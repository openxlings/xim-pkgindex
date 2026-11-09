#!/usr/bin/env python3
"""Assemble the <arch>-freebsd-sysroot base packages from FreeBSD's official base.txz.

One package per identity (x86_64-freebsd, aarch64-freebsd); the package root is
the sysroot (mcpp design 2026-11-10 E5). Each keeps the parts of the base system a
program is compiled and linked against -- `usr/include`, the shared libraries of
`lib/`, `libexec/ld-elf.so.1`, and `usr/lib` without the parts that serve
FreeBSD's own toolchain (`usr/lib/clang`, the `libprivate*` LLVM libraries, debug
data) and without the static archives a static program does not need -- and adds
libc++'s std module sources, generated from the official libcxx source release of
the version the base's libc++ is (FreeBSD installs no std.cppm).

Layout of <arch>-freebsd-sysroot-<version>/:

    mcpp.toml                       the package manifest: provides, [build]
    PROVENANCE.md
    lib/  libexec/  usr/            the sysroot
    usr/share/libc++/v1/            std.cppm, std.compat.cppm, std/, std.compat/

usage: build-freebsd-sysroot.py <out-dir> <version> <libcxx-src-dir> amd64=<base.txz> arm64=<base.txz>
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
    gen = Path(__file__).with_name("libcxx-modules.py")
    for machine, txz in inputs.items():
        txz = Path(txz).resolve()
        identity = f"{ARCH[machine]}-freebsd"
        name = f"{identity}-sysroot-{version}"
        with tempfile.TemporaryDirectory(dir=out) as tmp:
            root = Path(tmp) / name
            root.mkdir()
            with tarfile.open(txz) as t:
                members = [m for m in t.getmembers() if keep(m.name)]
                t.extractall(root, members=members, filter="tar")
            subprocess.run([sys.executable, str(gen), str(libcxx), str(root / "usr/share/libc++/v1")],
                           check=True, stdout=subprocess.DEVNULL)
            (root / "mcpp.toml").write_text(f'''# A base package (mcpp design 2026-11-10 E5): the package root is the sysroot
# of {identity}.
[package]
name        = "{identity}-sysroot"
version     = "{version}"
description = "FreeBSD {version}-RELEASE base system ({machine}) for compiling and linking, with libc++'s std module"
license     = "BSD-2-Clause AND Apache-2.0 WITH LLVM-exception"
provides    = ["mcpp:c-abi=freebsd-libc", "mcpp:c++-abi=libc++", "mcpp:compiler-runtime=libgcc",
               "hosted-standard-library"]

[build]
include_dirs      = ["usr/include/c++/v1"]
ldflags           = ["-lc++", "-lcxxrt"]
std-module        = "usr/share/libc++/v1/std.cppm"
std-compat-module = "usr/share/libc++/v1/std.compat.cppm"
# FreeBSD declares the fenv functions `static inline` unless `__fenv_static` is
# defined: a module cannot export a name with internal linkage.
std-module-flags  = ["-D__fenv_static="]
''')
            (root / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-freebsd-sysroot.py` from the official FreeBSD {version}-RELEASE
distribution set https://download.freebsd.org/releases/{machine}/{version}-RELEASE/base.txz,
whose digest the release's MANIFEST states:

    {txz.name}
        sha256 {sha256(txz)}

Taken without modification: `usr/include`, the libraries of `lib/`,
`libexec/ld-elf.so.1` and `usr/lib`, without `usr/lib/{{clang,debug,dtrace,i18n,engines-3,flua}}`,
`usr/lib32`, the `libprivate*` libraries, and every static archive except those of the C
library, the C++ run-time, the compiler run-time and the libraries they need.
Added: `usr/share/libc++/v1`, libc++'s module sources generated by `libcxx-modules.py`
from the official {libcxx.name}.tar.xz (llvm-project release, signed), the version of the
base's libc++; `mcpp.toml` and this file.
''')
            archive = out / f"{name}.tar.xz"
            subprocess.run(["tar", "-C", tmp, "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                            "-cf", "-", name], check=True, stdout=open(archive.with_suffix(""), "wb"))
            subprocess.run(["xz", "-T0", "-9", "-f", str(archive.with_suffix(""))], check=True)
            print(archive, sha256(archive), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
