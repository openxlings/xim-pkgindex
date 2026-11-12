#!/usr/bin/env python3
"""Assemble the aarch64-linux-gnu sysroot payload from published payloads.

Sources, each verified by digest before anything is copied:

    xlings-res/glibc           tag 2.44.3-r4   glibc-2.44.3-r4-linux-aarch64.tar.gz
    xlings-res/linux-headers   tag 5.11.1      linux-headers-5.11.1-linux-aarch64.tar.gz
    xlings-res/llvm            tag 23.1.3      llvm-23.1.3-linux-aarch64.tar.gz

Taken without modification:

    glibc          everything (headers, libraries, lib/ld-linux-aarch64.so.1,
                   crt objects, the C library's static archives)
    linux-headers  include/ (linux, asm of arm64, asm-generic, scsi, drm,
                   rdma, misc, mtd)
    llvm           include/c++/v1
                   lib/aarch64-unknown-linux-gnu (libc++, libc++abi,
                   libunwind, libatomic)
                   lib/clang/23/lib/aarch64-unknown-linux-gnu (builtins)
                   share/libc++/v1 (the std module sources)

Added: mcpp.toml (the package manifest mcpp reads) and PROVENANCE.md.

Usage:

    build-aarch64-linux-gnu-sysroot.py [--work DIR] [--out FILE]

The output is one tar.xz whose single top directory is the asset's file name
without its extension, aarch64-linux-gnu-sysroot-<version>-r<revision>: the
installer takes the top directory by that name. The version is glibc's; the
revision counts the corrective repacks of the same inputs.
"""

import argparse
import hashlib
import pathlib
import re
import shutil
import sys
import tarfile
SOURCES = [
    # (label, expected sha256, archive-relative paths to take)
    ("glibc-2.44.3-r4-linux-aarch64.tar.gz",
     "bd480264223d887de03fefeda34d0ee75566cb4bf4042e481818251fb463bfce", "*"),
    ("linux-headers-5.11.1-linux-aarch64.tar.gz",
     "ffb294cc183e9ddb87af3411364ba09c9724390494c2f271a81e98a3d6ccfbd7",
     "*/include"),
    ("llvm-23.1.3-linux-aarch64.tar.gz",
     "8a4697b6f22703c1fb8d808a0ef6022f3a9e9111a70e7a02009b7814bdbe46a9",
     # `include/aarch64-unknown-linux-gnu` is the per-target directory
     # without whose `c++/v1/__config_site` every libc++ include -- and so
     # every C compile, which reaches libc++'s stdio.h first through
     # [build] include_dirs -- dies at `__config_site` not found (the r1
     # payload missed it; revision 2 adds it).
     "*/include/c++ */include/aarch64-unknown-linux-gnu "
     "*/lib/aarch64-unknown-linux-gnu */lib/clang/23/lib/"
     "aarch64-unknown-linux-gnu */share/libc++"),
]

# gcc 15.1.0's own run-time objects for aarch64, taken from the installed
# xim:aarch64-linux-musl-gcc payload (musl-cross-make's gcc build; libgcc and
# the crtbegin/crtend objects are C-library-agnostic). The engine's row names
# this sysroot as the provider of compiler-runtime=libgcc, exactly as the
# FreeBSD base sysroot carries base's own libgcc.
LIBGCC = {
    "libgcc.a":      "a49880dd3c0d75b0222f4a08f94e37ca95302945e1967491b9535faf7f0d089f",
    "libgcc_eh.a":   "89eabc63e733e3468412353df3529846a40685589a5768bb4ff3b5bb3b37cd15",
    "crtbegin.o":    "af3f15a2f6d7f1821137ea2022cb78e3b9fda719ccb54ee59bebee94fd053e25",
    "crtbeginS.o":   "2a6ed8d44d1ba4c68109a05dec2b1dd1ac076f0bdbdbd7b3f827cd3953b0f338",
    "crtbeginT.o":   "af3f15a2f6d7f1821137ea2022cb78e3b9fda719ccb54ee59bebee94fd053e25",
    "crtend.o":      "25d85c6d7c43c6252c0e08477fae0477ef2b3f6d36093465e85aa98733d97afa",
    "crtendS.o":     "25d85c6d7c43c6252c0e08477fae0477ef2b3f6d36093465e85aa98733d97afa",
    "crtfastmath.o": "135ea54dbcf9241b2684f3b08125c0e1d13eb948a110747820a99f79e33860ce",
}

