#!/usr/bin/env python3
"""Assemble the x86_64-haiku-sysroot base package from Haiku's packages.

The package root is the sysroot (mcpp design 2026-11-10 E5), laid out as Haiku
lays out a running system, which is where a compiler for Haiku looks beneath a
sysroot: `boot/system/develop/headers`, `boot/system/develop/lib`,
`boot/system/lib`. The C library is libroot. The packages are the ones listed
below, each held to its sha256, and are read by `hpkg.py` beside this script.

Layout of x86_64-haiku-sysroot-<version>/:

    mcpp.toml                       the package manifest: provides, [build]
    PROVENANCE.md
    boot/system/develop/headers     Haiku's headers, libstdc++'s
    boot/system/develop/lib         start files, libgcc, the links to the libraries
    boot/system/lib                 libroot and the system's other libraries, GCC's run-time

usage: build-haiku-sysroot.py <out-dir> <version> [<directory of the .hpkg files>]
       (a package that is not in the directory is fetched from its repository)
"""
import hashlib, subprocess, sys, tempfile, urllib.parse, urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hpkg  # noqa: E402

HAIKU = "https://eu.hpkg.haiku-os.org/haiku/master/x86_64/r1~beta6_hrev60431/packages/"
PORTS = "https://eu.hpkg.haiku-os.org/haikuports/master/x86_64/current/packages/"
GCC = "develop/tools/lib/gcc/x86_64-unknown-haiku/15.3.0/"
# file, repository, sha256, the paths taken (a prefix, or a file), what is left out beneath them
PACKAGES = [
    ("haiku-r1~beta6_hrev60431-1-x86_64.hpkg", HAIKU,
     "5071a4e34baf5ada8e4f0afe658ae817c3376ff19bef055de90e1a76093d3342", ("lib",), ()),
    ("haiku_devel-r1~beta6_hrev60431-1-x86_64.hpkg", HAIKU,
     "06e5c1dbf5f9de1a904a37632f23a815fc447debabdf3a1d2643d9e963fc86cc",
     ("develop/headers", "develop/lib"), ("develop/lib/_KERNEL_", "develop/headers/private")),
    ("gcc_syslibs-15.3.0_2026_10_11-1-x86_64.hpkg", PORTS,
     "2b6b37479f7e88afeb0dc74e399f454165d55bcaf083a7b9b87ee602d21c8314", ("lib",), ()),
    ("gcc_syslibs_devel-15.3.0_2026_10_11-1-x86_64.hpkg", PORTS,
     "47c4ffafc703e562fcca828074a7c95075f6f59d89dd224d6df58f7a61b87ec2",
     ("develop/headers/c++", "develop/lib"), ()),
    ("gcc-15.3.0_2026_10_11-1-x86_64.hpkg", PORTS,
     "f763ec59bd9cdaf0a19e1be3d215d07e47596bb5d342f2982662c052ac12874f",
     tuple(GCC + f for f in ("crtbegin.o", "crtbeginS.o", "crtend.o", "crtendS.o")), ()),
]
# Only the libraries of `lib' itself: its subdirectories are the system's add-ons.
SYSTEM = "boot/system/"
REQUIRED = ("develop/headers/posix/stdio.h", "develop/headers/os/kernel/OS.h", "develop/lib/crti.o",
            "develop/lib/start_dyn.o", "develop/lib/libgcc.a", "develop/lib/crtbeginS.o", "develop/lib/libroot.so",
            "lib/libroot.so", "lib/libgcc_s.so.1", "lib/libstdc++.so.6")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def under(path, prefixes):
    return any(path == p or path.startswith(p + "/") for p in prefixes)


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(__doc__, file=sys.stderr)
        return 2
    out, version = Path(sys.argv[1]).resolve(), sys.argv[2]
    have = Path(sys.argv[3]).resolve() if len(sys.argv) == 4 else None
    out.mkdir(parents=True, exist_ok=True)
    name = f"x86_64-haiku-sysroot-{version}"
    with tempfile.TemporaryDirectory(dir=out) as tmp:
        root = Path(tmp) / name
        system = root / SYSTEM
        system.mkdir(parents=True)
        fetched = Path(tmp) / "fetched"
        fetched.mkdir()
        for file, repository, digest, take, leave in PACKAGES:
            local = have / file if have else None
            if not (local and local.is_file()):
                local = fetched / file
                local.write_bytes(urllib.request.urlopen(repository + urllib.parse.quote(file)).read())
            if sha256(local.read_bytes()) != digest:
                raise SystemExit(f"{file}: the digest differs from the one this script states")
            package = hpkg.Package(local)
            package.entries = [e for e in package.entries if under(e.path, take) and not under(e.path, leave)
                               and not (e.path.startswith("lib/") and e.path.count("/") > 1)]
            for e in package.entries:
                if e.path.startswith(GCC):          # GCC's start files, beside the system's
                    e.path = "develop/lib/" + e.path[len(GCC):]
            package.extract(system)
        for f in REQUIRED:
            if not (system / f).exists():
                raise SystemExit(f"the sysroot lacks {SYSTEM}{f}")
        # A link to what is not here (another package's file, a library in an add-on
        # directory) is not kept.
        dropped = sorted(str(p.relative_to(system)) for p in root.rglob("*") if p.is_symlink() and not p.exists())
        for f in dropped:
            (system / f).unlink()
        (root / "mcpp.toml").write_text(f'''# A base package (mcpp design 2026-11-10 E5): the package root is the sysroot
# of x86_64-haiku, laid out as a running Haiku system (boot/system).
[package]
name        = "x86_64-haiku-sysroot"
version     = "{version}"
description = "Haiku base system (x86_64) for compiling and linking"
license     = "MIT AND GPL-3.0-or-later WITH GCC-exception-3.1"
provides    = ["mcpp:c-abi=libroot", "mcpp:c++-abi=libstdc++", "mcpp:compiler-runtime=libgcc",
               "hosted-standard-library"]

[build]
# The compiler's own run-time is not built for this system: the base's is taken,
# libgcc with GCC's libstdc++.
cxxflags = ["-stdlib=libstdc++"]
''')
        listed = "\n".join(f"    {f}\n        {r}{urllib.parse.quote(f)}\n        sha256 {d}\n        taken: {', '.join(t)}"
                           + (f"\n        left out: {', '.join(l)}" if l else "") for f, r, d, t, l in PACKAGES)
        (root / "PROVENANCE.md").write_text(f'''# Provenance

Assembled by `build-haiku-sysroot.py` from packages of Haiku (the system, `master`) and of
HaikuPorts (GCC's run-time), each checked against the digest the script states and read by
`hpkg.py`, a reader of the package format written from Haiku's description of it:

{listed}

Taken without modification, beneath `{SYSTEM}`. Of `lib`, the libraries of the directory
itself (its subdirectories are the system's add-ons). GCC's start files (`crtbegin.o`,
`crtbeginS.o`, `crtend.o`, `crtendS.o`) are placed in `develop/lib`, beside the system's
own, where a compiler given this sysroot looks. Links whose target is not among what is
taken are not kept: {", ".join(dropped)}. Added: `mcpp.toml` and this file.
''')
        archive = out / f"{name}.tar.xz"
        subprocess.run(["tar", "-C", tmp, "--owner=0", "--group=0", "--numeric-owner", "--sort=name",
                        "--mtime=@0", "-cf", str(archive.with_suffix("")), name], check=True)
        subprocess.run(["xz", "-T0", "-9", "-f", str(archive.with_suffix(""))], check=True)
        print(archive, sha256(archive.read_bytes()), archive.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
