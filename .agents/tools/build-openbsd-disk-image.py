#!/usr/bin/env python3
"""Assemble openbsd-disk-image (amd64) or aarch64-openbsd-disk-image (arm64): OpenBSD
installed from the project's own media.

OpenBSD publishes no disk image, so the image is an installation: the official
`cd<ver>.iso` boots the installer, which answers itself from a response file
(autoinstall(8)) and installs the official sets served from a local directory over
HTTP. The installer verifies the sets against the release's signed SHA256.sig.

The response file installs `bsd`, `bsd.mp`, `bsd.rd` and `base<ver>.tgz` (no
compilers, manual pages, games or X), sets root's password to `root`, turns sshd off
and moves the console to the serial line (com0, 115200). One local set,
`site<ver>.tgz`, carries `install.site`, which the installer runs in the new system
at the end: it removes `/usr/share/relink` and turns the libraries' reordering off
(`library_aslr=NO`): the objects and the step the system relinks its kernel and
libraries by at every boot -- the work a runner's every boot would repeat, and a
third of the image; shortens the boot prompt's wait to one second, and fills
the free space with zeros so the image compresses. The disk holds one file system
(an autopartitioning template), so the one fill reaches all of its free space. The disk is then converted to
qcow2, which keeps no zero cluster, and the archive compresses it.

On amd64 the installer's own console is chosen at its `boot>` prompt, which is drawn
on the VGA screen only: the prompt is read from the screen and `set tty com0` typed
there through the emulator's monitor; everything after it is on the serial line.

On arm64 the machine is QEMU's `virt' with the EDK II firmware for AArch64, which
has no screen: the firmware, the boot loader's `boot>` prompt, the installer and the
system all speak on the serial line (the PL011, which OpenBSD names com0). The
installation media are a CD on a virtio SCSI controller (cd0), the disk a virtio
block device (sd0). Without a hardware accelerator for the guest the emulator
translates (TCG), and the timeouts are longer.

usage: build-openbsd-disk-image.py <out-dir> <version> <sets-dir> <qemu-system with user networking> <qemu-img>
                                   [arm64 <edk2-aarch64-code.fd>]
       (<sets-dir> holds cdXX.iso, bsd, bsd.mp, bsd.rd, baseXX.tgz, BUILDINFO, SHA256, SHA256.sig
        of the architecture; the emulator is qemu-system-x86_64 for amd64 and
        qemu-system-aarch64 for arm64)
"""
import hashlib, http.server, io, os, re, socket, socketserver, subprocess, sys, tarfile, tempfile, threading, time
from pathlib import Path

SITE = """#!/bin/sh
# install.site: run by the installer in the new system before its first boot.
rm -rf /usr/share/relink
echo 'library_aslr=NO' >> /etc/rc.conf.local
echo 'set timeout 1' >> /etc/boot.conf
# The disk has one file system, / (the disklabel template); the installer runs this script
# chrooted in it, so `mount' would name it /mnt, a path that does not exist here.
dd if=/dev/zero of=/.zero bs=1m 2>/dev/null
rm -f /.zero
sync
"""

# The autopartitioning template (disklabel(8)): one root file system and a small swap. The
# installer's own layout divides the disk into /, /usr and /home, whose free space this
# script cannot zero, so their unwritten blocks were kept in the image.
DISKLABEL = """/        1G-*    100%
swap     64M
"""

RESPONSES = """System hostname = openbsd
Password for root account = root
Network interfaces = vio0
IPv4 address for vio0 = autoconf
IPv6 address for vio0 = none
Default IPv4 route = none
DNS domain name = my.domain
DNS nameservers = none
Start sshd(8) by default = no
Do you expect to run the X Window System = no
Change the default console to com0 = yes
Which speed should com0 use = 115200
Setup a user = no
What timezone are you in = UTC
Which disk is the root disk = sd0
Use (W)hole disk MBR, whole disk (G)PT or (E)dit = whole
Use (A)uto layout, (E)dit auto layout, or create (C)ustom layout = a
URL to autopartitioning template for disklabel = http://10.0.2.100/disklabel
Location of sets = http
HTTP proxy URL = none
HTTP Server = 10.0.2.100
Server directory = pub/OpenBSD/{version}/{arch}
Set name(s) = -game* -man* -x* -comp* site*
Checksum test for site{v}.tgz failed. Continue anyway = yes
Unverified sets: site{v}.tgz. Continue without verification = yes
Exit to (S)hell, (H)alt or (R)eboot = R
"""


