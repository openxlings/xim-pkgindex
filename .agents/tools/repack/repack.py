#!/usr/bin/env python3
"""Repack upstream binary packages (conda-forge, Debian) into the xlings payload shape.

WHY THIS EXISTS

conda-forge and Debian already build most of the libraries a desktop program
needs, against an old glibc baseline, for both architectures. Rebuilding them
would swap their toolchain for ours and gain nothing. What they do not do is
ship them in a shape xlings installs: a `.conda` is a zip of zstd tarballs with
the build machine's prefix padded into its files; a `.deb` puts libraries under
`usr/lib/<triplet>`. This script turns one or more such artefacts into

    <name>-<version>-linux-<arch>.tar.gz      (top level: <name>-<version>/)
    <name>-<version>-linux-<arch>.tar.gz.sha256

whose root holds lib/, include/, share/, licenses/, PROVENANCE.md and, when a
file must learn its install location, RELOCATE.json. The recipe consumes the
tarball from xlings-res; nothing in a hook ever parses conda or deb again.

The recipe is the specification. A package's source artefacts, their sha256
and any placeholder decisions belong in the recipe's own header comment, and
the command that produced the payload is recorded in PROVENANCE.md inside it.

PLACEHOLDERS

conda-forge builds in a 255-byte padded prefix and records, in
info/paths.json, which files embed it. Every file that still carries a
placeholder after the layout step is classified, and an unclassified one is a
failure -- the maintainer decides, the script does not guess:

  *.pc                 prefix=/usr, other occurrences -> ${prefix}; the shape
                       sysroot.relocate_pkgconfig expects at install time.
  --relocate GLOB      left in place and listed in RELOCATE.json; the recipe's
                       install() calls relocate.apply() to point it at the
                       payload's install directory (libs/relocate.lua).
  --host GLOB          the path names something the HOST owns (a daemon socket,
                       /etc configuration, the udev hwdb): rewritten here, with
                       NUL padding for binaries, by the FHS mapping
                       <ph>/etc -> /etc, <ph>/var -> /var, <ph>/... -> /usr/...
  --inert GLOB         left in place and recorded as harmless, with the reason
                       written in the recipe.

ELF files are not modified: install() seals them (selfcontain.seal) against the
dependency closure the resolver chose, so any RPATH written here would be
replaced there.

Exit codes follow .agents/tools/README.md: 0 produced, 1 broken (sha256
mismatch, unclassified placeholder, file collision, missing --require), 3 could
not run (missing tool, download failure).
"""
import argparse
import fnmatch
import hashlib
import io
import json
import lzma
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path

# Removed unless a --keep glob names them. Build-time and documentation
# content: nothing inside a subos consumes it, and several of these carry
# placeholders in executable text (libtool archives, config scripts).
DEFAULT_DROP = [
    "bin/**", "sbin/**", "libexec/**",
    "lib/*.a", "lib/*.la", "lib/cmake/**", "lib/girepository-1.0/**",
    "share/gir-1.0/**", "share/man/**", "share/doc/**", "share/gtk-doc/**",
    "share/info/**", "share/aclocal/**", "share/gettext/**", "share/bash-completion/**", "share/installed-tests/**",
    "share/applications/**", "share/licenses/**", "share/lintian/**",
    "etc/conda/**", "conda-meta/**", "info/**",
]

# conda-build pads with "_h_env_placehold_...", rattler-build with "host_env_placehold_..."
PLACEHOLDER_MARK = b"_placehold_placehold"
HOST_ROOTS = (b"/etc", b"/var")
DEB_TRIPLETS = {"x86_64": "x86_64-linux-gnu", "aarch64": "aarch64-linux-gnu"}


class Broken(Exception):
    """The subject is wrong: exit 1."""


class CannotRun(Exception):
    """This machine cannot do the work: exit 3."""


def log(msg):
    print(f"[repack] {msg}", file=sys.stderr)


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def match(rel, globs):
    return any(fnmatch.fnmatch(rel, g) for g in globs)


