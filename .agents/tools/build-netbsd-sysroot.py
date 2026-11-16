#!/usr/bin/env python3
"""Assemble the <arch>-netbsd-sysroot base packages from NetBSD's official sets.

One package per identity (x86_64-netbsd, aarch64-netbsd); the package root is the
sysroot (mcpp design 2026-11-10 E5). From `base.tar.xz` it keeps the shared
libraries of `lib/` and `usr/lib/`, `libexec/ld.elf_so` and the
`usr/include/machine` link; from `comp.tar.xz` the headers, the crt objects and
the static archives a static program links (the C library, the C++ run-time and
the compiler run-time). NetBSD's C++ run-time is GCC's libstdc++, which ships no
module sources: the base states no `std-module`.

Layout of <arch>-netbsd-sysroot-<version>/:

    mcpp.toml                       the package manifest: provides, [build]
    PROVENANCE.md
    lib/  libexec/  usr/            the sysroot

usage: build-netbsd-sysroot.py <out-dir> <version> amd64=<sets-dir> evbarm-aarch64=<sets-dir>
       (a sets directory holds base.tar.xz, comp.tar.xz and the release's SHA512)
"""
import hashlib, subprocess, sys, tarfile, tempfile
from pathlib import Path, PurePosixPath

ARCH = {"amd64": "x86_64", "evbarm-aarch64": "aarch64"}     # NetBSD port -> mcpp arch
STATIC = {"libc.a", "libm.a", "libpthread.a", "librt.a", "libutil.a", "libexecinfo.a", "libkvm.a",
          "libcrypt.a", "libz.a", "libstdc++.a", "libsupc++.a", "libgcc.a", "libgcc_eh.a"}
DROP_DIRS = ("usr/lib/debug", "usr/lib/i18n", "usr/lib/security", "usr/lib/i386", "usr/lib/eabi",
             "usr/lib/eabihf", "usr/lib/oabi", "usr/libdata", "usr/include/clang")


def keep(name: str) -> bool:
    s = str(PurePosixPath(name.lstrip("./")))
    if s in ("", "."):
        return False
    if s in ("libexec", "libexec/ld.elf_so", "usr/libexec", "usr/libexec/ld.elf_so"):
        return True
    if not (s.startswith("lib/") or s.startswith("usr/include/") or s.startswith("usr/lib/")
            or s in ("lib", "usr", "usr/include", "usr/lib")):
        return False
    if any(s == d or s.startswith(d + "/") for d in DROP_DIRS):
        return False
    if s.startswith("lib/") and s.count("/") > 1:
        return False
    base = PurePosixPath(s).name
    if base.endswith(".a"):
        return base in STATIC
    if s.startswith("usr/lib/") and s.count("/") > 2:      # usr/lib/<dir>/...: modules of programs
        return False
    return True


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def sha512(p: Path) -> str:
    h = hashlib.sha512()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def stated(sets: Path, name: str) -> str:
    for line in (sets / "SHA512").read_text().splitlines():
        if line.startswith(f"SHA512 ({name}) = "):
            return line.rsplit(" ", 1)[1]
    raise SystemExit(f"{sets}/SHA512 states no digest for {name}")


def main() -> int:
    out, version = Path(sys.argv[1]).resolve(), sys.argv[2]
    inputs = dict(a.split("=", 1) for a in sys.argv[3:])
    out.mkdir(parents=True, exist_ok=True)
    for port, sets in inputs.items():
        sets = Path(sets).resolve()
        for s in ("base.tar.xz", "comp.tar.xz"):
            if sha512(sets / s) != stated(sets, s):
                raise SystemExit(f"{sets / s}: the digest differs from the release's SHA512")
        identity = f"{ARCH[port]}-netbsd"
        name = f"{identity}-sysroot-{version}"
        with tempfile.TemporaryDirectory(dir=out) as tmp:
            root = Path(tmp) / name
            root.mkdir()
            for s in ("base.tar.xz", "comp.tar.xz"):
                with tarfile.open(sets / s) as t:
                    t.extractall(root, members=[m for m in t.getmembers() if keep(m.name)], filter="tar")
            (root / "mcpp.toml").write_text(f'''# A base package (mcpp design 2026-11-10 E5): the package root is the sysroot
# of {identity}.
[package]
name        = "{identity}-sysroot"
version     = "{version}"
description = "NetBSD {version} base system ({port}) for compiling and linking"
license     = "BSD-2-Clause AND GPL-3.0-or-later WITH GCC-exception-3.1"
provides    = ["mcpp:c-abi=netbsd-libc", "mcpp:c++-abi=libstdc++", "mcpp:compiler-runtime=libgcc",
               "hosted-standard-library"]

[build]
include_dirs = ["usr/include/g++"]
# The C++ run-time is GCC's libstdc++ over libgcc_s; clang's NetBSD driver names
# neither the unwinder nor libstdc++ unless told.
cxxflags     = ["-stdlib=libstdc++"]
ldflags      = ["-stdlib=libstdc++", "-lstdc++", "-lgcc_s"]
''')
            digests = "\n".join(f"    {s}\n        sha512 {stated(sets, s)}\n        sha256 {sha256(sets / s)}"
                                for s in ("base.tar.xz", "comp.tar.xz"))
            (root / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-netbsd-sysroot.py` from the official NetBSD {version} distribution sets
https://cdn.netbsd.org/pub/NetBSD/NetBSD-{version}/{port}/binary/sets/{{base,comp}}.tar.xz,
checked against the release's SHA512 file:

{digests}

Taken without modification: `lib/`, `libexec/ld.elf_so`, `usr/include` (without
`usr/include/clang`) and `usr/lib` (without `usr/lib/{{debug,i18n,security}}`, the
other ABIs' directories and the programs' modules), and of the static archives only
those of the C library, the C++ run-time and the compiler run-time. Added: `mcpp.toml`
and this file.
''')
            archive = out / f"{name}.tar.xz"
            subprocess.run(["tar", "-C", tmp, "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                            "-cf", "-", name], check=True, stdout=open(archive.with_suffix(""), "wb"))
            subprocess.run(["xz", "-T0", "-9", "-f", str(archive.with_suffix(""))], check=True)
            print(archive, sha256(archive), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
