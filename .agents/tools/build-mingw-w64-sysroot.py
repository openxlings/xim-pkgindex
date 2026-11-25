#!/usr/bin/env python3
"""Assemble the mingw-w64-sysroot base package from an llvm-mingw release.

The package holds the target side of llvm-mingw only -- the MinGW-w64 headers
and import libraries (UCRT), libc++, libunwind, the compiler-rt runtime and
libc++'s std module sources -- for the architectures named in ARCHES. No
program of the release's host is kept, so one archive serves every host.

Layout (the sysroot is the package's top directory; clang's MinGW driver reads
`<sysroot>/include` and `<sysroot>/<arch>-w64-mingw32/lib`):

    mcpp.toml                          the package manifest of a base package (design 2026-11-10 E5)
    PROVENANCE.md, LICENSE.TXT
    include/                           generic-w64-mingw32/include (headers, c++/v1)
    <arch>-w64-mingw32/lib/            crt objects, import libraries, libc++, libunwind
    <arch>-w64-mingw32/bin/            the DLLs a dynamic link loads
    compiler-rt/lib/windows/           libclang_rt.*-<arch>.a
    share/libc++/v1/                   std.cppm, std.compat.cppm and their std/*.inc

usage: build-mingw-w64-sysroot.py <llvm-mingw-<v>-ucrt-<host>.tar.xz> <out-dir> <version>[-<revision>]

The archives 20261104, 20261104-1 and 20261104-2 name this script by its working name,
`mingw_w64_sysroot.py`, in their PROVENANCE.md; the content is the same.
"""
import hashlib, os, shutil, subprocess, sys, tarfile, tempfile
from pathlib import Path

ARCHES = {"x86_64": "x86_64", "aarch64": "aarch64"}   # mcpp arch -> llvm-mingw arch
RT_SUFFIX = {"x86_64": "x86_64", "aarch64": "aarch64"}


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main() -> int:
    src, out, version = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(), sys.argv[3]
    upstream = version.split("-")[0]   # a packaging revision (`-1`) is not llvm-mingw's
    out.mkdir(parents=True, exist_ok=True)
    name = f"mingw-w64-sysroot-{version}"
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        tmp = Path(tmp)
        with tarfile.open(src) as t:
            t.extractall(tmp, filter="tar")
        (rel,) = [d for d in tmp.iterdir() if d.is_dir()]
        dst = tmp / name
        dst.mkdir()
        shutil.copytree(rel / "generic-w64-mingw32" / "include", dst / "include", symlinks=False)
        for arch, la in ARCHES.items():
            sub = f"{la}-w64-mingw32"
            shutil.copytree(rel / sub / "lib", dst / sub / "lib", symlinks=False)
            (dst / sub / "bin").mkdir(parents=True)
            for dll in sorted((rel / sub / "bin").glob("*.dll")):
                shutil.copy2(dll, dst / sub / "bin" / dll.name)
        (rtdir,) = list((rel / "lib" / "clang").iterdir())
        rt_out = dst / "compiler-rt" / "lib" / "windows"
        rt_out.mkdir(parents=True)
        for f in sorted((rtdir / "lib" / "windows").iterdir()):
            if any(f.name.endswith((f"-{s}.a", f"-{s}.dll.a")) for s in RT_SUFFIX.values()):
                shutil.copy2(f, rt_out / f.name)
        shutil.copytree(rel / "share" / "libc++", dst / "share" / "libc++", symlinks=False)
        shutil.copy2(rel / "LICENSE.TXT", dst / "LICENSE.TXT")
        llvm = rtdir.name
        (dst / "mcpp.toml").write_text(f'''# A base package (mcpp design 2026-11-10 E5): the package root is the sysroot of
# x86_64-windows-gnu and aarch64-windows-gnu; clang's MinGW driver finds each
# architecture's libraries under <root>/<arch>-w64-mingw32/lib.
[package]
name        = "mingw-w64-sysroot"
version     = "{version}"
description = "The target side of llvm-mingw {upstream}: MinGW-w64 (UCRT), libc++, libunwind, compiler-rt"
license     = "ZPL-2.1 AND Apache-2.0 WITH LLVM-exception"
provides    = ["mcpp:c-abi=ucrt", "mcpp:c++-abi=libc++", "mcpp:compiler-runtime=compiler-rt",
               "hosted-standard-library"]

[build]
include_dirs         = ["include/c++/v1"]
ldflags              = ["-lc++", "-lunwind"]
std-module           = "share/libc++/v1/std.cppm"
std-compat-module    = "share/libc++/v1/std.compat.cppm"
compiler_runtime_dir = "compiler-rt"
''')
        srcsum = sha256(src)
        (dst / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-mingw-w64-sysroot.py` from the official llvm-mingw release
{upstream} (https://github.com/mstorsjo/llvm-mingw/releases/tag/{upstream}):

    {src.name}
    sha256 {srcsum}

Taken without modification: `generic-w64-mingw32/include` (as `include`),
`<arch>-w64-mingw32/lib` and the DLLs of `<arch>-w64-mingw32/bin` for
{", ".join(ARCHES.values())}, `lib/clang/{llvm}/lib/windows` (the files of those
architectures, as `compiler-rt/lib/windows`) and `share/libc++`. No program of the
release's host is included. `mcpp.toml` and this file are added.
''')
        archive = out / f"{name}.tar.xz"
        subprocess.run(["tar", "-C", str(tmp), "--owner=0", "--group=0", "--numeric-owner",
                        "--sort=name", "--mtime=2026-11-04", "-cJf", str(archive), name], check=True)
        print(archive, sha256(archive), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