VERSION = "2.44.3"
REVISION = 3
STEM = f"aarch64-linux-gnu-sysroot-{VERSION}-r{REVISION}"

MANIFEST = """# A base package (mcpp design 2026-11-10 E5): the package root is the sysroot
# of aarch64-linux-gnu. One archive serves every host.
[package]
name        = "aarch64-linux-gnu-sysroot"
version     = "{version}"
description = "glibc {version} for aarch64-linux-gnu with the 5.11 kernel headers, libc++ with its std modules, and compiler-rt's builtins, for compiling and linking"
license     = "LGPL-2.1-or-later AND Apache-2.0 WITH LLVM-exception"
# The compiler run-time a link over this sysroot takes is compiler-rt's
# builtins (`compiler_runtime_dir`); gcc's libgcc archives and crt objects are
# carried beside it for a link that names them.
provides    = ["mcpp:c-abi=glibc", "mcpp:c++-abi=libc++", "mcpp:compiler-runtime=compiler-rt",
               "hosted-standard-library"]

[build]
include_dirs         = ["include/aarch64-unknown-linux-gnu/c++/v1", "include/c++/v1"]
ldflags              = ["-lc++", "-lc++abi"]
# Where clang's link finds this sysroot's own run-times: the llvm-aarch64
# carve's compiler-rt, laid out as a resource directory (lib/<triple>/
# libclang_rt.builtins.a inside). Without it the link's --rtlib=compiler-rt
# reads the x86_64 llvm payload's resource directory and finds no aarch64
# builtins there.
compiler_runtime_dir = "lib/clang/23"
std-module           = "share/libc++/v1/std.cppm"
std-compat-module    = "share/libc++/v1/std.compat.cppm"
"""

