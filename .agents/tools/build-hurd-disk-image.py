#!/usr/bin/env python3
"""Assemble hurd-disk-image from Debian GNU/Hurd's pre-installed image.

The image (`debian-hurd-<date>.img.tar.xz`, cdimage/ports/latest/hurd-amd64 on
cdimage.debian.org) is a bootable disk of the installed system whose login is on the
screen's console only. Three changes make it a runner's image, and they are made by
the system itself: the image is booted once in QEMU, root logs in on the console (the
image has no password for it), and these lines are typed, as the emulator's keyboard:

    a login on the first serial line       /etc/inittab: `s0:23:respawn:/sbin/getty 115200 com0'
    the boot menu waits one second         /etc/default/grub: GRUB_TIMEOUT=1, then update-grub
    no interface is brought up at boot     /etc/network/interfaces: `auto' and `allow-hotplug' commented

The last is so that a machine with no network does not wait for an address. What the
system answered is read from its second serial line and checked before the disk is
kept. Nothing is written into the image from outside. The disk is then converted to
qcow2, and the archive compresses it.

Layout of hurd-disk-image-<version>.tar.xz:

    debian-hurd-amd64.qcow2
    PROVENANCE.md

usage: build-hurd-disk-image.py <out-dir> <version> <debian-hurd.img.tar.xz> <sha256> <qemu-system-x86_64> <qemu-img>
       (needs an accelerator: the system is prepared by running it)
"""
import hashlib, subprocess, sys, tarfile, tempfile, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from qemu_keyboard import Machine, said  # noqa: E402

GETTY = "s0:23:respawn:/sbin/getty 115200 com0"
BOOT_SECONDS = 150      # the published image's boot under an accelerator, with its wait for an address
PREPARE = [
    f"echo '{GETTY}' >> /etc/inittab",
    "sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub",
    "sed -i 's/^auto /#auto /; s/^allow-hotplug /#allow-hotplug /' /etc/network/interfaces",
    "update-grub > /dev/null 2>&1; echo GRUB=$? > /dev/com1",
    "(tail -1 /etc/inittab; grep ^GRUB_TIMEOUT= /etc/default/grub; grep -c '^auto ' /etc/network/interfaces) > /dev/com1",
    "sync; sync; echo PREPARED > /dev/com1",
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
    name = f"hurd-disk-image-{version}"
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        tmp = Path(tmp)
        with tarfile.open(archive) as t:
            images = [m for m in t.getmembers() if m.name.endswith(".img")]
            if len(images) != 1:
                raise SystemExit(f"{archive}: expected one .img, found {len(images)}")
            t.extract(images[0], tmp, filter="tar")
        raw = tmp / images[0].name
        said_file = tmp / "com1.log"
        m = Machine([qemu, "-accel", "kvm", "-accel", "tcg", "-cpu", "max", "-m", "2048",
                     "-drive", f"file={raw},format=raw,if=ide,cache=writeback", "-display", "none", "-vga", "std",
                     "-serial", "null", "-serial", f"file:{said_file}", "-no-reboot"])
        try:
            # Nothing is typed until the system has started: a key pressed in the boot menu stops
            # its countdown, and the menu then waits for ever. The console's login follows; root
            # is typed until a shell answers on the second serial line.
            time.sleep(BOOT_SECONDS)
            for _ in range(40):
                m.type("root")
                time.sleep(4)
                m.type("echo READY > /dev/com1")
                if said(said_file, "READY", 8):
                    break
            else:
                raise SystemExit("the system gave no root shell on its console")
            for line in PREPARE:
                m.type(line)
                time.sleep(2)
            if not said(said_file, "PREPARED", 180):
                raise SystemExit("the system did not finish the preparation")
            answered = said_file.read_text(errors="replace")
            for want in ("GRUB=0", GETTY, "GRUB_TIMEOUT=1"):
                if want not in answered:
                    raise SystemExit(f"the system did not answer `{want}':\n{answered}")
            m.type("poweroff")
            m.p.wait(timeout=180)
        finally:
            m.stop()
        root = tmp / name
        root.mkdir()
        subprocess.run([qemu_img, "convert", "-c", "-O", "qcow2", str(raw), str(root / "debian-hurd-amd64.qcow2")], check=True)
        raw.unlink()
        (root / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-hurd-disk-image.py` from Debian GNU/Hurd's pre-installed image for `hurd-amd64`
https://cdimage.debian.org/cdimage/ports/latest/hurd-amd64/{archive.name}

    {archive.name}
        sha256 {stated}

Changed, by the system itself (booted once, root on its console, the lines typed as its keyboard):

    /etc/inittab              + {GETTY}
    /etc/default/grub         GRUB_TIMEOUT=1, then `update-grub`
    /etc/network/interfaces   `auto` and `allow-hotplug` lines commented

and what a boot writes (logs, the random seed). Nothing is written into the image from outside.
The disk is converted to qcow2 (`qemu-img convert -c`).
''')
        packed = out / f"{name}.tar.xz"
        subprocess.run(["tar", "-C", str(tmp), "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                        "-cf", str(packed.with_suffix("")), name], check=True)
        subprocess.run(["xz", "-T0", "-1", "-f", str(packed.with_suffix(""))], check=True)
        print(packed, sha256(packed), packed.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
