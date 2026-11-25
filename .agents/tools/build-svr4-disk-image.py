#!/usr/bin/env python3
"""Assemble svr4-disk-image from the floppy set of AT&T UNIX System V/386 Release 4.0 Version 3.0.

TECHNICAL VERIFICATION ONLY. The system is proprietary. The floppy set is the package's revision 0
asset (xlings-res/svr4-disk-image, release 4.0.3-20261119), re-hosted unchanged from the repository
the recipe records; nothing here grants a right to use it.

The system is installed by its own installer, from the twelve floppies of its Base System Package:
floppy 1 is booted in QEMU, and the installer's questions, which it asks on the screen only, are read
from the display adapter's text memory and answered on the machine's keyboard (qemu_keyboard.py); the
floppies are put in the drive as it asks for them. The answers are its defaults but two: `/' is
`ufs' (names of 255 characters; the default, `s5', has fourteen), and the system's name is `svr4'.
The machine's clock is set a day after the installer's own date, 20 February 2023, so that the
passwords it has just been given have not expired at the first login.

Root then logs in on the console once, and these are typed:

    /etc/serialsh     a root shell on the first serial line: erase ^H and kill ^U (the line's
                      defaults are `#' and `@', which a command line may hold), no echo, a file
                      size limit of 1 GiB (the default is 2 MiB), the prompt `svr4# '
    /etc/inittab      + s0:234:respawn:/sbin/sh /etc/serialsh

The system writes its slice table (prtvtoc) and what it was given to the first serial line, which is
read here. The files disk of a run carries the system's own label (dirun 0.8.0, `[files] label'):
the first 378 sectors of the installed disk, as the installer wrote them (the master boot record, the
boot slice with the pdinfo sector and the VTOC, the alternates); the archive goes where the label puts
the swap slice, which no system mounts on a second disk. Both are checked against the slice table.
Nothing is written into the image from outside. The disk is converted to qcow2 (`qemu-img convert
-c'), and the image is then run by dirun with the profile the recipe ships: a command's output and
status, and a delivered file of 3 MiB.

Layout of svr4-disk-image-<version>-r<revision>.tar.xz:

    svr4.qcow2         the installed system, 400 MiB
    files-label.bin    the label of a run's files disk (dirun's [files] label)
    README.md          what it is and is not, how to run a program on it, how it is rebuilt
    PROVENANCE.md      the floppy set, the answers, the lines typed, the slice table, the checks

usage: build-svr4-disk-image.py <out-dir> <version> <revision> <floppy-archive> <sha256>
                                <qemu-system-i386|qemu-system-x86_64> <qemu-img> <dirun> <recipe.lua>
       (KVM is used when it can be opened; without it the installation takes longer)
"""
import hashlib, re, shutil, subprocess, sys, tarfile, tempfile, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from qemu_keyboard import Machine, said  # noqa: E402

FLOPPY = 1474560
DISK_MIB = 400                   # the system does not start on a disk of much more than 500 MiB
MEMORY_MIB = 64                  # nor with 256 MiB of memory or more
CLOCK = "2023-02-21T12:00:00"    # a day after the installer's date
ROOT_PASSWORD = "sysv4r00t"      # the console's; the serial line's shell asks for none
INSTALL_PASSWORD = "sysv4inst"
SERIALSH = [
    "echo 'exec </dev/tty00 >/dev/tty00 2>&1' > /etc/serialsh",
    "echo 'stty erase \"^h\" kill \"^u\" -echo' >> /etc/serialsh",
    "echo 'ulimit 2097152' >> /etc/serialsh",
    "echo 'PS1=\"svr4# \"; export PS1; exec /sbin/sh -i' >> /etc/serialsh",
    "grep -v '^s0:' /etc/inittab > /tmp/inittab; cp /tmp/inittab /etc/inittab",
    "echo 's0:234:respawn:/sbin/sh /etc/serialsh' >> /etc/inittab",
]
# What the label and the profile state, for a 400 MiB disk laid out by the installer's defaults.
LABEL_SECTORS = 378              # up to the first slice that holds data (/stand)
FILES_SLICE = (2, "SWAP", 11466, 132048)
PDINFO_SANE = (0xCA5E600D).to_bytes(4, "little")   # sys/hd.h VALID_PD, in sector 29 of the partition
VTOC_SANE = (0x600DDEEE).to_bytes(4, "little")     # sys/vtoc.h


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def floppies(archive: Path, into: Path) -> dict:
    """The twelve floppies of the Base System Package (`base1' .. `base12'), wherever the archive
    keeps them."""
    found = {}
    with tarfile.open(archive) as t:
        for m in t.getmembers():
            name = Path(m.name).name
            if m.isfile() and re.fullmatch(r"base\d+", name) and m.size == FLOPPY:
                t.extract(m, into, filter="data")
                found[int(name[4:])] = into / m.name
    if sorted(found) != list(range(1, 13)):
        raise SystemExit(f"{archive}: expected the floppies base1 .. base12, found {sorted(found)}")
    return found


