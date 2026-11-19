#!/usr/bin/env python3
"""An llvm payload links compressed debug sections on this host, with its own linker.

    llvm-compressed-links.py --sha256 <digest> --work <dir> (--url <url> | --archive <file>)

The rule (mcpp design 2026-11-19, section 11.2): a toolchain payload reads the
same inputs on every host. On the host it runs on, this takes the archive the
recipe names -- by its digest: the file this run built when the index makes it
(--archive), otherwise the recipe's url -- and with the payload's own clang:

  * compiles one ELF object (x86_64-linux-gnu) whose debug sections are
    zlib-compressed and one whose sections are zstd-compressed, and reads each
    object's section headers: an object that carries no section compressed
    that way would make the link below read nothing compressed;
  * asks the driver which linker it runs for that link (`-###`): the ld.lld
    beside it. A driver that does not find its own ld.lld runs the one on the
    host's PATH (the Windows archive of llvm 23.1.3 revision 3 shipped none,
    and a FreeBSD link on a Windows host ran a PATH ld.lld built without zlib);
  * links each object into a shared object, writing its debug sections with the
    same algorithm, and reads the output's section headers.

Either link failing fails the check (exit 1). What `ld.lld` on the host's PATH
does with the zlib object is printed too, as a reading of the host, not a
criterion. A step summary row is written when GITHUB_STEP_SUMMARY is set.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import time
import urllib.request
import zipfile
from pathlib import Path

TARGET = "x86_64-unknown-linux-gnu"
SHF_COMPRESSED = 0x800
ALGORITHMS = {"zlib": 1, "zstd": 2}      # ELFCOMPRESS_ZLIB, ELFCOMPRESS_ZSTD
EXE = ".exe" if os.name == "nt" else ""


def fail(message: str) -> None:
    print(f"::error::llvm payload: {message}", flush=True)
    sys.exit(1)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def obtain(args) -> tuple[Path, str]:
    if args.archive:
        path, source = Path(args.archive), "built by this run (tools/res)"
    else:
        path, source = args.work / args.url.rsplit("/", 1)[-1], args.url
        for attempt in range(3):
            try:
                with urllib.request.urlopen(args.url, timeout=120) as r, path.open("wb") as f:
                    shutil.copyfileobj(r, f, 1 << 20)
                break
            except OSError as e:
                if attempt == 2:
                    fail(f"{args.url} could not be read: {e}")
                time.sleep(10)
    digest = sha256(path)
    if digest != args.sha256:
        fail(f"{path.name} ({source}) has sha256 {digest}; the recipe names {args.sha256}")
    print(f"READING archive: {path.name} sha256 {digest}, {source}", flush=True)
    return path, source


def extract(archive: Path, into: Path) -> Path:
    into.mkdir(parents=True, exist_ok=True)
    if archive.name.endswith(".zip"):
        with zipfile.ZipFile(archive) as z:
            z.extractall(into)
    else:
        with tarfile.open(archive) as t:
            t.extractall(into, filter="tar")
    tops = [p for p in into.iterdir() if p.is_dir()]
    if len(tops) != 1:
        fail(f"{archive.name} holds {len(tops)} top directories, not one")
    return tops[0]


def compressed_sections(path: Path) -> dict[str, int]:
    """Section name -> ch_type, for every SHF_COMPRESSED section of an ELF64 LE file."""
    d = path.read_bytes()
    if d[:4] != b"\x7fELF" or d[4] != 2 or d[5] != 1:
        fail(f"{path.name} is not a little-endian ELF64 file")
    shoff = struct.unpack_from("<Q", d, 0x28)[0]
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", d, 0x3A)
    names = struct.unpack_from("<Q", d, shoff + shstrndx * shentsize + 0x18)[0]
    out = {}
    for i in range(shnum):
        at = shoff + i * shentsize
        name_at = names + struct.unpack_from("<I", d, at)[0]
        flags, _, offset = struct.unpack_from("<QQQ", d, at + 8)
        if flags & SHF_COMPRESSED:
            out[d[name_at:d.index(b"\0", name_at)].decode()] = struct.unpack_from("<I", d, offset)[0]
    return out


def run(argv: list, what: str, check: bool = True) -> subprocess.CompletedProcess:
    r = subprocess.run([str(a) for a in argv], capture_output=True, text=True, errors="replace", timeout=900)
    if check and r.returncode != 0:
        print(" ".join(str(a) for a in argv))
        print(r.stdout + r.stderr)
        fail(f"{what} exited {r.returncode}")
    return r


def driver_linker(clang: Path, link: list) -> Path:
    """The program the driver runs for the link: the first word of its last job.
    On Windows the driver names it without its extension (`bin\\ld.lld`), which
    process creation supplies; the file is the one PATHEXT completes it to."""
    r = run([clang, *link, "-###"], "the driver, asked for its jobs")
    jobs = [line for line in (r.stdout + r.stderr).splitlines() if line.startswith(' "')]
    if not jobs:
        fail("the driver printed no job for the link")
    word = re.match(r'\s*"((?:[^"\\]|\\.)*)"', jobs[-1]).group(1)
    path = Path(re.sub(r"\\(.)", r"\1", word))
    if os.name == "nt" and not path.is_file():
        for ext in os.environ.get("PATHEXT", ".EXE").split(os.pathsep):
            if Path(f"{path}{ext}").is_file():
                return Path(f"{path}{ext}")
    return path


def same_file(a: Path, b: Path) -> bool:
    return os.path.normcase(os.path.realpath(a)) == os.path.normcase(os.path.realpath(b))


def source(path: Path) -> None:
    # Enough debug information that compressing it pays: a section that does
    # not shrink is written uncompressed, and the case would test nothing.
    with path.open("w") as f:
        for i in range(400):
            f.write(f"struct s{i} {{ int a; long b; double c; char d[{i + 1}]; }};\n")
            f.write(f"int f{i}(struct s{i} *p) {{ return p->a + (int)p->b + p->d[0]; }}\n")


def host_ld_lld(root: Path, obj: Path, work: Path) -> str:
    found = shutil.which("ld.lld")
    if not found:
        return "none on PATH"
    if same_file(Path(found), root / "bin" / f"ld.lld{EXE}"):
        return f"{found} (the payload's)"
    said = run([found, "--version"], "ld.lld --version", check=False)
    version = [line for line in (said.stdout + said.stderr).splitlines() if line.startswith("LLD")][:1]
    r = run([found, "-shared", obj, "-o", work / "host.so"], "the host's ld.lld", check=False)
    said = (r.stdout + r.stderr).strip().splitlines()[:1]
    verdict = "yes" if r.returncode == 0 else f"no ({said[0] if said else f'exit {r.returncode}'})"
    return f"{found} ({version[0] if version else 'no version'}): reads the zlib object: {verdict}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sha256", required=True)
    ap.add_argument("--work", type=Path, required=True)
    ap.add_argument("--url")
    ap.add_argument("--archive")
    args = ap.parse_args()
    if bool(args.url) == bool(args.archive):
        ap.error("one of --url and --archive")
    args.work.mkdir(parents=True, exist_ok=True)
    archive, origin = obtain(args)
    root = extract(archive, args.work / "payload")
    clang, ld_lld = root / "bin" / f"clang{EXE}", root / "bin" / f"ld.lld{EXE}"
    for program in (clang, ld_lld):
        if not program.is_file():
            fail(f"{root.name} has no bin/{program.name}")
    src = args.work / "debug.c"
    source(src)
    rows = []
    for alg, ch_type in ALGORITHMS.items():
        obj, out = args.work / f"{alg}.o", args.work / f"{alg}.so"
        run([clang, "--no-default-config", f"--target={TARGET}", "-g", f"-gz={alg}", "-c", src, "-o", obj],
            f"clang -gz={alg}")
        kinds = set(compressed_sections(obj).values())
        if kinds != {ch_type}:
            fail(f"the {alg} object's compressed sections are of types {sorted(kinds)}, not {ch_type}")
        link = ["--no-default-config", f"--target={TARGET}", "-fuse-ld=lld", "-nostdlib", "-shared",
                f"-Wl,--compress-debug-sections={alg}", obj, "-o", out]
        linker = driver_linker(clang, link)
        print(f"READING {alg}.linker: {linker}", flush=True)
        if not same_file(linker, ld_lld):
            fail(f"the driver runs {linker} for the {alg} link, not the payload's {ld_lld}")
        run([clang, *link], f"the {alg} link")
        kinds = set(compressed_sections(out).values())
        if kinds != {ch_type}:
            fail(f"the {alg} link wrote compressed sections of types {sorted(kinds)}, not {ch_type}")
        print(f"READING {alg}.link: reads and writes {alg}-compressed debug sections", flush=True)
        rows.append(alg)
    host = host_ld_lld(root, args.work / "zlib.o", args.work)
    print(f"READING host.ld.lld: {host}", flush=True)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("| archive | taken from | links | the driver's linker | `ld.lld` on the host's PATH |\n"
                    "|---|---|---|---|---|\n"
                    f"| `{archive.name}` | {origin} | {', '.join(rows)} | `{Path(*linker.parts[-2:])}` | {host} |\n")
    print(f"PASS: {root.name} links zlib- and zstd-compressed debug sections with its own ld.lld", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