def fetch(url, sha256, cache):
    cache.mkdir(parents=True, exist_ok=True)
    dst = cache / url.rsplit("/", 1)[-1]
    if not dst.exists() or sha256_of(dst) != sha256:
        log(f"download {url}")
        tmp = dst.with_suffix(dst.suffix + ".part")
        try:
            with urllib.request.urlopen(url, timeout=300) as r, open(tmp, "wb") as f:
                shutil.copyfileobj(r, f)
        except OSError as e:
            raise CannotRun(f"download failed: {url}: {e}")
        tmp.rename(dst)
    got = sha256_of(dst)
    if got != sha256:
        raise Broken(f"sha256 mismatch for {url}: got {got}, want {sha256}")
    return dst


def zstd_decompress(data):
    if not shutil.which("zstd"):
        raise CannotRun("zstd not found on PATH")
    return subprocess.run(["zstd", "-dc"], input=data, capture_output=True, check=True).stdout


def untar(data, dest):
    with tarfile.open(fileobj=io.BytesIO(data)) as t:
        t.extractall(dest, filter="tar")


def extract_conda(archive, dest):
    """Returns (paths.json entries, index.json) and fills dest with the package tree."""
    info = {}
    if archive.name.endswith(".conda"):
        with zipfile.ZipFile(archive) as z:
            for n in z.namelist():
                if n.endswith(".tar.zst"):
                    untar(zstd_decompress(z.read(n)), dest)
    else:  # legacy .tar.bz2
        with tarfile.open(archive, "r:bz2") as t:
            t.extractall(dest, filter="tar")
    paths = dest / "info" / "paths.json"
    if paths.exists():
        info["paths"] = json.loads(paths.read_text())["paths"]
    index = dest / "info" / "index.json"
    if index.exists():
        info["index"] = json.loads(index.read_text())
    lic = dest / "info" / "licenses"
    if lic.is_dir():
        name = info.get("index", {}).get("name", archive.stem)
        shutil.copytree(lic, dest / "licenses" / name, dirs_exist_ok=True)
    return info


def ar_members(data):
    if not data.startswith(b"!<arch>\n"):
        raise Broken("not an ar archive")
    pos, out = 8, {}
    while pos + 60 <= len(data):
        hdr = data[pos:pos + 60]
        name = hdr[:16].decode().strip().rstrip("/")
        size = int(hdr[48:58].decode().strip())
        out[name] = data[pos + 60:pos + 60 + size]
        pos += 60 + size + (size & 1)
    return out


def extract_deb(archive, dest, arch):
    members = ar_members(archive.read_bytes())
    data_name = next((n for n in members if n.startswith("data.tar")), None)
    ctrl_name = next((n for n in members if n.startswith("control.tar")), None)
    if not data_name:
        raise Broken(f"{archive.name}: no data.tar member")

    def plain(name):
        raw = members[name]
        if name.endswith(".xz"):
            return lzma.decompress(raw)
        if name.endswith(".zst"):
            return zstd_decompress(raw)
        if name.endswith(".gz"):
            import gzip
            return gzip.decompress(raw)
        return raw

    raw = dest / ".raw"
    untar(plain(data_name), raw)
    control = {}
    if ctrl_name:
        cdir = dest / ".control"
        untar(plain(ctrl_name), cdir)
        for line in (cdir / "control").read_text().splitlines():
            if ":" in line and not line.startswith(" "):
                k, v = line.split(":", 1)
                control[k.strip()] = v.strip()
        shutil.rmtree(cdir)

    triplet = DEB_TRIPLETS[arch]
    moves = [
        (f"usr/lib/{triplet}", "lib"), (f"lib/{triplet}", "lib"),
        ("usr/include", "include"), ("usr/share", "share"), ("usr/lib", "lib"),
    ]
    for src, dst in moves:
        s = raw / src
        if s.is_dir():
            merge_tree(s, dest / dst)
            shutil.rmtree(s)
    pkg = control.get("Package", archive.stem)
    for c in (dest / "share" / "doc").glob("*/copyright"):
        (dest / "licenses" / pkg).mkdir(parents=True, exist_ok=True)
        shutil.copy2(c, dest / "licenses" / pkg / "copyright")
    shutil.rmtree(raw)
    return {"control": control}