def install(m: Machine, fl: dict, com1: Path) -> str:
    """The installer's dialogue, then the first login and the serial line's shell. Returns what the
    system wrote to its first serial line."""
    m.shown("Floppy Disk 2 and then strike ENTER", 300)
    m.insert("floppy0", fl[2]); m.key("ret")
    m.shown("Please strike ENTER to install the UNIX System", 300); m.key("ret")
    m.shown("Do you wish to continue (y or n)?", 120); m.type("y")
    m.shown("Please strike ENTER when ready or DEL", 120); m.key("ret")
    m.shown('To select this, please type "y"', 120, tail=6); m.type("y")
    m.shown("Please press ENTER for the default type", 120); m.type("ufs")
    m.shown("disk slices or filesystems (y or n)?", 120); m.type("n")
    m.shown("Is this correct (y or n)?", 120); m.type("y")
    m.shown("Please strike ENTER to continue or DEL to cancel", 120); m.key("ret")
    m.shown("Is this configuration acceptable? (y/n)", 900); m.type("y")
    m.shown("Reboot the system now.", 900)
    m.eject("floppy0"); m.monitor("system_reset")
    # The system on the disk asks for the other ten. Its first question takes one key, and drops a
    # key pressed before it has settled.
    m.shown('or "F" to install from FLOPPY DISKETTE', 300, tail=6)
    for _ in range(20):
        time.sleep(5)
        m.key("f")
        time.sleep(3)
        if "Floppy Disk 3 of 12" in m.screen():
            break
    for n in range(3, 13):
        m.shown(f"Floppy Disk {n} of 12 and then strike ENTER", 900)
        m.insert("floppy0", fl[n]); m.key("ret")
        print(f"build-svr4-disk-image: floppy {n} of 12", file=sys.stderr, flush=True)
    m.shown("New password:", 900); m.type(ROOT_PASSWORD)
    m.shown("Re-enter new password:", 60); m.type(ROOT_PASSWORD)
    m.shown("Enter a password for the 'install' user", 120, tail=6)
    m.shown("New password:", 60); m.type(INSTALL_PASSWORD)
    m.shown("Re-enter new password:", 60); m.type(INSTALL_PASSWORD)
    m.shown("Enter System Name:", 120); m.type("svr4")
    m.shown("Reboot the system now.", 900)
    m.eject("floppy0"); m.monitor("system_reset")
    # The first login, on the console.
    m.shown("Console Login:", 600); m.type("root")
    m.shown("Password:", 60); m.type(ROOT_PASSWORD)
    time.sleep(5)
    if "Choose a new one" in m.screen():  # not expected at this clock; answered if asked
        m.shown("New password:", 60); m.type(ROOT_PASSWORD[::-1])
        m.shown("Re-enter new password:", 60); m.type(ROOT_PASSWORD[::-1])
        time.sleep(5)
    m.type("echo LOGGED''-IN > /dev/tty00")
    if not said(com1, "LOGGED-IN", 60):
        raise SystemExit("root did not log in on the console; the screen shows:\n" + m.screen())
    for line in SERIALSH:
        m.type(line)
        time.sleep(1)
    m.type("prtvtoc /dev/rdsk/0s0 > /dev/tty00; uname -a > /dev/tty00")
    m.type("(cat /etc/serialsh; grep '^s0:' /etc/inittab; echo CONFIG''URED) > /dev/tty00")
    if not said(com1, "CONFIGURED", 120):
        raise SystemExit("the system did not write its configuration; the screen shows:\n" + m.screen())
    m.type("cd /; sync; sync; shutdown -y -g0 -i0")
    m.shown("Reboot the system now.", 300)
    return com1.read_text(errors="replace")


def slices(table: str) -> dict:
    return {int(n): (tag, int(start), int(length)) for n, tag, start, length in re.findall(
        r"slice (\d+):\s+(\S+).*?starting sector:\s+(\d+)[^\n]*?length:\s+(\d+)", table, re.S)}


def run(dirun, profile, qemu, words, files=()):
    argv = [dirun, "--profile", str(profile), "--emulator", qemu, "--timeout", "300"]
    for f in files:
        argv += ["--file", f]
    r = subprocess.run(argv + ["--"] + words, capture_output=True, text=True, errors="replace")
    return r.returncode, r.stdout + r.stderr


