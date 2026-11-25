#!/usr/bin/env python3
"""Assemble aarch64-netbsd-disk-image from The NetBSD Foundation's arm64 live image.

The image (`arm64.img.gz`, NetBSD-<version>/evbarm-aarch64/binary/gzimg/ on
cdn.netbsd.org) is the system as the release's INSTALL describes it for 64-bit Arm:
a GPT disk with an EFI system partition (the boot loader, bootaa64.efi, and the
kernel, netbsd.img) and the root file system. It boots under QEMU's `virt' machine
with the EDK II firmware for AArch64, and the firmware, the boot loader, the kernel
and the login all speak on the serial line (the PL011); root logs in without a
password.

The release publishes no digest of the gzipped images (gzimg/), only of its kernels
(kernel/SHA512) and sets. So the kernel set is checked against kernel/SHA512, and the
image's own kernel (/boot/netbsd.img, read by the booted system) against the kernel
set's: the image is the release's if it boots that kernel.

The image is booted once, by this script, as its first boot would be at every run:
the system makes its host keys, its databases and its caches then. Five changes are
made in it, by the system itself, typed on the serial line:

    the boot loader waits one second                /boot/boot.cfg: `timeout=1'
    no network service starts (a runner's machine   /etc/rc.conf: sshd, dhcpcd, ntpd,
      has no network), nor the mail system             mdnsd, postfix = NO
    the root file system is not resized, and the    /etc/rc.conf: resize_gpt,
      system does not reboot for it                    resize_root = NO
    no host key is published                        /etc/ssh/ssh_host_*: removed
                                                       (sshd is off; it would make
                                                       new ones when started)

and the system is halted. The disk is then converted to qcow2 (one file, without the
overlay it was booted through), and the archive compresses it.

Layout of netbsd-disk-image-<version>-aarch64.tar.xz:

    netbsd-disk-image-<version>-aarch64/
        netbsd-<version>-aarch64.qcow2
        PROVENANCE.md

usage: build-aarch64-netbsd-disk-image.py <out-dir> <version> <arm64.img.gz>
           <netbsd-GENERIC64.img.gz> <kernel/SHA512> <qemu-system-aarch64> <edk2-aarch64-code.fd> <qemu-img>
"""
import gzip, hashlib, re, shutil, socket, subprocess, sys, tempfile, time
from pathlib import Path

RC_CONF = ["sshd=NO", "dhcpcd=NO", "ntpd=NO", "mdnsd=NO", "postfix=NO", "resize_gpt=NO", "resize_root=NO"]