def merge_tree(src, dst):
    for root, dirs, files in os.walk(src):
        rel = Path(root).relative_to(src)
        (dst / rel).mkdir(parents=True, exist_ok=True)
        for n in files + [d for d in dirs if (Path(root) / d).is_symlink()]:
            s, d = Path(root) / n, dst / rel / n
            if d.exists() or d.is_symlink():
                if s.is_symlink() and d.is_symlink() and os.readlink(s) == os.readlink(d):
                    continue
                if not s.is_symlink() and not d.is_symlink() and sha256_of(s) == sha256_of(d):
                    continue
                raise Broken(f"two sources ship different {rel / n}")
            if s.is_symlink():
                os.symlink(os.readlink(s), d)
            else:
                shutil.copy2(s, d)


def walk_files(root):
    for dirpath, dirs, files in os.walk(root):
        for n in files:
            p = Path(dirpath) / n
            yield p, p.relative_to(root).as_posix()


def prune(root, keep, drop):
    removed = []
    for p, rel in list(walk_files(root)):
        if match(rel, drop) and not match(rel, keep):
            p.unlink()
            removed.append(rel)
    for dirpath, dirs, files in os.walk(root, topdown=False):
        for d in dirs:
            dp = Path(dirpath) / d
            if dp.is_symlink() and not dp.exists():
                dp.unlink()
            elif dp.is_dir() and not dp.is_symlink() and not any(dp.iterdir()):
                dp.rmdir()
    # a symlink whose target was pruned is not a file anyone can use
    for p, rel in list(walk_files(root)):
        if p.is_symlink() and not p.exists():
            p.unlink()
            removed.append(rel)
    return removed


def rewrite_pc(path, placeholders):
    text = path.read_text()
    for ph in placeholders:
        lines = []
        for line in text.splitlines(keepends=True):
            if line.startswith("prefix=") and ph in line:
                lines.append("prefix=/usr\n")
            else:
                lines.append(line.replace(ph, "${prefix}"))
        text = "".join(lines)
    path.write_text(text)


def host_path(ph, rest):
    """Map a conda prefix path onto the host's FHS layout."""
    for r in HOST_ROOTS:
        if rest == r or rest.startswith(r + b"/"):
            return rest
    return b"/usr" + rest


def rewrite_host(data, ph, binary):
    """Replace every <ph><rest> by host_path(<rest>), keeping the file length for binaries.

    <rest> runs to the next byte that cannot be part of a path, so a string
    such as "Listen <ph>/var/run/cups/cups.sock" keeps its surroundings.
    """
    phb = ph.encode()

    def one(chunk):
        out, pos, shrink = [], 0, 0
        while True:
            i = chunk.find(phb, pos)
            if i < 0:
                break
            j = i + len(phb)
            while j < len(chunk) and chunk[j:j + 1] not in (b" ", b":", b";", b'"', b"'", b"\n", b"\t"):
                j += 1
            new = host_path(phb, chunk[i + len(phb):j])
            out += [chunk[pos:i], new]
            shrink += (j - i) - len(new)
            pos = j
        out.append(chunk[pos:])
        return b"".join(out), shrink

    if not binary:
        return one(data)[0]
    parts = data.split(b"\0")
    fixed = []
    for part in parts[:-1]:
        new, shrink = one(part)
        if shrink < 0:
            raise Broken("host path longer than the placeholder it replaces")
        fixed.append(new + b"\0" * shrink)
    new, shrink = one(parts[-1])
    if shrink:
        raise Broken("placeholder in an unterminated trailing string")
    fixed.append(new)
    return b"\0".join(fixed)


