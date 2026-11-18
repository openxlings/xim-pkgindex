#!/usr/bin/env python3
"""Assemble the x86_64-hurd-sysroot base package from Debian GNU/Hurd's packages.

The package root is the sysroot (mcpp design 2026-11-10 E5): the C library (glibc on
the Hurd), the headers of the Hurd and of GNU Mach, libxcrypt, and GCC's run-time and
libstdc++, as Debian's `hurd-amd64` port builds them. The packages are the ones listed
below, each held to its sha256; a `.deb` is read here (an `ar` archive holding
`data.tar.*`), so no tool of Debian's is needed.

Debian is a merged-/usr system: `lib` is a link to `usr/lib`, and the loader a program
names (`/lib/ld-x86-64.so.1`) is found through it.

Layout of x86_64-hurd-sysroot-<version>/:

    mcpp.toml                       the package manifest: provides, [build]
    PROVENANCE.md
    lib -> usr/lib   usr/include   usr/lib

usage: build-hurd-sysroot.py <out-dir> <version> [<directory of the .deb files>]
       (a package that is not in the directory is fetched from MIRROR)
"""
import hashlib, io, subprocess, sys, tarfile, tempfile, urllib.request
from pathlib import Path

MIRROR = "http://deb.debian.org/debian-ports/"
# name, version, path beneath the mirror, sha256
PACKAGES = [
    ("gnumach-dev", "2:1.8+git20261028-2", "pool-hurd-amd64/main/g/gnumach/gnumach-dev_1.8+git20261028-2_hurd-amd64.deb",
     "fdc97ea53c74d8d0439044b5c9afef25171234b217ba671a95b770749a5d5f13"),
    ("hurd-dev", "1:0.9.git20261028-4", "pool-hurd-amd64/main/h/hurd/hurd-dev_0.9.git20261028-4_hurd-amd64.deb",
     "12d304ca12c194fa1c073bc2cdde996ea14bf8f409e52a1530c976a375d6093d"),
    ("hurd-libs0.3", "1:0.9.git20261028-4", "pool-hurd-amd64/main/h/hurd/hurd-libs0.3_0.9.git20261028-4_hurd-amd64.deb",
     "84907a4b41f57113a456055b3155728a0e7a205b613479b866fc2ec1f1c0dc2b"),
    ("libc0.3-dev", "2.43-7", "pool-hurd-amd64/main/g/glibc/libc0.3-dev_2.43-7_hurd-amd64.deb",
     "6be6dd60aff4ff99776b45d4ae4b4eeafe8f0539ba12c6386d85d152e34a456b"),
    ("libc0.3", "2.43-7", "pool-hurd-amd64/main/g/glibc/libc0.3_2.43-7_hurd-amd64.deb",
     "d014aab99750f218b41e5e9d9dfe836cda307f57728055b0c0a1575caeefad65"),
    ("libcrypt-dev", "1:4.5.2+20251210-1", "pool-hurd-amd64/main/libx/libxcrypt/libcrypt-dev_4.5.2+20251210-1_hurd-amd64.deb",
     "a38d77512a5ec4cf38b2e230227d3a240a0a3ef753c96761b8cd9fac39a2bcd4"),
    ("libcrypt1", "1:4.5.2+20251210-1", "pool-hurd-amd64/main/libx/libxcrypt/libcrypt1_4.5.2+20251210-1_hurd-amd64.deb",
     "a864034aed39a349e4f5e753ea55679706883a83e47cbdc1e4cc1e349210a104"),
    ("libgcc-16-dev", "16.2.0-4", "pool-hurd-amd64/main/g/gcc-16/libgcc-16-dev_16.2.0-4_hurd-amd64.deb",
     "4cad3e41d09e8d289c31e463c265258f9faa0cd45cf956c4762604312a4d32bd"),
    ("libgcc-s1", "16.2.0-4", "pool-hurd-amd64/main/g/gcc-16/libgcc-s1_16.2.0-4_hurd-amd64.deb",
     "f7343a0e36d49a73b79b29c162f5d9b31f55ef2c9d77d812334bc454144f9b36"),
    ("libstdc++-16-dev", "16.2.0-4", "pool-hurd-amd64/main/g/gcc-16/libstdc++-16-dev_16.2.0-4_hurd-amd64.deb",
     "9154af9923602b49025ac838c0d9855e168d3b468e9713039b03b97bc49b0e46"),
    ("libstdc++6", "16.2.0-4", "pool-hurd-amd64/main/g/gcc-16/libstdc++6_16.2.0-4_hurd-amd64.deb",
     "d8e1049e7f68bb048758c739ce3006daf645367fbef2a987bb76027060e6aec7"),
]
KEEP = ("usr/include/", "usr/lib/")
DROP = ("usr/lib/x86_64-gnu/gconv/", "usr/lib/x86_64-gnu/audit/", "usr/lib/locale/", "usr/lib/debug/")
REQUIRED = ("usr/include/stdio.h", "usr/include/hurd.h", "usr/include/mach.h", "usr/lib/x86_64-gnu/crt1.o",
            "usr/lib/x86_64-gnu/libc.so", "usr/lib/x86_64-gnu/libc.so.0.3", "usr/lib/x86_64-gnu/ld-x86-64.so.1",
            "usr/lib/gcc/x86_64-gnu/16/libgcc.a", "usr/lib/gcc/x86_64-gnu/16/crtbegin.o")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def data_of(deb: bytes) -> tarfile.TarFile:
    """The `data.tar.*' member of a .deb (an `ar' archive: a magic, then 60-byte headers)."""
    if deb[:8] != b"!<arch>\n":
        raise SystemExit("not a .deb: no ar magic")
    at = 8
    while at + 60 <= len(deb):
        name = deb[at:at + 16].decode().strip().rstrip("/")
        size = int(deb[at + 48:at + 58].decode().strip())
        body = deb[at + 60:at + 60 + size]
        if name.startswith("data.tar"):
            return tarfile.open(fileobj=io.BytesIO(body))
        at += 60 + size + (size & 1)
    raise SystemExit("a .deb with no data.tar member")


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(__doc__, file=sys.stderr)
        return 2
    out, version = Path(sys.argv[1]).resolve(), sys.argv[2]
    have = Path(sys.argv[3]).resolve() if len(sys.argv) == 4 else None
    out.mkdir(parents=True, exist_ok=True)
    name = f"x86_64-hurd-sysroot-{version}"
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        root = Path(tmp) / name
        root.mkdir()
        for package, _, path, digest in PACKAGES:
            local = have / Path(path).name if have else None
            deb = local.read_bytes() if local and local.is_file() else urllib.request.urlopen(MIRROR + path).read()
            if sha256(deb) != digest:
                raise SystemExit(f"{package}: the digest differs from the one this script states")
            with data_of(deb) as t:
                members = []
                for m in t.getmembers():
                    s = m.name.lstrip("./")
                    if not s.startswith(KEEP) or s.startswith(DROP):
                        continue
                    if not (m.isfile() or m.isdir() or m.issym() or m.islnk()):
                        continue
                    members.append(m)
                t.extractall(root, members=members, filter="tar")
        (root / "lib").symlink_to("usr/lib")
        for f in REQUIRED:
            if not (root / f).exists():
                raise SystemExit(f"the sysroot lacks {f}")
        (root / "mcpp.toml").write_text(f'''# A base package (mcpp design 2026-11-10 E5): the package root is the sysroot
# of x86_64-hurd.
[package]
name        = "x86_64-hurd-sysroot"
version     = "{version}"
description = "Debian GNU/Hurd base system (hurd-amd64) for compiling and linking"
license     = "LGPL-2.1-or-later AND GPL-2.0-or-later AND GPL-3.0-or-later WITH GCC-exception-3.1"
provides    = ["mcpp:c-abi=glibc", "mcpp:c++-abi=libstdc++", "mcpp:compiler-runtime=libgcc",
               "hosted-standard-library"]

[build]
# The compiler's own run-time is not built for this system: the base's is taken,
# libgcc and its unwinder, with GCC's libstdc++.
cxxflags = ["-stdlib=libstdc++"]
ldflags  = ["-rtlib=libgcc", "--unwindlib=libgcc"]
''')
        listed = "\n".join(f"    {p} {v}\n        {MIRROR}{path}\n        sha256 {d}" for p, v, path, d in PACKAGES)
        (root / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-hurd-sysroot.py` from the packages of Debian GNU/Hurd's `hurd-amd64` port
(debian-ports, `sid`), each checked against the digest the script states:

{listed}

Taken without modification: `usr/include` and `usr/lib` of each package, without the
C library's character-set modules (`gconv`), its audit modules and locale data. Added:
the link `lib -> usr/lib` (Debian's merged /usr), `mcpp.toml` and this file.
''')
        archive = out / f"{name}.tar.xz"
        subprocess.run(["tar", "-C", tmp, "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                        "--mtime=@0", "-cf", str(archive.with_suffix("")), name], check=True)
        subprocess.run(["xz", "-T0", "-9", "-f", str(archive.with_suffix(""))], check=True)
        print(archive, sha256(archive.read_bytes()), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