class VM:
    """QEMU with its serial line on a Unix socket."""

    def __init__(self, qemu, args, work: Path, log: Path):
        self.ser_path = work / "ser.sock"
        self.ser_path.unlink(missing_ok=True)
        argv = [qemu, *args, "-chardev", f"socket,id=ser0,path={self.ser_path},server=on,wait=off",
                "-serial", "chardev:ser0", "-display", "none", "-no-reboot"]
        self.log = log.open("ab", buffering=0)
        self.p = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=self.log, stderr=self.log)
        for _ in range(100):
            if self.ser_path.exists():
                break
            time.sleep(0.1)
        self.ser = socket.socket(socket.AF_UNIX)
        self.ser.connect(str(self.ser_path))
        self.ser.setblocking(False)
        self.buf = b""

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

    def run(self, line, timeout=120):
        """Types a line at root's prompt and returns what it printed before the next prompt."""
        self.send(line)
        m = self.expect(r"(?s)(.*?)\n[^\n]*# ", timeout)
        return m.group(1).decode(errors="replace").replace("\r", "")

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
    out, version = Path(sys.argv[1]).resolve(), sys.argv[2]
    gz, kernel_gz, kernel_sums = (Path(a).resolve() for a in sys.argv[3:6])
    qemu, firmware, qemu_img = sys.argv[6], Path(sys.argv[7]).resolve(), sys.argv[8]

    stated = next(l.rsplit(" ", 1)[1] for l in kernel_sums.read_text().splitlines()
                  if l.startswith(f"SHA512 ({kernel_gz.name}) = "))
    if digest(kernel_gz, "sha512") != stated:
        raise SystemExit(f"{kernel_gz}: the digest differs from the release's kernel/SHA512")
    h = hashlib.sha512()
    with gzip.open(kernel_gz, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    kernel_sha512 = h.hexdigest()

    out.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(dir=out))
    raw = work / "arm64.img"
    with gzip.open(gz, "rb") as src, raw.open("wb") as dst:
        shutil.copyfileobj(src, dst, 1 << 20)
    disk = work / "disk.qcow2"
    subprocess.run([qemu_img, "convert", "-O", "qcow2", str(raw), str(disk)], check=True)
    raw.unlink()

    log = out / f"netbsd-{version}-aarch64-boot.log"
    machine = ["-machine", "virt", "-cpu", "max", "-accel", "kvm", "-accel", "tcg", "-m", "1024", "-smp", "2",
               "-drive", f"if=pflash,format=raw,readonly=on,file={firmware}",
               "-drive", f"file={disk},if=virtio,format=qcow2", "-nic", "none"]

    # The first boot, and the changes, made by the system itself.
    vm = VM(qemu, machine, work, log)
    try:
        t0 = time.time()
        vm.expect(r"login: ", 1800)
        first = time.time() - t0
        vm.send("root")
        vm.expect(r"# ", 120)
        seen = vm.run("cksum -a SHA512 /boot/netbsd.img")
        if f"SHA512 (/boot/netbsd.img) = {kernel_sha512}" not in seen:
            raise SystemExit(f"the image's kernel is not the release's kernel set: {seen!r}")
        vm.run("printf 'timeout=1\\n' > /boot/boot.cfg")
        for line in RC_CONF:
            vm.run(f"echo {line} >> /etc/rc.conf")
        vm.run("rm -f /etc/ssh/ssh_host_*")
        vm.run("sync")
        vm.send("shutdown -p now")
        vm.wait_exit(600)
    finally:
        vm.kill()

    # The boot a runner makes: the console, the login and a clean halt.
    vm = VM(qemu, machine, work, log)
    try:
        t0 = time.time()
        vm.expect(r"starting in 1 seconds", 300)
        vm.expect(r"login: ", 900)
        second = time.time() - t0
        vm.send("root")
        vm.expect(r"# ", 120)
        keys = vm.run("ls /etc/ssh/ | grep -c host_ || true").strip().splitlines()[-1:]
        vm.send("shutdown -p now")
        vm.wait_exit(600)
    finally:
        vm.kill()
    if keys != ["0"]:
        raise SystemExit(f"host keys were made again: {keys}")
    print(f"login prompt: {first:.0f} s at the first boot, {second:.0f} s after it")

    pkg = out / f"netbsd-disk-image-{version}-aarch64"
    pkg.mkdir(exist_ok=True)
    image = pkg / f"netbsd-{version}-aarch64.qcow2"
    subprocess.run([qemu_img, "convert", "-O", "qcow2", str(disk), str(image)], check=True)
    shutil.rmtree(work)
    rc = "\n".join(f"{' ' * 25}{l}" for l in RC_CONF)
    (pkg / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-aarch64-netbsd-disk-image.py` from The NetBSD Foundation's arm64 live
image of NetBSD {version}:

    https://cdn.netbsd.org/pub/NetBSD/NetBSD-{version}/evbarm-aarch64/binary/gzimg/{gz.name}
        sha512 {digest(gz, "sha512")}
        sha256 {digest(gz, "sha256")}

The release publishes no digest of its gzipped images. Its kernel set is checked against
the release's kernel/SHA512, and the image's own kernel (/boot/netbsd.img, read by the
booted system with `cksum -a SHA512`) is that set's kernel, byte for byte:

    https://cdn.netbsd.org/pub/NetBSD/NetBSD-{version}/evbarm-aarch64/binary/kernel/{kernel_gz.name}
        sha512 {stated} (kernel/SHA512)
        decompressed: sha512 {kernel_sha512}

The image was booted once (QEMU `virt', EDK II for AArch64, no network), as its first boot
would be at every run: the system made its databases and caches then. The changes, typed
on the serial line as root:

    /boot/boot.cfg       timeout=1 (the boot loader waits one second)
    /etc/rc.conf         appended:
{rc}
    /etc/ssh/ssh_host_*  removed (the host keys the first boot made; sshd is off)

The system was halted, and booted again to its login prompt and halted: no host key was
made again. Nothing else is changed. The disk is converted to qcow2 (`qemu-img convert`).
''')
    archive = out / f"{pkg.name}.tar.xz"
    subprocess.run(["tar", "-C", str(out), "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                    "-cJf", str(archive), pkg.name], check=True)
    print(archive, digest(archive), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
