#!/usr/bin/env python3
"""Assemble the <arch>-openbsd-sysroot base packages from OpenBSD's official sets.

One package per identity (x86_64-openbsd, aarch64-openbsd); the package root is the
sysroot (mcpp design 2026-11-10 E5). From `base<v>.tgz` it keeps the shared
libraries and crt objects of `usr/lib/`, `usr/libexec/ld.so` and the compiler
run-time (`libcompiler_rt.a`); from `comp<v>.tgz` the headers and the static
archives a static program links (the C library, the C++ run-time and what they
need). Two additions:

- OpenBSD names its shared libraries only by version (`libc.so.104.0`); its own
  linker finds them by that rule, upstream lld does not, and `-lc` would take
  `libc.a` without a word. Each library gets its link name, `lib<x>.so`, a
  symbolic link to its newest version.
- OpenBSD installs no std.cppm, so libc++'s module sources are generated from the
  llvm-project source release of the version the base's libc++ is.

Layout of <arch>-openbsd-sysroot-<version>/:

    mcpp.toml                       the package manifest: provides, [build]
    PROVENANCE.md
    usr/                            the sysroot
    usr/share/libc++/v1/            std.cppm, std.compat.cppm, std/, std.compat/

usage: build-openbsd-sysroot.py <out-dir> <version> <libcxx-src-dir> <llvm-project-X.src.tar.xz>:<sha256> \
           amd64=<sets-dir> arm64=<sets-dir>
       (a sets directory holds base<v>.tgz, comp<v>.tgz and the release's SHA256)
"""
import hashlib, re, subprocess, sys, tarfile, tempfile
from pathlib import Path, PurePosixPath

ARCH = {"amd64": "x86_64", "arm64": "aarch64"}           # OpenBSD platform -> mcpp arch
STATIC = {"libc.a", "libm.a", "libpthread.a", "libc++.a", "libc++abi.a", "libcompiler_rt.a",
          "libexecinfo.a", "libutil.a", "libkvm.a", "libz.a", "libelf.a"}


def keep(name: str) -> bool:
    s = str(PurePosixPath(name.lstrip("./")))
    if s in ("", "."):
        return False
    if s in ("usr", "usr/lib", "usr/include", "usr/libexec", "usr/libexec/ld.so"):
        return True
    if s.startswith("usr/include/"):
        return True
    if not s.startswith("usr/lib/") or s.count("/") > 2:   # usr/lib/<dir>/...: not the system's libraries
        return False
    base = PurePosixPath(s).name
    if base.endswith(".a"):
        return base in STATIC
    return base.endswith(".o") or ".so." in base


def digest(p: Path, algo="sha256") -> str:
    h = hashlib.new(algo)
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def link_names(lib: Path) -> list[str]:
    """`lib<x>.so` -> its newest `lib<x>.so.<major>.<minor>`, for every library."""
    newest: dict[str, tuple[tuple[int, int], str]] = {}
    for f in lib.iterdir():
        m = re.fullmatch(r"(lib.+)\.so\.(\d+)\.(\d+)", f.name)
        if m and not f.is_symlink():
            v = (int(m.group(2)), int(m.group(3)))
            if m.group(1) not in newest or v > newest[m.group(1)][0]:
                newest[m.group(1)] = (v, f.name)
    made = []
    for stem, (_, target) in sorted(newest.items()):
        link = lib / f"{stem}.so"
        if not link.exists():
            link.symlink_to(target)
            made.append(f"{link.name} -> {target}")
    return made


def main() -> int:
    out, version, libcxx = Path(sys.argv[1]).resolve(), sys.argv[2], Path(sys.argv[3]).resolve()
    llvm_name, llvm_sha = sys.argv[4].split(":", 1)        # the source release the module sources come from
    inputs = dict(a.split("=", 1) for a in sys.argv[5:])
    v = version.replace(".", "")
    out.mkdir(parents=True, exist_ok=True)
    gen = Path(__file__).with_name("libcxx-modules.py")
    for machine, sets in inputs.items():
        sets = Path(sets).resolve()
        stated = {m.group(1): m.group(2) for m in
                  re.finditer(r"SHA256 \((.+?)\) = ([0-9a-f]+)", (sets / "SHA256").read_text())}
        names = (f"base{v}.tgz", f"comp{v}.tgz")
        for n in names:
            if digest(sets / n) != stated.get(n):
                raise SystemExit(f"{sets / n}: the digest differs from the release's SHA256")
        identity = f"{ARCH[machine]}-openbsd"
        name = f"{identity}-sysroot-{version}"
        with tempfile.TemporaryDirectory(dir=out) as tmp:
            root = Path(tmp) / name
            root.mkdir()
            for n in names:
                with tarfile.open(sets / n) as t:
                    t.extractall(root, members=[m for m in t.getmembers() if keep(m.name)], filter="tar")
            links = link_names(root / "usr/lib")
            subprocess.run([sys.executable, str(gen), str(libcxx), str(root / "usr/share/libc++/v1")],
                           check=True, stdout=subprocess.DEVNULL)
            (root / "mcpp.toml").write_text(f'''# A base package (mcpp design 2026-11-10 E5): the package root is the sysroot
# of {identity}.
[package]
name        = "{identity}-sysroot"
version     = "{version}"
description = "OpenBSD {version} base system ({machine}) for compiling and linking, with libc++'s std module"
license     = "ISC AND BSD-3-Clause AND Apache-2.0 WITH LLVM-exception"
provides    = ["mcpp:c-abi=openbsd-libc", "mcpp:c++-abi=libc++", "mcpp:compiler-runtime=compiler-rt",
               "hosted-standard-library"]

[build]
include_dirs      = ["usr/include/c++/v1"]
ldflags           = ["-lc++", "-lc++abi", "-lpthread"]
std-module        = "usr/share/libc++/v1/std.cppm"
std-compat-module = "usr/share/libc++/v1/std.compat.cppm"
''')
            listing = "\n".join(f"    {n}\n        sha256 {stated[n]}" for n in names)
            link_list = "\n".join(f"    {l}" for l in links)
            (root / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-openbsd-sysroot.py` from the official OpenBSD {version} sets
https://cdn.openbsd.org/pub/OpenBSD/{version}/{machine}/{{base{v},comp{v}}}.tgz, checked against the
release's SHA256 file (which the release signs in SHA256.sig):

{listing}

Taken without modification: `usr/include`, the shared libraries and crt objects of `usr/lib`,
`usr/libexec/ld.so`, and of the static archives only those of the C library, the C++ run-time,
the compiler run-time and what they need. Added: `usr/share/libc++/v1`, libc++'s module
sources generated by `libcxx-modules.py` from the official {llvm_name}
(sha256 {llvm_sha}), the version of the base's libc++; the link names
upstream lld looks for, each a symbolic link to the library's newest version:

{link_list}

and `mcpp.toml` and this file.
''')
            archive = out / f"{name}.tar.xz"
            subprocess.run(["tar", "-C", tmp, "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                            "-cf", "-", name], check=True, stdout=open(archive.with_suffix(""), "wb"))
            subprocess.run(["xz", "-T0", "-9", "-f", str(archive.with_suffix(""))], check=True)
            print(archive, digest(archive), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