def main() -> int:
    if len(sys.argv) != 10:
        print(__doc__, file=sys.stderr)
        return 2
    out, version, revision = Path(sys.argv[1]).resolve(), sys.argv[2], int(sys.argv[3])
    archive, stated = Path(sys.argv[4]).resolve(), sys.argv[5]
    qemu, qemu_img, dirun, recipe = sys.argv[6], sys.argv[7], sys.argv[8], Path(sys.argv[9])
    if sha256(archive) != stated:
        raise SystemExit(f"{archive}: the digest differs from the one given")
    profile = re.search(r"local profile = \[=\[\n(.*?)\]=\]", recipe.read_text(), re.S)
    if not profile:
        raise SystemExit(f"{recipe}: no `local profile = [=[ ... ]=]'")
    qemu_said = subprocess.run([qemu, "--version"], capture_output=True, text=True).stdout.splitlines()[0]
    dirun_said = subprocess.run([dirun, "--version"], capture_output=True, text=True).stdout.strip()
    out.mkdir(parents=True, exist_ok=True)
    name = f"svr4-disk-image-{version}-r{revision}"
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        tmp = Path(tmp)
        fl = floppies(archive, tmp / "floppies")
        for n, f in list(fl.items()):  # the installer writes to its floppies: copies
            fl[n] = shutil.copyfile(f, tmp / f"base{n}")
        raw, com1 = tmp / "disk.raw", tmp / "com1.log"
        subprocess.run([qemu_img, "create", "-q", "-f", "raw", str(raw), f"{DISK_MIB}M"], check=True)
        m = Machine([qemu, "-accel", "kvm", "-accel", "tcg", "-machine", "pc", "-cpu", "pentium",
                     "-m", str(MEMORY_MIB), "-rtc", f"base={CLOCK}", "-net", "none", "-display", "none",
                     "-drive", f"file={raw},format=raw,if=ide,index=0,cache=writeback",
                     "-drive", f"file={fl[1]},format=raw,if=floppy", "-boot", "a",
                     "-serial", f"file:{com1}"])
        m.pace = 0.06    # the installer's console drops keys typed faster
        try:
            print("build-svr4-disk-image: floppy 1 boots; the installer's questions follow", file=sys.stderr, flush=True)
            answered = install(m, fl, com1)
        finally:
            m.monitor("quit")
            try:
                m.p.wait(timeout=30)
            except subprocess.TimeoutExpired:
                pass
            m.stop()

        # The slice table, the label and the files slice.
        table = slices(answered)
        tag, start, length = table.get(FILES_SLICE[0], ("", 0, 0))
        data_starts = [s for n, (t, s, _) in table.items() if t not in ("DISK", "BOOT", "ALTERNATES")]
        if (FILES_SLICE[1], FILES_SLICE[2], FILES_SLICE[3]) != (tag, start, length) or min(data_starts) != LABEL_SECTORS:
            raise SystemExit(f"the slice table is not the one the profile states:\n{answered}")
        for want in ("svr4 svr4 4.0 3.0 i386", "s0:234:respawn:/sbin/sh /etc/serialsh", "ulimit 2097152"):
            if want not in answered:
                raise SystemExit(f"the system did not answer `{want}':\n{answered}")
        root = tmp / name
        root.mkdir()
        with raw.open("rb") as f:
            label = f.read(LABEL_SECTORS * 512)
        if label[510:512] != b"\x55\xaa" or PDINFO_SANE not in label or VTOC_SANE not in label:
            raise SystemExit("the first sectors of the disk are not the system's label")
        (root / "files-label.bin").write_bytes(label)
        subprocess.run([qemu_img, "convert", "-c", "-O", "qcow2", str(raw), str(root / "svr4.qcow2")], check=True)
        raw.unlink()

        # The image as the runner boots it: the recipe's profile, beside the image for the checks.
        check = root / "dirun.toml"
        check.write_text(profile.group(1))
        big = tmp / "big.bin"
        big.write_bytes(bytes(range(256)) * (3 << 12))
        checks = []
        for words, files, want_status, want in (
                (["uname", "-a"], (), 0, "svr4 svr4 4.0 3.0 i386 386/AT"),
                (["wc", "-c", "big.bin"], (f"{big}=big.bin",), 0, f"{3 << 20} big.bin"),
                (["sh", "-c", "exit 7"], (), 7, "")):
            t0 = time.time()
            status, said_ = run(dirun, check, qemu, words, files)
            if status != want_status or want not in " ".join(said_.split()):
                raise SystemExit(f"dirun {' '.join(words)}: status {status}, said:\n{said_}")
            checks.append((" ".join(words), status, said_.strip().splitlines()[-1] if said_.strip() else "",
                           time.time() - t0))
            print(f"build-svr4-disk-image: dirun {' '.join(words)}: status {status} ({time.time() - t0:.1f} s)",
                  file=sys.stderr, flush=True)
        check.unlink()

        table_text = "\n".join("    " + line for line in answered.splitlines()
                               if re.match(r"\s*(slice|starting)", line))
        (root / "README.md").write_text(README.format(version=version, revision=revision))
        (root / "PROVENANCE.md").write_text(PROVENANCE.format(
            archive=archive.name, sha=stated, version=version, qemu=qemu_said, dirun=dirun_said,
            serialsh="\n".join("    " + l for l in SERIALSH), table=table_text, label=LABEL_SECTORS,
            offset=FILES_SLICE[2] * 512, size=(FILES_SLICE[2] + FILES_SLICE[3]) * 512,
            checks="\n".join(f"| `{w}` | {s} | {f'`{o}`' if o else '(nothing)'} | {t:.1f} s |" for w, s, o, t in checks),
            clock=CLOCK, memory=MEMORY_MIB, disk=DISK_MIB))
        packed = out / f"{name}.tar.xz"
        subprocess.run(["tar", "-C", str(tmp), "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                        "-cf", str(packed.with_suffix("")), name], check=True)
        subprocess.run(["xz", "-T0", "-6", "-f", str(packed.with_suffix(""))], check=True)
        print(packed, sha256(packed), packed.stat().st_size)
    return 0


README = """# svr4-disk-image --- TECHNICAL VERIFICATION ONLY

AT&T UNIX System V/386 Release 4.0 Version 3.0 (1990), installed from its floppy set into a disk
image for QEMU, with a root shell on its first serial line. It exists to check that a program built
for the System V i386 interface (`i686-svr4-musl`, openkal-svr4) runs on a System V kernel, and for
nothing else.

## What this is not

- **Not free software.** The system is proprietary. Its floppy set is re-hosted unchanged by xlings
  from a third party's repository, which states no licence for it, and this image is installed from
  it. Nothing here grants a right to use it: whether you may is for you to settle. The package may be
  disabled or removed at any time.
- **Not for any other use.** One machine with no network; the shell on the serial line asks for no
  password.

## Running a program

The package's `dirun.toml` boots the image and runs one command (dirun 0.8.0 or later: a run's files
go on a second disk behind the system's own label, `files-label.bin`):

    dirun --profile <package>/dirun.toml --emulator qemu-system-x86_64 -- ./program arguments

The status is the program's. The image is never written: each run boots an overlay of it. Through
mcpp, a project states the runner for the row:

    [target.i686-svr4-musl]
    runner = {{ cmd = ["dirun", "--profile", "{{pkg:svr4-disk-image}}/dirun.toml",
                      "--emulator", "{{pkg:qemu-x86}}/bin/qemu-system-x86_64", "--", "{{}}"],
               host = "any", hosts = ["linux-x86_64"],
               requires = ["xim:dirun@0.8.0", "xim:svr4-disk-image@{version}", "xim:qemu-x86@9.2.4-1"],
               enabled = false }}

## Rebuilding it

`.agents/tools/build-svr4-disk-image.py` in xim-pkgindex, from the package's revision 0 asset (the
floppy set). `PROVENANCE.md` states the inputs, the installer's answers, the lines typed and the
checks. This is revision {revision} of version {version}.

## Limits

- The machine has at most 255 MiB of memory (the profile states 64) and a disk of about 500 MiB.
- A run's files are at most 64 MiB: the archive goes where the label puts the swap slice.
- The Base System Package only: no compiler, no networking.
"""

PROVENANCE = """# Provenance

TECHNICAL VERIFICATION ONLY: AT&T UNIX System V/386 Release 4.0 Version 3.0 is proprietary.

Assembled by `build-svr4-disk-image.py` (xim-pkgindex `.agents/tools/`) from the floppy set of the
system's Base System Package, the package's revision 0 asset, re-hosted unchanged from
https://github.com/Sunrisepeak/svr4-386-src:

    {archive}
        sha256 {sha}

Installed by the system's own installer in QEMU ({qemu}): a {disk} MiB disk, {memory} MiB of memory,
the clock at {clock} (a day after the installer's date). The installer's questions, read on the
screen, were answered with its defaults but two: `/` is `ufs`, and the system's name is `svr4`. The
root password is `sysv4r00t`, the `install` user's `sysv4inst`.

Typed on the console after the first login, as root:

{serialsh}

The slice table the system wrote (prtvtoc /dev/rdsk/0s0):

{table}

`files-label.bin` is the disk's first {label} sectors as the installer wrote them, up to the first
slice that holds data: the master boot record, the boot slice with the pdinfo sector and the VTOC,
and the alternates. A run's files disk carries it, and its archive starts at byte {offset}, where the
label puts the swap slice; the disk is {size} bytes, the end of that slice (dirun's `[files] label`,
`offset`, `size`). Nothing was written into the image from outside. The disk was converted to qcow2
(`qemu-img convert -c`).

Checked by dirun {dirun} with the profile the recipe ships, on the image as published:

| Command | Status | Last line | Time |
|---|---|---|---|
{checks}
"""

if __name__ == "__main__":
    sys.exit(main())