RELAY = """import os, socket, sys, threading
s = socket.create_connection(("127.0.0.1", int(sys.argv[1])))
def up():
    while d := os.read(0, 65536):
        s.sendall(d)
    s.shutdown(socket.SHUT_WR)
threading.Thread(target=up, daemon=True).start()
while d := s.recv(65536):
    os.write(1, d)
"""


class VM:
    """QEMU with its serial line and monitor on Unix sockets."""

    def __init__(self, qemu, args, work: Path, log: Path):
        self.ser_path, self.mon_path = work / "ser.sock", work / "mon.sock"
        for p in (self.ser_path, self.mon_path):
            p.unlink(missing_ok=True)
        argv = [qemu, *args, "-chardev", f"socket,id=ser0,path={self.ser_path},server=on,wait=off",
                "-serial", "chardev:ser0", "-monitor", f"unix:{self.mon_path},server=on,wait=off",
                "-display", "none"]
        self.log = log.open("ab", buffering=0)
        self.p = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=self.log, stderr=self.log)
        for _ in range(100):
            if self.ser_path.exists() and self.mon_path.exists():
                break
            time.sleep(0.1)
        self.ser = socket.socket(socket.AF_UNIX)
        self.ser.connect(str(self.ser_path))
        self.ser.setblocking(False)
        self.mon = socket.socket(socket.AF_UNIX)
        self.mon.connect(str(self.mon_path))
        self.mon.settimeout(5)
        self.monitor_read()
        self.buf = b""

    def monitor_read(self):
        out = b""
        try:
            while not out.endswith(b"(qemu) "):
                d = self.mon.recv(65536)
                if not d:
                    break
                out += d
        except socket.timeout:
            pass
        return out.decode(errors="replace")

    def monitor(self, cmd):
        self.mon.sendall(cmd.encode() + b"\n")
        return self.monitor_read()

    def pump(self):
        try:
            while d := self.ser.recv(65536):
                self.buf += d
                self.log.write(d)
        except BlockingIOError:
            pass

    def expect(self, pattern, timeout):
        rx, end = re.compile(pattern.encode()), time.time() + timeout
        while time.time() < end:
            self.pump()
            if m := rx.search(self.buf):
                self.buf = self.buf[m.end():]
                return m
            if self.p.poll() is not None:
                raise SystemExit(f"the emulator ended (status {self.p.returncode}) before {pattern!r}")
            time.sleep(0.1)
        raise SystemExit(f"no {pattern!r} within {timeout} s; the console ends with:\n"
                         + self.buf[-600:].decode(errors="replace"))

    def send(self, line):
        self.ser.sendall((line + "\r").encode())

    def screen(self):
        out = self.monitor("xp /2000hx 0xb8000")
        cells = [int(m.group(1), 16) & 0xFF for m in re.finditer(r"0x([0-9a-f]{4})", out.split("\n", 1)[-1])]
        return "".join(chr(c) if 32 <= c < 127 else " " for c in cells)

    KEYS = {" ": "spc", "\n": "ret", "-": "minus", "/": "slash", ".": "dot"}

    def type(self, text):
        for ch in text:
            self.monitor("sendkey " + self.KEYS.get(ch, ch))
            time.sleep(0.05)

    def wait_exit(self, timeout):
        end = time.time() + timeout
        while time.time() < end:
            self.pump()
            if self.p.poll() is not None:
                return self.p.returncode
            time.sleep(0.5)
        raise SystemExit("the emulator did not end")

    def kill(self):
        if self.p.poll() is None:
            self.p.kill()
            self.p.wait()


