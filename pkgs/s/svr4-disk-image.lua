package = {
    spec = "2",
    homepage = "https://github.com/Sunrisepeak/svr4-386-src",
    name = "svr4-disk-image",
    description = "EXPERIMENTAL, technical verification only: the floppy set of AT&T UNIX System V/386 Release 4.0 Version 3.0 as a third party publishes it (proprietary, not mirrored), with a program that installs it in QEMU and runs a command on it",

    maintainers = {"https://github.com/Sunrisepeak"},
    licenses = {"LicenseRef-proprietary-not-redistributed"},
    repo = "https://github.com/Sunrisepeak/svr4-386-src",

    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"runner", "svr4"},
    keywords = {"svr4", "system-v", "unix", "disk-image", "qemu", "runner", "experimental"},

    -- EXPERIMENTAL: TECHNICAL VERIFICATION ONLY, AND NOT A DISK-IMAGE ASSET OF THE CLASS
    -- (docs/12-disk-image-assets.md) IN THREE RESPECTS.
    --
    -- It is not free software. The system is proprietary and the repository that publishes
    -- its floppies states no licence. The package exists so that one measurement can be
    -- repeated: a program of `i686-svr4-musl` (openkal-svr4) on a System V kernel. It may be
    -- disabled or removed at any time, and `config` says so each time it is installed.
    --
    -- It is not mirrored. The bytes are fetched from the one place the recipe names and are
    -- not copied to xlings-res. THE ADDRESS BELOW IS A PLACEHOLDER: this recipe records the
    -- repository used (`repo`, Sunrisepeak/svr4-386-src) and the digest of the file, and the
    -- maintainer supplies the address of `pkgs.tar.gz` when the package is enabled. Until
    -- then an install stops at the download.
    --
    -- It is not an image. No prepared image is published, so what is installed is the floppy
    -- set, a program (svr4.py) that installs the system from it in QEMU on the user's machine
    -- and runs a command on the result, and README.md, which is the path to repeat the
    -- measurement. Both files are written from this recipe.
    xpm = {
        linux = {
            ["latest"] = { ref = "4.0.3-20261119" },
            ["4.0.3-20261119"] = {
                url = {
                    GLOBAL = "https://example.invalid/SVR4-386-FLOPPY-SET/pkgs.tar.gz",
                    CN = "https://example.invalid/SVR4-386-FLOPPY-SET/pkgs.tar.gz",
                },
                sha256 = "59d301d9a403f358740cb2945e9f6c83df495dcf2de2f31fd85dff7bc9463b9b",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local readme = [====[
# svr4-disk-image — TECHNICAL VERIFICATION ONLY

AT&T UNIX System V/386 Release 4.0 Version 3.0 (1990) in QEMU: the floppy set of its Base System
Package, and a program that installs it into a disk image and runs a command on it. It exists to
check that a program built for the System V i386 interface (`i686-svr4-musl`, openkal-svr4) runs on
a System V kernel, and for nothing else.

## What this is not

- **Not free software, and not ours.** The system is proprietary. The floppy set is fetched from
  where it is published and is not mirrored by xlings; the repository recorded below states no
  licence for it. Nothing here grants a right to use it: whether you may is for
  you to settle. This package may be disabled or removed at any time.
- **Not a supported package.** It is not a disk-image asset of this index's class: no prepared
  image is published, so the image is built on your machine, from the floppies, in about a quarter
  of an hour.
- **Not for any other use.** One machine, no network, well-known passwords.

## Source

| | |
|---|---|
| Repository | <https://github.com/Sunrisepeak/svr4-386-src> |
| File | `pkgs.tar.gz`, the floppy set; its address is the recipe's, which the index's maintainer supplies |
| sha256 | `59d301d9a403f358740cb2945e9f6c83df495dcf2de2f31fd85dff7bc9463b9b` |
| Contents | 27 floppy images of 1.44 MB: `base1` .. `base12` (used here), and `nsu`, `inet`, `ed`, `scde`, `compat`, `termcap`, `xcp`, `license` (not used) |

## What is in the package

```
README.md      this file
svr4.py        build the image; run a command on it
media/         the floppy set, as fetched
```

## Reproducing it

Needs Linux, Python 3.8 or later, `qemu-system-i386` and `qemu-img` (measured with QEMU 8.2.2).
KVM is used when `/dev/kvm` can be opened.

```sh
d=~/.xlings/data/xpkgs/xim-x-svr4-disk-image/4.0.3-20261119   # the directory this file is in

# 1. Install the system: boots floppy 1, answers the installer, reads the twelve floppies,
#    leaves a shell on the first serial line. About 15 minutes with KVM.
python3 "$d/svr4.py" build --media "$d/media" --image svr4.qcow2

# 2. Run something. The image is not written: each run boots a copy-on-write overlay. The
#    machine's clock is 21 February 2023 in every run (a day after the installer's own).
python3 "$d/svr4.py" run --image svr4.qcow2 -- uname -a
#   svr4 svr4 4.0 3.0 i386 386/AT

# 3. Run a program of the row. Files go in as a tar archive cut into floppies and are
#    unpacked in /tmp/in, where the command line runs; the status is the program's.
mcpp build --target i686-svr4-musl --release            # openkal-platform 0.30.1 or later
python3 "$d/svr4.py" run --image svr4.qcow2 --file target/i686-svr4-musl/*/bin/hello -- ./hello
echo $?
```

`build --resume` configures an installation that stopped after its floppies (`<image>.partial`).

`build` chooses: a 400 MiB disk (the system does not start on much more than 500), 64 MiB of
memory (it does not start on more than 255), the `ufs` file system for `/` (names of 255
characters; the default, `s5`, has fourteen), the system name `svr4`.

## What was measured with it (2026-11-19)

On Linux x86_64, QEMU 8.2.2 with KVM, programs of `i686-svr4-musl` linked as openkal-platform
0.30.1 links them:

| Program | Result |
|---|---|
| openkal's conformance suite (`env,time,fs,terminal`) | 122 observations held, 0 did not hold, on the serial line (`svr4.py run`); 111 held, 0 did not, with its output in a file |
| A C program; a C++23 program (`import std`, an exception across a frame, files made, renamed, listed, removed) | run; statuses 42 and 7 |
| `cmd` (github.com/ChenPi11/cmd): `test.bat` and `test-crlf.bat`, dev and release builds | output as expected |

Found by it: this kernel kills a static executable that has a `PT_PHDR` program header and no
`PT_INTERP` one. openkal-platform 0.30.1 links the row without it.

## Known limits

- The programs above were run as linked, debugging sections included (up to 2.8 MB).
- A delivered file larger than a floppy is cut across several; the machine has no other way in
  (no network is installed; a second hard disk needs this system's own partition table and label).
- Only the Base System Package is installed: no compiler, no networking.
- The installer is a dialogue; `svr4.py build` waits for each of its questions by its text. Another
  release of the system asks other questions.
]====]

local program = [====[
#!/usr/bin/env python3
"""AT&T UNIX System V/386 Release 4.0 Version 3.0 in QEMU: install it, and run a program on it.

    svr4.py build --media <dir of the floppy set> --image svr4.qcow2
    svr4.py run   --image svr4.qcow2 [--file FILE ...] -- COMMAND LINE

TECHNICAL VERIFICATION ONLY. The floppy set is not part of this program and is not free software;
see README.md beside this file.

`build' boots the first floppy and answers the installer, which is a dialogue in text on the
console: what the screen shows is read from the display adapter's text memory through QEMU's
monitor, and the answers are typed on the machine's keyboard. The system that results has a shell
on its first serial line, which is what `run' talks to.

`run' boots a copy-on-write overlay of the image (the image is not written), delivers the files as
a tar archive cut into floppies, runs the command line in the directory that holds them, writes
what the program wrote, and returns its status.

Needs: python 3.8 or later, qemu-system-i386 and qemu-img (QEMU 6 or later). KVM is used when
/dev/kvm can be opened; without it the installation takes several times longer.
"""
import argparse, io, os, re, shutil, socket, subprocess, sys, tarfile, tempfile, time

FLOPPY = 1474560
ROOT_PASSWORD = "sysv4r00t"          # a machine with no network; the serial shell asks for none
INSTALL_PASSWORD = "sysv4inst"
EXPIRED_PASSWORD = "Unix5vr4x"
# The installer does not read the machine's clock: it runs at the date of its floppies, 20 February
# 2023. The machine is started a day after that, every time, so the installed system does not find
# its passwords expired and a run does not depend on the day it is made.
CLOCK = "2023-02-21T12:00:00"
PROMPT = "svr4# "
KEY = {' ': 'spc', '\n': 'ret', '-': 'minus', '=': 'equal', '.': 'dot', '/': 'slash', ',': 'comma',
       ';': 'semicolon', "'": 'apostrophe', '\\': 'backslash', '[': 'bracket_left', ']': 'bracket_right',
       '`': 'grave_accent'}
SHIFT = {'>': 'dot', '<': 'comma', '_': 'minus', '|': 'backslash', '&': '7', '*': '8', '(': '9', ')': '0',
         '!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '+': 'equal', ':': 'semicolon',
         '"': 'apostrophe', '?': 'slash', '{': 'bracket_left', '}': 'bracket_right', '~': 'grave_accent'}


def say(*words):
    print("svr4:", *words, file=sys.stderr, flush=True)


class Machine:
    """One QEMU process: its monitor and its first serial line, each a socket in `work'."""

    def __init__(self, work, image, floppy=None, boot="c", memory=64):
        self.work = work
        self.mon_path = os.path.join(work, "monitor")
        self.ser_path = os.path.join(work, "serial")
        argv = ["qemu-system-i386", "-display", "none", "-m", str(memory), "-net", "none",
                "-cpu", "pentium", "-rtc", f"base={CLOCK}",
                "-monitor", f"unix:{self.mon_path},server,nowait",
                "-serial", f"unix:{self.ser_path},server,nowait",
                "-drive", f"if=ide,format=qcow2,file={image}", "-boot", boot]
        if os.access("/dev/kvm", os.R_OK | os.W_OK):
            argv += ["-accel", "kvm"]
        # A drive with no floppy in it is given as a 2.88 MB one, which this system does not know:
        # the machine starts with a blank 1.44 MB floppy when it is given none.
        if not floppy:
            floppy = os.path.join(work, "blank-floppy")
            with open(floppy, "wb") as fh:
                fh.truncate(FLOPPY)
        argv += ["-drive", f"if=floppy,format=raw,file={floppy}"]
        self.log = open(os.path.join(work, "qemu.log"), "w")
        self.p = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=self.log, stderr=subprocess.STDOUT)
        self.mon = self._connect(self.mon_path)
        self.ser = self._connect(self.ser_path)
        self.ser.settimeout(0.5)
        self.heard = b""
        self._monitor_read()

    def _connect(self, path):
        end = time.time() + 20
        while True:
            try:
                s = socket.socket(socket.AF_UNIX)
                s.connect(path)
                return s
            except OSError:
                if self.p.poll() is not None:
                    raise SystemExit("svr4: the emulator ended: " + open(self.log.name).read()[-600:])
                if time.time() > end:
                    raise SystemExit("svr4: the emulator's sockets did not appear")
                time.sleep(0.1)

    # --- the monitor: keys, floppies, the text screen -------------------------------------------
    def _monitor_read(self, wait=0.15):
        self.mon.settimeout(wait)
        out = b""
        try:
            while True:
                d = self.mon.recv(65536)
                if not d:
                    break
                out += d
        except socket.timeout:
            pass
        return out

    def monitor(self, command, wait=0.15):
        self.mon.sendall((command + "\n").encode())
        return self._monitor_read(wait)

    def key(self, name):
        self.monitor("sendkey " + name, wait=0.06)

    def type(self, text, enter=True):
        for ch in text + ("\n" if enter else ""):
            self.key(KEY.get(ch) or ("shift-" + SHIFT[ch] if ch in SHIFT else
                                     ("shift-" + ch.lower() if ch.isupper() else ch)))

    def floppy(self, path):
        if path:
            self.monitor(f'change floppy0 "{path}" raw', wait=0.4)
        else:
            self.monitor("eject -f floppy0", wait=0.4)

    def screen(self):
        """The 80x25 text screen, read from the display adapter's memory."""
        path = os.path.join(self.work, "screen.bin")
        if os.path.exists(path):
            os.remove(path)
        self.monitor(f'pmemsave 0xb8000 4000 "{path}"', wait=0.3)
        try:
            b = open(path, "rb").read()
        except OSError:
            return ""
        lines = []
        for r in range(25):
            row = bytes(b[(r * 80 + c) * 2] for c in range(80) if (r * 80 + c) * 2 < len(b)).decode("cp437", "replace")
            lines.append("".join(ch if ch.isprintable() else " " for ch in row).rstrip())
        while lines and not lines[-1]:
            lines.pop()
        return "\n".join(lines)

    def shown(self, text, within, tail=4):
        """Waits until the last lines of the screen hold `text' and the screen is still."""
        end = time.time() + within
        last = None
        while time.time() < end:
            s = self.screen()
            if text in "\n".join(s.splitlines()[-tail:]) and s == last:
                time.sleep(1)                      # a question is shown before its answer is read
                return s
            last = s
            time.sleep(1.5)
        raise SystemExit(f"svr4: the screen did not come to show {text!r} within {within} s; it shows:\n{self.screen()}")

    # --- the serial line: the shell `build' leaves there ----------------------------------------
    def hear(self, pattern, within):
        """Reads the serial line until `pattern' (bytes, a regular expression) is in what was heard
        since the last call; returns the match and what preceded it."""
        end = time.time() + within
        rx = re.compile(pattern, re.S)
        while True:
            m = rx.search(self.heard)
            if m:
                before, self.heard = self.heard[:m.start()], self.heard[m.end():]
                return m, before
            if time.time() > end:
                raise SystemExit(f"svr4: the serial line did not say {pattern!r} within {within} s; it said:\n"
                                 + self.heard[-800:].decode("latin-1"))
            try:
                d = self.ser.recv(65536)
                if d:
                    self.heard += d
            except socket.timeout:
                if self.p.poll() is not None:
                    raise SystemExit("svr4: the emulator ended")

    def forget(self):
        """Drops what the serial line has said so far."""
        try:
            while self.ser.recv(65536):
                pass
        except socket.timeout:
            pass
        self.heard = b""

    def tell(self, line):
        """One line to the serial shell, written slowly: the port has no flow control."""
        data = (line + "\n").encode()
        for i in range(0, len(data), 16):
            self.ser.sendall(data[i:i + 16])
            time.sleep(0.02)

    def shell(self, line, within=120):
        """Runs a line in the serial shell and returns what it wrote and its status."""
        self.tell(line + "; echo ==STA''TUS=$?==")
        m, before = self.hear(rb"==STATUS=(\d+)==\r?\n", within)
        self.hear(re.escape(PROMPT.encode()), 30)
        return before, int(m.group(1))

    def stop(self):
        if self.p.poll() is None:
            try:
                self.monitor("quit")
            except OSError:
                pass
            try:
                self.p.wait(10)
            except subprocess.TimeoutExpired:
                self.p.kill()
                self.p.wait()
        self.log.close()


def need(*programs):
    for p in programs:
        if not shutil.which(p):
            raise SystemExit(f"svr4: {p} is not on PATH")


# ------------------------------------------------------------------------------------------------
def configure(m):
    """Logs in on the console of the installed system and leaves a shell on the first serial line,
    with no login: what `run' and a runner talk to."""
    m.shown("Console Login:", 600)
    m.type("root")
    m.shown("Password:", 60); m.type(ROOT_PASSWORD)
    time.sleep(5)
    # A password older than the system allows is changed at the login. The machine's clock is
    # set a day after the installer's (Machine), so this is not expected; it is answered if asked.
    if "Choose a new one" in m.screen():
        m.shown("New password:", 60); m.type(EXPIRED_PASSWORD)
        m.shown("Re-enter new password:", 60); m.type(EXPIRED_PASSWORD)
        time.sleep(5)
    m.type("echo logged''-in")
    m.shown("logged-in", 60, tail=3)
    m.type("clear")
    # init gives the line to a shell as one command, so the prompt is set in a file of its own.
    # The line's erase and kill characters are `#' and `@' as the system leaves them, which a
    # command line may hold; and what is written to the shell is not written back.
    m.type("echo 'exec </dev/tty00 >/dev/tty00 2>&1' > /etc/serialsh")
    m.type("echo 'stty erase \"^h\" kill \"^u\" -echo' >> /etc/serialsh")
    m.type("echo 'PS1=\"" + PROMPT + "\"; export PS1; exec /sbin/sh -i' >> /etc/serialsh")
    m.type("grep -v '^s0:' /etc/inittab > /tmp/inittab; cp /tmp/inittab /etc/inittab")
    m.type("echo 's0:234:respawn:/sbin/sh /etc/serialsh' >> /etc/inittab")
    m.type("init q; echo configured")
    m.shown("configured", 60, tail=3)
    # What the line said before the shell was there is not the shell's: ask it for a prompt.
    time.sleep(8)
    m.forget()
    m.tell("")
    m.hear(re.escape(PROMPT.encode()), 120)
    out, status = m.shell("uname -a")
    say("the serial shell answers:", out.decode("latin-1").strip())


def build(args):
    need("qemu-system-i386", "qemu-img")
    media = os.path.abspath(args.media)
    floppies = {}
    for root, _, names in os.walk(media):
        for n in names:
            if re.fullmatch(r"base\d+", n) and os.path.getsize(os.path.join(root, n)) == FLOPPY:
                floppies[int(n[4:])] = os.path.join(root, n)
    if sorted(floppies) != list(range(1, 13)):
        raise SystemExit(f"svr4: {media} does not hold the twelve floppies base1 .. base12 of the Base System Package")
    image = os.path.abspath(args.image)
    if os.path.exists(image):
        raise SystemExit(f"svr4: {image} exists; remove it to build again")
    work = tempfile.mkdtemp(prefix="svr4-build-")
    # The installer writes to its floppies (it is the root file system of the first boot): copies.
    fl = {}
    for n, p in floppies.items():
        fl[n] = os.path.join(work, f"base{n}")
        shutil.copyfile(p, fl[n])
    partial = image + ".partial"
    if args.resume:
        # An installed system that was not configured (a build that stopped after the floppies).
        if not os.path.exists(partial):
            raise SystemExit(f"svr4: nothing to resume: no {partial}")
        m = Machine(work, partial)
        try:
            configure(m)
            m.type("cd /; sync; sync; shutdown -y -g0 -i0")
            m.shown("Reboot the system now.", 300)
        finally:
            m.stop()
        os.rename(partial, image)
        shutil.rmtree(work, ignore_errors=True)
        say("built", image)
        return 0
    if os.path.exists(partial):
        os.remove(partial)
    subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", partial, f"{args.size}M"], check=True)
    m = Machine(work, partial, floppy=fl[1], boot="a")
    try:
        say("the first floppy boots (a kernel of 1990; about a minute)")
        m.shown("Floppy Disk 2 and then strike ENTER", 300)
        m.floppy(fl[2]); m.key("ret")
        m.shown("Please strike ENTER to install the UNIX System", 300); m.key("ret")
        m.shown("Do you wish to continue (y or n)?", 120); m.type("y")
        m.shown("Please strike ENTER when ready or DEL", 120); m.key("ret")
        m.shown('To select this, please type "y"', 120, tail=6); m.type("y")
        # ufs: file names of 255 characters. The default, s5, has fourteen.
        m.shown("Please press ENTER for the default type", 120); m.type("ufs")
        m.shown("disk slices or filesystems (y or n)?", 120); m.type("n")
        m.shown("Is this correct (y or n)?", 120); m.type("y")
        m.shown("Please strike ENTER to continue or DEL to cancel", 120); m.key("ret")
        say("the disk is checked and its file systems are made")
        m.shown("Is this configuration acceptable? (y/n)", 900); m.type("y")
        m.shown("Reboot the system now.", 900)
        m.floppy(None); m.monitor("system_reset")
        say("the system on the disk boots and reads the other ten floppies")
        # This question discards what was typed before it has settled, and takes one key.
        m.shown('or "F" to install from FLOPPY DISKETTE', 300, tail=6)
        for _ in range(20):
            time.sleep(5)
            m.type("f", enter=False)
            time.sleep(3)
            if "Floppy Disk 3 of 12" in m.screen():
                break
        for n in range(3, 13):
            m.shown(f"Floppy Disk {n} of 12 and then strike ENTER", 900)
            m.floppy(fl[n]); m.key("ret")
            say(f"floppy {n} of 12")
        m.shown("New password:", 900); m.type(ROOT_PASSWORD)
        m.shown("Re-enter new password:", 60); m.type(ROOT_PASSWORD)
        m.shown("Enter a password for the 'install' user", 120, tail=6)
        m.shown("New password:", 60); m.type(INSTALL_PASSWORD)
        m.shown("Re-enter new password:", 60); m.type(INSTALL_PASSWORD)
        m.shown("Enter System Name:", 120); m.type("svr4")
        say("the kernel is rebuilt")
        m.shown("Reboot the system now.", 900)
        m.floppy(None); m.monitor("system_reset")
        configure(m)
        m.type("cd /; sync; sync; shutdown -y -g0 -i0")
        m.shown("Reboot the system now.", 300)
    finally:
        m.stop()
    os.rename(partial, image)
    shutil.rmtree(work, ignore_errors=True)
    say("built", image)
    return 0


# ------------------------------------------------------------------------------------------------
def run(args):
    need("qemu-system-i386", "qemu-img")
    image = os.path.abspath(args.image)
    if not os.path.isfile(image):
        raise SystemExit(f"svr4: no image {image}; `svr4.py build' makes it")
    work = tempfile.mkdtemp(prefix="svr4-run-")
    status = 1
    m = None
    try:
        overlay = os.path.join(work, "overlay.qcow2")
        subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", "-F", "qcow2", "-b", image, overlay], check=True)
        # The files as a tar archive (the 1977 format, which every tar reads), cut into floppies.
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode="w", format=tarfile.USTAR_FORMAT) as tar:
            for f in args.file:
                src, _, name = f.partition("=")
                info = tar.gettarinfo(src, arcname=name or os.path.basename(src))
                info.uid = info.gid = 0; info.uname = info.gname = ""
                with open(src, "rb") as fh:
                    tar.addfile(info, fh)
        data = buf.getvalue()
        chunks = []
        for i in range(0, len(data), FLOPPY):
            path = os.path.join(work, f"files{len(chunks)}")
            with open(path, "wb") as fh:
                fh.write(data[i:i + FLOPPY].ljust(FLOPPY, b"\0"))
            chunks.append(path)
        m = Machine(work, overlay)
        m.hear(re.escape(PROMPT.encode()), args.boot_timeout)
        # A file is at most 2 MB until the limit is raised (in 512-byte blocks; root may).
        m.shell("ulimit 2097152; mkdir /tmp/in; cd /tmp/in")
        for n, path in enumerate(chunks if args.file else []):
            m.floppy(path)
            out, st = m.shell("dd if=/dev/rdsk/f03ht bs=18k count=80 >> /tmp/in.tar 2>/tmp/in.err || { cat /tmp/in.err; false; }", 300)
            if st:
                raise SystemExit(f"svr4: floppy {n + 1} of {len(chunks)} was not read: " + out.decode("latin-1"))
        if args.file:
            out, st = m.shell("tar xf /tmp/in.tar && rm /tmp/in.tar", 300)
            if st:
                raise SystemExit("svr4: the files were not unpacked: " + out.decode("latin-1"))
        line = " ".join(args.command)
        m.tell("echo ==BEG''IN==; " + line + " < /dev/null; echo ==STA''TUS=$?==")
        m.hear(rb"==BEGIN==\r?\n", 60)
        mt, before = m.hear(rb"==STATUS=(\d+)==", args.timeout)
        sys.stdout.buffer.write(before.replace(b"\r\n", b"\n"))
        sys.stdout.flush()
        status = int(mt.group(1))
    finally:
        if m:
            m.stop()
        shutil.rmtree(work, ignore_errors=True)
    return status


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="verb", required=True)
    b = sub.add_parser("build", help="install the system from its floppy set into a disk image")
    b.add_argument("--media", required=True, help="a directory holding base1 .. base12 (searched recursively)")
    b.add_argument("--image", required=True)
    b.add_argument("--size", type=int, default=400, help="MiB; the system does not start on more than about 500")
    b.add_argument("--resume", action="store_true", help="configure <image>.partial, an installation that stopped after its floppies")
    r = sub.add_parser("run", help="run a command line on the system and return its status")
    r.add_argument("--image", required=True)
    r.add_argument("--file", action="append", default=[], metavar="FROM[=TO]", help="a file delivered beside the command")
    r.add_argument("--timeout", type=int, default=600)
    r.add_argument("--boot-timeout", type=int, default=600)
    r.add_argument("command", nargs="+")
    a = ap.parse_args()
    return build(a) if a.verb == "build" else run(a)


if __name__ == "__main__":
    sys.exit(main())
]====]

function install()
    -- xim unpacks the archive beside it, into a directory named after it; the floppies are
    -- beneath `trn/` in the archive.
    local top = pkginfo.install_file()
    for _, ext in ipairs({ ".tar.gz" }) do
        if top:sub(-#ext) == ext then top = top:sub(1, #top - #ext) break end
    end
    local media = nil
    for _, candidate in ipairs({ path.join(top, "trn"), top, path.join(path.directory(top), "trn") }) do
        if os.isfile(path.join(candidate, "base", "base1")) then media = candidate break end
    end
    if not media then
        raise("svr4-disk-image: the floppy set was not found beneath " .. top)
    end
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(dir)
    os.mv(media, path.join(dir, "media"))
    io.writefile(path.join(dir, "README.md"), readme)
    io.writefile(path.join(dir, "svr4.py"), program)
    return os.isfile(path.join(dir, "media", "base", "base12"))
end

-- Data and a script, not a program on PATH: the package name is registered so a home knows
-- it has it. The notice is printed each time, which is the condition this package is kept on.
function config()
    xvm.add(package.name)
    local dir = pkginfo.install_dir()
    log.warn("svr4-disk-image: EXPERIMENTAL, TECHNICAL VERIFICATION ONLY.")
    log.warn("  AT&T UNIX System V/386 Release 4.0 is proprietary software. Its floppy set was fetched")
    log.warn("  from a third party's repository, which states no licence; xlings does not mirror it")
    log.warn("  and grants no right to use it. This package may be disabled or removed at any time.")
    log.warn("  How to build the image and repeat the measurement: %s", path.join(dir, "README.md"))
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
