#!/usr/bin/env python3
"""Assemble the freebsd-sysroot base package from FreeBSD's official base.txz.

For each architecture the package keeps the parts of the base system a program
is compiled and linked against -- `usr/include`, the shared libraries of `lib/`,
`libexec/ld-elf.so.1`, and `usr/lib` without the parts that serve FreeBSD's own
toolchain (`usr/lib/clang`, the `libprivate*` LLVM libraries, debug data,
`*_pic.a`) -- and adds libc++'s std module sources, generated from the official
libcxx source release of the version the base's libc++ is (FreeBSD installs no
std.cppm).

Layout:

    mcpp.toml                       the base statement (design 2026-11-10 E5)
    PROVENANCE.md
    amd64/  arm64/                  one sysroot per architecture
      usr/share/libc++/v1/          std.cppm, std.compat.cppm, std/, std.compat/

usage: build-freebsd-sysroot.py <out-dir> <version> <libcxx-src-dir> amd64=<base.txz> arm64=<base.txz>

The archives published before this script entered the index name it by its
working name, `freebsd_sysroot.py`, in their PROVENANCE.md; the content is the same.
"""
import hashlib, shutil, subprocess, sys, tarfile, tempfile
from pathlib import Path, PurePosixPath

ARCH = {"amd64": "x86_64", "arm64": "aarch64"}       # FreeBSD machine -> mcpp arch
# The static archives kept: the C library, the C++ run-time, the compiler
# run-time and what they need, which is what a static program links. Every
# other library is kept as a shared object (its `.so` link name and its
# `lib/` file); a static copy of it is a dependency's to supply.
STATIC = {"libc.a", "libc_nonshared.a", "libm.a", "libthr.a", "libpthread.a", "libc++.a",
          "libc++experimental.a", "libcxxrt.a", "libgcc.a", "libgcc_eh.a", "libcompiler_rt.a",
          "libssp_nonshared.a", "libexecinfo.a", "libelf.a", "libutil.a", "librt.a", "libkvm.a",
          "libmd.a", "libcrypt.a", "libdl.a", "libstdthreads.a", "libz.a", "libprocstat.a",
          "libsys.a"}
DROP_DIRS = ("usr/lib/clang", "usr/lib/debug", "usr/lib/dtrace", "usr/lib/i18n",
             "usr/lib/engines-3", "usr/lib/flua", "usr/lib32")


def keep(name: str) -> bool:
    p = PurePosixPath(name.lstrip("./"))
    s = str(p)
    if s in ("", "."):
        return False
    if s == "libexec/ld-elf.so.1":
        return True
    if not (s.startswith("lib/") or s.startswith("usr/include/") or s.startswith("usr/lib/")
            or s in ("lib", "usr", "usr/include", "usr/lib", "libexec")):
        return False
    if any(s == d or s.startswith(d + "/") for d in DROP_DIRS):
        return False
    if s.startswith("lib/") and s.count("/") > 1:      # lib/geom, lib/nvmecontrol: programs' modules
        return False
    base = p.name
    if base.endswith(".a"):
        return base in STATIC
    return not base.startswith("libprivate")


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main() -> int:
    out, version, libcxx = Path(sys.argv[1]).resolve(), sys.argv[2], Path(sys.argv[3]).resolve()
    inputs = dict(a.split("=", 1) for a in sys.argv[4:])
    out.mkdir(parents=True, exist_ok=True)
    name = f"freebsd-sysroot-{version}"
    gen = Path(__file__).with_name("libcxx-modules.py")
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        dst = Path(tmp) / name
        dst.mkdir()
        sums = {}
        for machine, txz in inputs.items():
            txz = Path(txz).resolve()
            sums[machine] = (txz.name, sha256(txz))
            root = dst / machine
            root.mkdir()
            with tarfile.open(txz) as t:
                members = [m for m in t.getmembers() if keep(m.name)]
                t.extractall(root, members=members, filter="tar")
            subprocess.run([sys.executable, str(gen), str(libcxx), str(root / "usr/share/libc++/v1")],
                           check=True, stdout=subprocess.DEVNULL)
        roots = ", ".join(f'{ARCH[m]} = "{m}"' for m in inputs)
        (dst / "mcpp.toml").write_text(f'''[package]
name        = "freebsd-sysroot"
version     = "{version}"
description = "FreeBSD {version}-RELEASE base system for compiling and linking, with libc++'s std module"
license     = "BSD-2-Clause AND Apache-2.0 WITH LLVM-exception"
provides    = ["mcpp:c-abi=freebsd-libc", "mcpp:c++-abi=libc++", "mcpp:compiler-runtime=libgcc",
               "hosted-standard-library"]

[base]
roots             = {{ {roots} }}
include-dirs      = ["usr/include/c++/v1"]
libs              = {{ dynamic = ["c++"], static = ["c++", "cxxrt"] }}
std-module        = "usr/share/libc++/v1/std.cppm"
std-compat-module = "usr/share/libc++/v1/std.compat.cppm"
# FreeBSD declares the fenv functions `static inline` unless `__fenv_static` is
# defined: a module cannot export a name with internal linkage.
std-module-flags  = ["-D__fenv_static="]
''')
        lines = "\n".join(f"    {m}: {n}\n        sha256 {s}" for m, (n, s) in sums.items())
        (dst / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-freebsd-sysroot.py` from the official FreeBSD {version}-RELEASE
distribution sets (https://download.freebsd.org/releases/<machine>/{version}-RELEASE/base.txz,
whose digests the release's signed MANIFEST and CHECKSUM files state):

{lines}

Taken without modification: `usr/include`, the libraries of `lib/`,
`libexec/ld-elf.so.1` and `usr/lib`, without `usr/lib/{{clang,debug,dtrace,i18n,engines-3,flua}}`,
`usr/lib32`, the `libprivate*` libraries, and every static archive except those of the C
library, the C++ run-time, the compiler run-time and the libraries they need.
Added: `usr/share/libc++/v1` per architecture, libc++'s module sources generated by
`libcxx-modules.py` from the official {libcxx.name}.tar.xz (llvm-project release,
signed), the version of the base's libc++; `mcpp.toml` and this file.
''')
        archive = out / f"{name}.tar.xz"
        subprocess.run(["tar", "-C", tmp, "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                        "-cf", "-", name], check=True, stdout=open(archive.with_suffix(""), "wb"))
        subprocess.run(["xz", "-T0", "-9", "-f", str(archive.with_suffix(""))], check=True)
        print(archive, sha256(archive), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