def audit(root, declared, relocate_globs, host_globs, inert_globs):
    """Classify every file that still carries a build placeholder."""
    placeholders = sorted({d["prefix_placeholder"] for d in declared}, key=len, reverse=True)
    modes = {d["_path"]: d.get("file_mode", "text") for d in declared}
    result = {"pc": [], "relocate": [], "host": [], "inert": [], "unresolved": []}
    for p, rel in sorted(walk_files(root), key=lambda x: x[1]):
        if p.is_symlink():
            continue
        data = p.read_bytes()
        hits = [ph for ph in placeholders if ph.encode() in data]
        if not hits and PLACEHOLDER_MARK not in data:
            continue
        if not hits:
            result["unresolved"].append((rel, "undeclared placeholder (not in paths.json)"))
            continue
        if rel.endswith(".pc"):
            rewrite_pc(p, hits)
            result["pc"].append(rel)
        elif match(rel, relocate_globs):
            mode = modes.get(rel) or ("binary" if b"\0" in data else "text")
            for ph in hits:
                result["relocate"].append({"path": rel, "mode": mode, "placeholder": ph})
        elif match(rel, host_globs):
            binary = modes.get(rel, "binary" if b"\0" in data else "text") == "binary"
            for ph in hits:
                data = rewrite_host(data, ph, binary)
            p.write_bytes(data)
            result["host"].append(rel)
        elif match(rel, inert_globs):
            result["inert"].append(rel)
        else:
            result["unresolved"].append((rel, "placeholder with no decision"))
    return result


def canonical_command(args):
    """The command that reproduces this payload, independent of where it ran."""
    pairs = [("--name", args.name), ("--version", args.version), ("--arch", args.arch)]
    for flag in ("src", "keep", "drop", "relocate", "host", "inert", "require"):
        pairs += [(f"--{flag}", f"'{v}'" if any(c in v for c in "*?[") else v)
                  for v in getattr(args, flag)]
    return " \\\n    ".join([".agents/tools/repack/repack.py"] + [f"{k} {v}" for k, v in pairs])


def provenance(args, sources, result, removed):
    lines = [f"# {args.name} {args.version} ({args.arch})", "",
             "Repacked by `.agents/tools/repack/repack.py`; no file below was rebuilt.", "",
             "## Sources", "", "| artefact | sha256 | origin |", "|---|---|---|"]
    for s in sources:
        meta = s["meta"]
        if "index" in meta:
            i = meta["index"]
            origin = f"conda-forge {i.get('name')} {i.get('version')} {i.get('build')} ({i.get('license', '?')})"
        elif "control" in meta:
            c = meta["control"]
            origin = f"Debian {c.get('Package')} {c.get('Version')} {c.get('Architecture')}"
        else:
            origin = "?"
        lines.append(f"| {s['url']} | `{s['sha256']}` | {origin} |")
    lines += ["", "## Command", "", "```", canonical_command(args), "```", "",
              "## Placeholder audit", ""]
    lines.append(f"- pkg-config rewritten to prefix=/usr: {', '.join(result['pc']) or 'none'}")
    lines.append("- relocated at install time (RELOCATE.json): "
                 + (", ".join(sorted({e['path'] for e in result['relocate']})) or "none"))
    lines.append(f"- mapped onto host paths (/etc, /var, /usr): {', '.join(result['host']) or 'none'}")
    lines.append(f"- inert, left in place: {', '.join(result['inert']) or 'none'}")
    lines += ["", f"## Not shipped ({len(removed)} files)", "",
              "Default drop list plus: " + (", ".join(args.drop) or "nothing"), ""]
    return "\n".join(lines)


