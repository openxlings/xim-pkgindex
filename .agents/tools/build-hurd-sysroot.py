#!/usr/bin/env python3
"""Assemble the x86_64-hurd-sysroot base package from Debian GNU/Hurd's packages.

The package root is the sysroot (mcpp design 2026-11-10 E5): the C library (glibc on
the Hurd), the headers of the Hurd and of GNU Mach, libxcrypt, and GCC's run-time and
libstdc++, as Debian's `hurd-amd64` port builds them. The packages are the ones listed
below, each held to its sha256; a `.deb` is read here (an `ar` archive holding
`data.tar.*`), so no tool of Debian's is needed.

The versions are the ones Debian's pre-installed image of the same date has
(hurd-disk-image), taken from the archive's snapshot of that date: a program is built
against the libraries it runs with. (20261118 was assembled from `sid` of its day; its
libstdc++, GCC 16's, is newer than the image's, and a C++ program built against it did
not start there: `GLIBCXX_3.4.36' not found.) The manifest states GCC's std module
sources, so the row compiles `import std`.

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

MIRROR = "https://snapshot.debian.org/archive/debian-ports/20260314T000000Z/"
GCC = "15"
# name, version, path beneath the mirror, sha256: the versions hurd-disk-image@20260314 has
# (dpkg-query in that image; libcrypt-dev, not installed there, is libcrypt1's source version).
PACKAGES = [
    ("gnumach-dev", "2:1.8+git20260224-4", "pool-hurd-amd64/main/g/gnumach/gnumach-dev_1.8+git20260224-4_hurd-amd64.deb",
     "5fb6f71d0486f50bf932eeb23c7c52a87e1b65c7cd7df325f2406eff62ad597c"),
    ("hurd-dev", "1:0.9.git20251029-7", "pool-hurd-amd64/main/h/hurd/hurd-dev_0.9.git20251029-7_hurd-amd64.deb",
     "ce0cc062a151c608b7f289b83035e606ec77ead31b7e2e768ba29b14fbc4695d"),
    ("hurd-libs0.3", "1:0.9.git20251029-7", "pool-hurd-amd64/main/h/hurd/hurd-libs0.3_0.9.git20251029-7_hurd-amd64.deb",
     "c5bcfaa517def94f03ca39f7e6b5f250669f7ebf493e254db36402f16afa61f0"),
    ("libc0.3-dev", "2.42-14~hurd.1", "pool-hurd-amd64/main/g/glibc/libc0.3-dev_2.42-14~hurd.1_hurd-amd64.deb",
     "4d4eb4ac5d530056509d9738eaad2df18c18e0f315585e3f98d7f8815a0e2392"),
    ("libc0.3", "2.42-14~hurd.1", "pool-hurd-amd64/main/g/glibc/libc0.3_2.42-14~hurd.1_hurd-amd64.deb",
     "a7b0c3095efd24f2c100eed169275e851bb64f052d8c2ef93b2ffa40243b6960"),
    ("libcrypt-dev", "1:4.5.1-1", "pool-hurd-amd64/main/libx/libxcrypt/libcrypt-dev_4.5.1-1_hurd-amd64.deb",
     "a2cae06cc99cdf724c2980ea51d7134c52aa833f5102a480d9a3026ff7923da7"),
    ("libcrypt1", "1:4.5.1-1", "pool-hurd-amd64/main/libx/libxcrypt/libcrypt1_4.5.1-1_hurd-amd64.deb",
     "745cf9dd1f2806d0f125a75650faa8dc0a9c6bbc3f46042ebd91f6f6f45867c7"),
    ("libgcc-15-dev", "15.2.0-12", "pool-hurd-amd64/main/g/gcc-15/libgcc-15-dev_15.2.0-12_hurd-amd64.deb",
     "402337603873aab595197346aef3e03426b861a0b30758a6e51178ae9ac9f53b"),
    ("libgcc-s1", "15.2.0-12", "pool-hurd-amd64/main/g/gcc-15/libgcc-s1_15.2.0-12_hurd-amd64.deb",
     "cd131ef7302f5c4c75281287d8703bdb5a44c701b169469dff379beba60581c6"),
    ("libstdc++-15-dev", "15.2.0-12", "pool-hurd-amd64/main/g/gcc-15/libstdc++-15-dev_15.2.0-12_hurd-amd64.deb",
     "ba63f503fe8cb8f3d20f11de065ea0503aeb36b3055afe6245ea97cdb2081000"),
    ("libstdc++6", "15.2.0-12", "pool-hurd-amd64/main/g/gcc-15/libstdc++6_15.2.0-12_hurd-amd64.deb",
     "2845c5fac510243c8ea68c729d58b74823fcf961b0f1f2f24941e049de5b6523"),
]
KEEP = ("usr/include/", "usr/lib/")
DROP = ("usr/lib/x86_64-gnu/gconv/", "usr/lib/x86_64-gnu/audit/", "usr/lib/locale/", "usr/lib/debug/")
REQUIRED = ("usr/include/stdio.h", "usr/include/hurd.h", "usr/include/mach.h", "usr/lib/x86_64-gnu/crt1.o",
            "usr/lib/x86_64-gnu/libc.so", "usr/lib/x86_64-gnu/libc.so.0.3", "usr/lib/x86_64-gnu/ld-x86-64.so.1",
            f"usr/lib/gcc/x86_64-gnu/{GCC}/libgcc.a", f"usr/lib/gcc/x86_64-gnu/{GCC}/crtbegin.o",
            f"usr/include/c++/{GCC}/bits/std.cc", f"usr/include/x86_64-gnu/c++/{GCC}/bits/c++config.h")


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
# libgcc and its unwinder, with GCC's libstdc++, which is linked by name: the link
# is the compiler's, given no `-stdlib`.
cxxflags = ["-stdlib=libstdc++"]
ldflags  = ["-rtlib=libgcc", "--unwindlib=libgcc", "-lstdc++"]
# GCC's std module sources (GCC 15 and later), compiled with libstdc++'s headers:
# `import std` on this row.
include_dirs      = ["usr/include/c++/{GCC}", "usr/include/x86_64-gnu/c++/{GCC}", "usr/include/c++/{GCC}/backward"]
std-module        = "usr/include/c++/{GCC}/bits/std.cc"
std-compat-module = "usr/include/c++/{GCC}/bits/std.compat.cc"
''')
        listed = "\n".join(f"    {p} {v}\n        {MIRROR}{path}\n        sha256 {d}" for p, v, path, d in PACKAGES)
        (root / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-hurd-sysroot.py` from the packages of Debian GNU/Hurd's `hurd-amd64` port
(debian-ports), at the versions Debian's pre-installed image of {version} has, from the
archive's snapshot of that date; each checked against the digest the script states:

{listed}

Taken without modification: `usr/include` and `usr/lib` of each package, without the
C library's character-set modules (`gconv`), its audit modules and locale data. Added:
the link `lib -> usr/lib` (Debian's merged /usr), `mcpp.toml` and this file. The manifest
states libstdc++'s include directories and GCC's std module sources (`bits/std.cc`,
`bits/std.compat.cc`), as the package ships them, and links libstdc++ by name.
''')
        archive = out / f"{name}.tar.xz"
        subprocess.run(["tar", "-C", tmp, "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                        "--mtime=@0", "-cf", str(archive.with_suffix("")), name], check=True)
        subprocess.run(["xz", "-T0", "-9", "-f", str(archive.with_suffix(""))], check=True)
        print(archive, sha256(archive.read_bytes()), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
