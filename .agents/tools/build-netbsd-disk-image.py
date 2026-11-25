#!/usr/bin/env python3
"""Assemble netbsd-disk-image from The NetBSD Foundation's official live image.

The live image (`NetBSD-<version>-amd64-live.img.gz`, images/<version>/ on
cdn.netbsd.org) is a bootable disk of the installed system. One change makes it a
runner's image: `/boot.cfg` names the serial line as the console (`consdev=com0`)
and boots without waiting, so the boot loader, the kernel and the login all speak on
the line an emulator's runner reads. The file is rewritten in place, at its own
length, inside the root file system; nothing else is touched. The disk is then
converted to qcow2, and the archive compresses it.

Layout of netbsd-disk-image-<version>.tar.xz:

    netbsd-<version>.qcow2
    PROVENANCE.md

usage: build-netbsd-disk-image.py <out-dir> <version> <live.img.gz> <SHA512> <qemu-img>
"""
import gzip, hashlib, shutil, subprocess, sys
from pathlib import Path

# The live image's /boot.cfg as published (10.x), and what replaces it. The
# replacement keeps the length: it is padded with a comment line.
ORIGINAL_START = b"menu=Boot normally:rndseed /var/db/entropy-file;boot\n"
REPLACEMENT = (b"consdev=com0\n"
               b"menu=Boot normally:rndseed /var/db/entropy-file;boot\n"
               b"menu=Drop to boot prompt:prompt\n"
               b"default=1\n"
               b"timeout=1\n")


def digest(p: Path, algo: str) -> str:
    h = hashlib.new(algo)
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def boot_cfg(raw: Path) -> tuple[int, int]:
    """The offset and length of /boot.cfg's bytes: the one block that starts with the
    published first line and ends at the file's last line (`timeout=...`)."""
    data = raw.read_bytes()
    hits = []
    at = data.find(ORIGINAL_START)
    while at != -1:
        end = data.find(b"\n", data.find(b"timeout=", at)) + 1
        if 0 < end - at < 512:
            hits.append((at, end - at))
        at = data.find(ORIGINAL_START, at + 1)
    if len(hits) != 1:
        raise SystemExit(f"{raw}: /boot.cfg was found {len(hits)} times, not once")
    return hits[0]


def main() -> int:
    out, version, gz, sums, qemu_img = (Path(sys.argv[1]).resolve(), sys.argv[2], Path(sys.argv[3]).resolve(),
                                        Path(sys.argv[4]).resolve(), sys.argv[5])
    stated = next(l.rsplit(" ", 1)[1] for l in sums.read_text().splitlines()
                  if l.startswith(f"SHA512 ({gz.name}) = "))
    if digest(gz, "sha512") != stated:
        raise SystemExit(f"{gz}: the digest differs from the release's SHA512")
    out.mkdir(parents=True, exist_ok=True)
    work = out / f"netbsd-disk-image-{version}"
    work.mkdir(exist_ok=True)
    raw = out / f"netbsd-{version}.img"
    with gzip.open(gz, "rb") as src, raw.open("wb") as dst:
        shutil.copyfileobj(src, dst, 1 << 20)
    off, length = boot_cfg(raw)
    new = REPLACEMENT + b"#" * (length - len(REPLACEMENT) - 1) + b"\n"
    assert len(new) == length
    with raw.open("r+b") as f:
        f.seek(off)
        f.write(new)
    image = work / f"netbsd-{version}.qcow2"
    subprocess.run([qemu_img, "convert", "-O", "qcow2", str(raw), str(image)], check=True)
    raw.unlink()
    (work / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-netbsd-disk-image.py` from The NetBSD Foundation's official live image
https://cdn.netbsd.org/pub/NetBSD/images/{version}/{gz.name}, checked against the release's
SHA512 file:

    {gz.name}
        sha512 {stated}
        sha256 {digest(gz, "sha256")}

Changed: `/boot.cfg` (at byte {off} of the disk, {length} bytes, rewritten at its own length)
names the serial console and boots after one second:

{new.decode().rstrip(chr(10)).rstrip("#").rstrip()}

Nothing else is changed. The disk is converted to qcow2 (`qemu-img convert`).
''')
    archive = out / f"netbsd-disk-image-{version}.tar.xz"
    subprocess.run(["tar", "-C", str(out), "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                    "-cJf", str(archive), work.name], check=True)
    print(archive, digest(archive, "sha256"), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