def build(args, prepare=None):
    """Build a payload, optionally preparing generated data before its audit.

    Imported callers may supply prepare(root). It runs after pruning but before
    placeholder auditing, required-path checks, provenance and final packaging.
    The caller must record its full reproduction command and generator versions
    in BUILD-METADATA.json; the bare repack command cannot reproduce that data.
    """
    for tool in ("tar", "gzip"):
        if not shutil.which(tool):
            raise CannotRun(f"{tool} not found on PATH")
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    cache = Path(args.cache).expanduser()
    top = f"{args.name}-{args.version}"
    with tempfile.TemporaryDirectory(prefix="repack-") as tmp:
        tmp = Path(tmp)
        root = tmp / top
        root.mkdir()
        sources, declared = [], []
        for i, spec in enumerate(args.src):
            url, _, sha = spec.partition("#")
            if len(sha) != 64:
                raise Broken(f"--src needs URL#SHA256, got {spec}")
            archive = fetch(url, sha, cache)
            stage = tmp / f"src{i}"
            stage.mkdir()
            if archive.name.endswith(".deb"):
                meta = extract_deb(archive, stage, args.arch)
            elif archive.name.endswith((".conda", ".tar.bz2")):
                meta = extract_conda(archive, stage)
                declared += [p for p in meta.get("paths", []) if p.get("prefix_placeholder")]
                # Package-local metadata collides across sources; its parsed
                # provenance and copied licenses above are retained separately.
                prune(stage, args.keep, ["info/**"])
            else:
                raise Broken(f"unsupported artefact: {archive.name}")
            merge_tree(stage, root)
            sources.append({"url": url, "sha256": sha, "meta": meta})

        removed = prune(root, args.keep, DEFAULT_DROP + args.drop)
        if prepare is not None:
            prepare(root)
        result = audit(root, declared, args.relocate, args.host, args.inert)
        if result["unresolved"]:
            for rel, why in result["unresolved"]:
                log(f"UNRESOLVED {rel}: {why}")
            raise Broken("placeholders need a decision: pass --relocate or --inert for the files above")
        missing = [r for r in args.require if not (root / r).exists()]
        if missing:
            raise Broken("payload lacks required files: " + ", ".join(missing))

        if result["relocate"]:
            (root / "RELOCATE.json").write_text(json.dumps(
                {"schema": 1, "entries": result["relocate"]}, indent=2) + "\n")
        details = provenance(args, sources, result, removed)
        if prepare is not None:
            details = details.replace(
                "## Command\n", "## Command\n\n"
                "This bare repack command reproduces only the source layout, not "
                "prepared/generated data. Use the complete builder command and "
                "tool versions in `BUILD-METADATA.json` to reproduce this payload.\n",
                1,
            )
        (root / "PROVENANCE.md").write_text(details)

        tarball = out / f"{top}-linux-{args.arch}.tar.gz"
        subprocess.run(["tar", "--sort=name", "--owner=0", "--group=0", "--numeric-owner",
                        "--mtime=@0", "-I", "gzip -n", "-cf", str(tarball), "-C", str(tmp), top],
                       check=True)
        digest = sha256_of(tarball)
        (out / (tarball.name + ".sha256")).write_text(f"{digest}  {tarball.name}\n")
        log(f"{tarball.name}  sha256={digest}")
        log(f"  pc={len(result['pc'])} relocate={len(result['relocate'])} "
            f"host={len(result['host'])} inert={len(result['inert'])} dropped={len(removed)}")
        print(json.dumps({"name": args.name, "version": args.version, "arch": args.arch,
                          "file": str(tarball), "sha256": digest}))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--name", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--arch", required=True, choices=sorted(DEB_TRIPLETS))
    ap.add_argument("--src", action="append", required=True, metavar="URL#SHA256",
                    help="upstream artefact; repeat to merge several into one payload")
    ap.add_argument("--keep", action="append", default=[], metavar="GLOB",
                    help="ship a path the default drop list would remove")
    ap.add_argument("--drop", action="append", default=[], metavar="GLOB")
    ap.add_argument("--relocate", action="append", default=[], metavar="GLOB")
    ap.add_argument("--host", action="append", default=[], metavar="GLOB")
    ap.add_argument("--inert", action="append", default=[], metavar="GLOB")
    ap.add_argument("--require", action="append", default=[], metavar="PATH")
    ap.add_argument("--out", default="dist")
    ap.add_argument("--cache", default="~/.cache/xlings-repack")
    args = ap.parse_args()
    try:
        build(args)
    except Broken as e:
        log(f"BROKEN: {e}")
        sys.exit(1)
    except CannotRun as e:
        log(f"NOT RUN: {e}")
        sys.exit(3)
    except subprocess.CalledProcessError as e:
        log(f"NOT RUN: {e}")
        sys.exit(3)


if __name__ == "__main__":
    main()