def digest(p: Path, algo="sha256") -> str:
    h = hashlib.new(algo)
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main() -> int:
    out, version, sets, qemu, qemu_img = (Path(sys.argv[1]).resolve(), sys.argv[2], Path(sys.argv[3]).resolve(),
                                          sys.argv[4], sys.argv[5])
    arch = sys.argv[6] if len(sys.argv) > 6 else "amd64"
    if arch not in ("amd64", "arm64") or (arch == "arm64") != (len(sys.argv) == 8):
        raise SystemExit("the architecture is amd64, or arm64 followed by the EDK II firmware for AArch64")
    firmware = Path(sys.argv[7]).resolve() if arch == "arm64" else None
    # The package, the image and the machine of the architecture. TCG translates an arm64
    # guest on an x86_64 host: an installation and a first boot take minutes, not seconds.
    if arch == "amd64":
        package, image_name, slow = f"openbsd-disk-image-{version}", f"openbsd-{version}.qcow2", 1
        def machine(disk, cdrom=None):
            args = ["-machine", "q35,accel=kvm", "-cpu", "host", "-m", "1024", "-smp", "2",
                    "-drive", f"file={disk},if=virtio,format=qcow2"]
            return args + (["-cdrom", str(cdrom), "-boot", "d"] if cdrom else [])
    else:
        package, image_name, slow = f"openbsd-disk-image-{version}-aarch64", f"openbsd-{version}-aarch64.qcow2", 4
        def machine(disk, cdrom=None):
            # cortex-a72: under `max' QEMU offers the newest extensions (SVE2, SME), and OpenBSD 8.0's
            # kernel stopped at its first floating-point use (`FP exception in kernel', measured).
            args = ["-machine", "virt", "-cpu", "cortex-a72", "-accel", "kvm", "-accel", "tcg", "-m", "1024", "-smp", "2",
                    "-drive", f"if=pflash,format=raw,readonly=on,file={firmware}",
                    "-drive", f"file={disk},if=none,id=hd0,format=qcow2",
                    "-device", "virtio-blk-pci,drive=hd0,bootindex=1"]
            if cdrom:
                args += ["-drive", f"file={cdrom},if=none,id=cd0,media=cdrom,readonly=on",
                         "-device", "virtio-scsi-pci", "-device", "scsi-cd,drive=cd0,bootindex=0"]
            return args
    v = version.replace(".", "")
    names = [f"cd{v}.iso", "bsd", "bsd.mp", "bsd.rd", f"base{v}.tgz", "BUILDINFO"]
    stated = {m.group(1): m.group(2) for m in re.finditer(r"SHA256 \((.+?)\) = ([0-9a-f]+)", (sets / "SHA256").read_text())}
    for n in names:
        if n != "BUILDINFO" and digest(sets / n) != stated.get(n):
            raise SystemExit(f"{sets / n}: the digest differs from the release's SHA256")
    out.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(dir=out))
    serve = work / "www"
    tree = serve / f"pub/OpenBSD/{version}/{arch}"
    tree.mkdir(parents=True)
    for n in names[1:] + ["SHA256", "SHA256.sig"]:
        os.symlink(sets / n, tree / n)
    site = tree / f"site{v}.tgz"
    with tarfile.open(site, "w:gz") as t:
        data = SITE.encode()
        info = tarfile.TarInfo("./install.site")
        info.size, info.mode = len(data), 0o755
        t.addfile(info, io.BytesIO(data))
    # index.txt as the release publishes it: `ls -ln`, the name last.
    (tree / "index.txt").write_text("".join(
        f"-rw-r--r--  1 0  0  {p.stat().st_size} Jan  1 00:00 {p.name}\n"
        for p in sorted(tree.iterdir()) if p.name != "index.txt"))

    class Quiet(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=str(serve), **k)

        def log_message(self, fmt, *a):
            with (out / f"openbsd-{version}-http.log").open("a") as f:
                f.write((fmt % a) + "\n")

    httpd = socketserver.TCPServer(("127.0.0.1", 0), Quiet)
    port = httpd.server_address[1]
    (serve / "install.conf").write_text(RESPONSES.format(port=port, version=version, v=v, arch=arch))
    (serve / "disklabel").write_text(DISKLABEL)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()

    # The guest reaches one address, 10.0.2.100:80, and each connection to it is relayed to
    # the local server; nothing else is routed (`restrict=on`).
    relay = work / "relay.py"
    relay.write_text(RELAY)
    disk = work / f"openbsd-{version}.qcow2"
    subprocess.run([qemu_img, "create", "-q", "-f", "qcow2", str(disk), "6G"], check=True)
    log = out / f"openbsd-{version}-install.log"
    vm = VM(qemu, machine(disk, sets / f"cd{v}.iso") + [
                   "-netdev", f"user,id=n0,restrict=on,guestfwd=tcp:10.0.2.100:80-cmd:{sys.executable} {relay} {port}",
                   "-device", "virtio-net-pci,netdev=n0", "-no-reboot"],
            work, log)
    try:
        if arch == "amd64":
            end = time.time() + 120
            while "boot>" not in vm.screen():
                if time.time() > end:
                    raise SystemExit("the installer's boot> prompt did not appear on the screen")
                time.sleep(0.3)
            vm.type("set tty com0\n")
        vm.expect(r"boot> ", 120 * slow)
        vm.send("")
        vm.expect(r"\(I\)nstall, \(U\)pgrade, \(A\)utoinstall or \(S\)hell\? ", 180 * slow)
        vm.send("a")
        vm.expect(r"Response file location\?.*\] ", 120 * slow)
        vm.send("http://10.0.2.100/install.conf")
        if vm.expect(r"CONGRATULATIONS|failed; check /tmp/ai/ai.log", 1800 * slow).group(0) != b"CONGRATULATIONS":
            raise SystemExit(f"the installer stopped: see {log}")
        vm.wait_exit(300 * slow)
    finally:
        vm.kill()
        httpd.shutdown()

    # The first boot, with no network: the console, the login and a clean halt.
    vm = VM(qemu, machine(disk) + ["-nic", "none", "-no-reboot"], work, log)
    try:
        t0 = time.time()
        vm.expect(r"login: ", 600 * slow)
        print(f"login prompt after {time.time() - t0:.0f} s")
        vm.send("root")
        vm.expect(r"Password:", 30)
        vm.send("root")
        vm.expect(r"# ", 60)
        vm.send("halt -p")
        vm.wait_exit(300 * slow)
    finally:
        vm.kill()

    pkg = out / package
    pkg.mkdir(exist_ok=True)
    image = pkg / image_name
    subprocess.run([qemu_img, "convert", "-O", "qcow2", str(disk), str(image)], check=True)
    disk.unlink()
    listing = "\n".join(f"    {n}\n        sha256 {stated[n]}" for n in names if n in stated)
    (pkg / "PROVENANCE.md").write_text(f'''# Provenance

Installed by `build-openbsd-disk-image.py` from the OpenBSD {version} release for {arch}
(https://cdn.openbsd.org/pub/OpenBSD/{version}/{arch}/), by the release's own installer
answering a response file (autoinstall(8)). The installer verified the sets against the
release's signed SHA256.sig; their digests, as SHA256 states them:

{listing}

Installed sets: bsd, bsd.mp, bsd.rd, base{v}.tgz. Root's password is `root`, sshd is off, the
console is com0 at 115200{" (on arm64, QEMU virt's PL011 with the EDK II firmware)" if arch == "arm64" else ""}. A local set, site{v}.tgz, ran this install.site in the new system:

{SITE}
The disk is converted to qcow2 (`qemu-img convert`), which keeps no zero cluster.
''')
    archive = out / f"{package}.tar.xz"
    subprocess.run(["tar", "-C", str(out), "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                    "-cJf", str(archive), pkg.name], check=True)
    print(archive, digest(archive), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
