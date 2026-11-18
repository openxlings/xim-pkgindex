#!/usr/bin/env python3
"""Assemble haiku-disk-image from one of Haiku's nightly images.

The image (`haiku-master-hrev<N>-x86_64-anyboot.zip`, download.haiku-os.org/nightly-images)
is a bootable disk of the system as it runs from the medium: a desktop, with no login and
no console but the screen. Two changes make it a runner's image, and they are made by the
system itself: the image is booted once in QEMU, its Terminal is opened from the keyboard
(Alt+Win+T), and these lines are typed:

    the kernel does not write to the serial line    ~/config/settings/kernel/drivers/kernel:
                                                    `serial_debug_output false'
    a shell on the first serial line                ~/config/settings/boot/UserBootscript: SHELL below

The serial port's driver gives the port to one opener, so the shell has it as one
descriptor, read and written. The system is then shut down and booted again, without
keeping what that boot writes, to see the shell's prompt on the serial line before the
disk is kept. Nothing is written into the image from outside. The disk is then
converted to qcow2, and the archive compresses it.

Layout of haiku-disk-image-<version>.tar.xz:

    haiku-x86_64.qcow2
    PROVENANCE.md

usage: build-haiku-disk-image.py <out-dir> <version> <anyboot.zip> <sha256> <qemu-system-x86_64> <qemu-img>
       (needs an accelerator: the system is prepared by running it)
"""
import hashlib, subprocess, sys, tempfile, time, zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from qemu_keyboard import Machine, said  # noqa: E402

PORT = "/dev/ports/pc_serial0"
PROMPT = "haiku# "
SHELL = (f"(while true; do (exec <> {PORT} >&0 2>&0; stty sane 115200; PS1='{PROMPT}' exec /bin/sh -i); "
         "sleep 1; done) &")
DESKTOP_SECONDS = 90    # the published image's boot to its first window, under an accelerator
PREPARE = [
    "mkdir -p ~/config/settings/kernel/drivers ~/config/settings/boot",
    "echo serial_debug_output false >> ~/config/settings/kernel/drivers/kernel",
    f'echo "{SHELL}" >> ~/config/settings/boot/UserBootscript',
    f"sync; (tail -1 ~/config/settings/boot/UserBootscript; echo PREPARED) > {PORT}",
]


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main() -> int:
    if len(sys.argv) != 7:
        print(__doc__, file=sys.stderr)
        return 2
    out, version, archive, stated = Path(sys.argv[1]).resolve(), sys.argv[2], Path(sys.argv[3]).resolve(), sys.argv[4]
    qemu, qemu_img = sys.argv[5], sys.argv[6]
    if sha256(archive) != stated:
        raise SystemExit(f"{archive}: the digest differs from the one given")
    out.mkdir(parents=True, exist_ok=True)
    name = f"haiku-disk-image-{version}"
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        tmp = Path(tmp)
        with zipfile.ZipFile(archive) as z:
            images = [m for m in z.namelist() if m.endswith(".iso") and "/" not in m]
            if len(images) != 1:
                raise SystemExit(f"{archive}: expected one .iso, found {len(images)}")
            z.extract(images[0], tmp)
        raw = tmp / images[0]
        machine = [qemu, "-machine", "q35", "-accel", "kvm", "-accel", "tcg", "-cpu", "max", "-smp", "2", "-m", "2048",
                   "-display", "none", "-vga", "std", "-no-reboot"]
        said_file = tmp / "prepare.log"
        m = Machine(machine + ["-drive", f"file={raw},format=raw,if=ide", "-serial", f"file:{said_file}"])
        try:
            # The first boot asks for a language and whether to install: Enter takes the
            # desktop. The Terminal follows, and the lines; the last is the system's answer.
            time.sleep(DESKTOP_SECONDS)
            m.key("ret")
            time.sleep(40)
            m.key("alt-meta_l-t")
            time.sleep(10)
            for line in PREPARE:
                m.type(line)
                time.sleep(2)
            if not said(said_file, "PREPARED", 120):
                raise SystemExit("the system did not finish the preparation")
            if SHELL not in said_file.read_text(errors="replace"):
                raise SystemExit("the system's boot script does not end with the shell's line")
            m.type("shutdown")
            m.p.wait(timeout=180)
        finally:
            m.stop()
        check_file = tmp / "check.log"
        m = Machine(machine + ["-drive", f"file={raw},format=raw,if=ide,snapshot=on", "-serial", f"file:{check_file}"])
        try:
            if not said(check_file, PROMPT, 300):
                raise SystemExit("the prepared system gave no shell on its serial line")
        finally:
            m.stop()
        root = tmp / name
        root.mkdir()
        subprocess.run([qemu_img, "convert", "-c", "-O", "qcow2", str(raw), str(root / "haiku-x86_64.qcow2")], check=True)
        raw.unlink()
        (root / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-haiku-disk-image.py` from Haiku's nightly image for x86_64
https://download.haiku-os.org/nightly-images/x86_64/

    {archive.name}
        sha256 {stated}

Changed, by the system itself (booted once, its Terminal opened and the lines typed as its keyboard):

    ~/config/settings/kernel/drivers/kernel   + serial_debug_output false
    ~/config/settings/boot/UserBootscript     + {SHELL}

and what a boot writes (settings of the first start, logs). Nothing is written into the image
from outside. The disk is converted to qcow2 (`qemu-img convert -c`).
''')
        packed = out / f"{name}.tar.xz"
        subprocess.run(["tar", "-C", str(tmp), "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                        "-cf", str(packed.with_suffix("")), name], check=True)
        subprocess.run(["xz", "-T0", "-1", "-f", str(packed.with_suffix(""))], check=True)
        print(packed, sha256(packed), packed.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