PROVENANCE = """# Provenance

Assembled by `build-aarch64-linux-gnu-sysroot.py` from published xlings-res
payloads, each taken without modification:

    glibc-2.44.3-r4-linux-aarch64.tar.gz   (xlings-res/glibc, tag 2.44.3-r4)
        sha256 bd480264223d887de03fefeda34d0ee75566cb4bf4042e481818251fb463bfce
      taken: everything -- headers, libraries, the loader
      (lib/ld-linux-aarch64.so.1), crt objects and the static archives of the
      C library.

    linux-headers-5.11.1-linux-aarch64.tar.gz   (xlings-res/linux-headers, tag 5.11.1)
        sha256 ffb294cc183e9ddb87af3411364ba09c9724390494c2f271a81e98a3d6ccfbd7
      taken: include/ -- linux, asm (arm64), asm-generic, scsi, drm, rdma,
      misc, mtd.

    llvm-23.1.3-linux-aarch64.tar.gz   (xlings-res/llvm, tag 23.1.3)
        sha256 8a4697b6f22703c1fb8d808a0ef6022f3a9e9111a70e7a02009b7814bdbe46a9
      taken: include/c++/v1, lib/aarch64-unknown-linux-gnu (libc++, libc++abi,
      libunwind, libatomic), lib/clang/23/lib/aarch64-unknown-linux-gnu
      (compiler-rt builtins), share/libc++/v1 (the std module sources).

Added: `mcpp.toml` and this file. The version is glibc's.

Revision 3 corrects revision 2 in five places, from the same inputs: the
archive's top directory is the asset's file name without its extension; the
install-time placeholder is removed from every ld script of the library
directory (libm.a's had been left, and libm.so named it); every file of llvm's
per-target library directory -- the shared objects and their
sonames as well as the archives -- is named at the library root, so
`libc++.so`'s `INPUT(libc++.so.1 ...)` resolves and a dynamic C++ program
loads; the manifest states `std-module`; and `provides` names the compiler
run-time the link takes (compiler-rt).
"""


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=".assembler-work")
    ap.add_argument("--out", default=f"{STEM}.tar.xz")
    ap.add_argument("--libgcc-src", required=True,
                    help="directory holding gcc's aarch64 libgcc/crt objects "
                         "(the installed xim:aarch64-linux-musl-gcc payload's "
                         "lib/gcc/aarch64-linux-musl/<ver> directory)")
    args = ap.parse_args()

    work = pathlib.Path(args.work).resolve()
    work.mkdir(parents=True, exist_ok=True)
    root = work / STEM
    if root.exists():
        shutil.rmtree(root)
    root.mkdir()

    for name, digest, _ in SOURCES:
        archive = work / name
        if not archive.is_file():
            sys.exit(f"missing source archive: {archive}")
        got = sha256(archive)
        if got != digest:
            sys.exit(f"digest mismatch for {name}: {got} != {digest}")

    newest = 0
    for name, _, take in SOURCES:
        archive = work / name
        with tarfile.open(archive) as tf:
            members = tf.getmembers()
            newest = max(newest, max(int(m.mtime) for m in members))
            top = members[0].name.split("/")[0]
            for m in members:
                if not m.name.startswith(top + "/"):
                    continue
                rel = m.name[len(top) + 1:]
                if not rel:
                    continue
                for pattern in take.split():
                    p = pattern[2:] if pattern.startswith("*/") else pattern
                    if p == "*" or rel == p or rel.startswith(p.rstrip("/") + "/"):
                        m.name = rel
                        tf.extract(m, root, filter="data")
                        break

    gcc_dir = pathlib.Path(args.libgcc_src).resolve()
    for f, digest in LIBGCC.items():
        src = gcc_dir / f
        if not src.is_file():
            sys.exit(f"missing libgcc object: {src}")
        got = sha256(src)
        if got != digest:
            sys.exit(f"digest mismatch for {f}: {got} != {digest}")
        shutil.copy2(src, root / "lib" / f)

    # glibc's payload ships some library names as GNU ld scripts -- libc.so,
    # libm.so and the static libm.a -- whose GROUP paths begin with a 255-byte
    # placeholder the host package relocates at install time. A sysroot
    # package needs no relocation: the placeholder is removed from every such
    # script, which leaves the sysroot-relative form (`/lib/libc.so.6`) a
    # --sysroot link resolves. One rule for every script of the directory:
    # revision 2 rewrote two of them by hand and missed libm.a, which every
    # C++ link and every static link reads.
    libdir = root / "lib"
    pad = re.compile(rb"/nonexistent/xlings-use-rpath-not-default-search/[^\s/]*")
    for f in sorted(libdir.iterdir()):
        if f.is_symlink() or not f.is_file() or f.stat().st_size > 4096:
            continue
        data = f.read_bytes()
        if not data.startswith(b"/* GNU ld script"):
            continue
        fixed = pad.sub(b"", data)
        if b"/nonexistent/" in fixed:
            sys.exit(f"{f.name}: a path of the script is not the relocation placeholder's")
        f.write_bytes(fixed)

    # The C++ run-time lives in llvm's per-target directory, where neither a
    # --sysroot link nor the target's loader looks. Every library file of it
    # is named at the library root -- symlinks into the one copy -- so the
    # archives, the linker script `libc++.so` and the sonames its
    # `INPUT(libc++.so.1 ...)` and a program's DT_NEEDED name all resolve
    # there (revision 2 named the archives and the `.so` names alone, and a
    # dynamic C++ link stopped at `unable to find libc++.so.1`).
    triple_lib = libdir / "aarch64-unknown-linux-gnu"
    for src in sorted(triple_lib.iterdir()):
        name = src.name
        if not (name.startswith("lib") and (name.endswith(".a") or ".so" in name)):
            continue
        link = libdir / name
        if link.exists() or link.is_symlink():
            sys.exit(f"{name} exists at the library root and in {triple_lib.name}")
        link.symlink_to(f"aarch64-unknown-linux-gnu/{name}")
    # glibc's payload carries its own PROVENANCE/ELF-MANIFEST/LICENSE files at
    # the root; the assembly keeps them (each name is distinct from the two
    # files this script adds).
    (root / "mcpp.toml").write_text(MANIFEST.format(version=VERSION))
    (root / "PROVENANCE.md").write_text(PROVENANCE)

    # The archive is a function of its inputs: members in name order (tarfile
    # sorts each directory), no owner, and no time later than the newest
    # member of the source archives -- the files this script writes take that
    # time. Two runs over the same inputs give the same bytes.
    def member(info):
        info.uid = info.gid = 0
        info.uname = info.gname = ""
        info.mtime = min(int(info.mtime), newest)
        return info

    out = pathlib.Path(args.out).resolve()
    with tarfile.open(out, "w:xz") as tf:
        tf.add(root, arcname=root.name, filter=member)
    print(f"{out}  sha256 {sha256(out)}")


if __name__ == "__main__":
    main()
