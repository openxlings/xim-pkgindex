"""How a recipe's entries state their CPU architectures, read as the client reads them.

Shared by the architecture census (tools/arch_census.py), the migration tool
(tools/arch-migrate) and the checks K1 and K3 (tools/xpkg_ci.py arch-check).

A recipe is loaded AS LUA in the recipe sandbox (.github/scripts/recipe-sandbox.lua,
through tools/xpkg_arch_dump.lua): the values the client sees, not a text
sweep. Each version entry is then parsed the way libxpkg's loader parses it
(xpkg-loader.cppm) and classified the way the client classifies it
(xpkg-compat.cppm `classify_arch_evidence`):

  Strong  the entry enumerates its architectures: a per-architecture map,
          per-architecture `sha256`, or per-architecture `arch_alias`
  Open    `res = true`, or `${arch}` / `${arch_alias}` in a URL
  Weak    one artifact, and only `package.archs` to go on
  None    one artifact and no `package.archs`

The design these checks implement is the ecosystem-convergence design, §5.2
(`archs` is the union of the entries' architectures), §5.3 (how an entry
states its architectures) and §5.6 (K1, K3).
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DUMP = Path(__file__).resolve().parent / "xpkg_arch_dump.lua"

# libxpkg's architecture identities (xpkg.cppm kArchIdentities): canonical
# name, spellings.
ARCH_ALIASES = {
    "x86_64": "x86_64", "amd64": "x86_64", "x64": "x86_64", "x86-64": "x86_64",
    "aarch64": "aarch64", "arm64": "aarch64", "armv8": "aarch64",
    "x86": "x86", "i386": "x86", "i686": "x86",
    "arm": "arm", "armv7": "arm", "armv7l": "arm", "armhf": "arm",
    "riscv64": "riscv64",
    "loongarch64": "loongarch64", "loong64": "loongarch64",
}

# The host architectures of each platform the index serves (design §5.7). On
# a platform with ONE, an entry that names none is that one (§5.3); K1 asks
# only on a platform with two.
HOST_ARCHS = {
    "linux": ("x86_64", "aarch64"),
    "macosx": ("aarch64",),
    "windows": ("x86_64",),
}

# Keys of a platform section that are not version entries (libxpkg's loader,
# plus the template fields check-revision.lua also skips).
PLATFORM_FIELDS = {"deps", "inherits", "ref", "exports", "source", "strip",
                   "url_template", "arch_alias", "res_versioned"}

STUB = "<stub>"


def normalize_arch(name: str) -> str:
    low = str(name).lower()
    return ARCH_ALIASES.get(low, low)


def is_arch_name(name: str) -> bool:
    return str(name).lower() in ARCH_ALIASES


# ── loading ────────────────────────────────────────────────────────────────

def find_lua() -> str:
    for candidate in ("lua5.4", "lua5.3", "lua"):
        path = shutil.which(candidate)
        if not path:
            continue
        probe = subprocess.run(
            [path, "-e", 'os.exit((tonumber(_VERSION:match("%d+%.%d+")) or 0) >= 5.3 and 0 or 1)'],
            capture_output=True)
        if probe.returncode == 0:
            return path
    raise RuntimeError("no Lua 5.3+ interpreter (lua5.4, lua5.3, lua): the recipes are loaded as Lua")


def load_recipes(files: Iterable[Path | str], arch: str | None = None,
                 root: Path = ROOT) -> dict[str, dict[str, Any]]:
    """file (relative to root) -> {"package": {...}} or {"error": "..."}."""
    lua = find_lua()
    names = [str(Path(f).resolve().relative_to(root.resolve())) if Path(f).is_absolute() else str(f)
             for f in files]
    out: dict[str, dict[str, Any]] = {}
    for start in range(0, len(names), 200):
        batch = names[start:start + 200]
        cmd = [lua, str(DUMP)] + (["--arch", arch] if arch else []) + batch
        run = subprocess.run(cmd, cwd=root, capture_output=True, text=True)
        if run.returncode != 0:
            raise RuntimeError(f"recipe dump failed: {run.stderr.strip()}")
        for line in run.stdout.splitlines():
            if line.strip():
                item = json.loads(line)
                out[item["file"]] = item
    return out


def load_recipe_text(text: str, name: str = "recipe.lua", arch: str | None = None) -> dict[str, Any]:
    """The `package` table of recipe text that is not a file in the tree."""
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / Path(name).name
        path.write_text(text, encoding="utf-8")
        lua = find_lua()
        cmd = [lua, str(DUMP)] + (["--arch", arch] if arch else []) + [str(path)]
        run = subprocess.run(cmd, capture_output=True, text=True)
        if run.returncode != 0 or not run.stdout.strip():
            return {"error": run.stderr.strip() or "no output"}
        return json.loads(run.stdout.splitlines()[0])


def all_recipe_files(root: Path = ROOT) -> list[str]:
    return sorted(str(p.relative_to(root)) for p in (root / "pkgs").glob("*/*.lua"))


# ── the entry, as libxpkg's loader reads it ────────────────────────────────

def _str(v: Any) -> str:
    return v if isinstance(v, str) and v != STUB else ""


def _str_map(v: Any) -> dict[str, str]:
    if not isinstance(v, dict):
        return {}
    return {str(k): s for k, s in v.items() if isinstance(s, str) and s != STUB}


@dataclass
class Entry:
    version: str
    raw: Any
    url: str = ""
    mirrors: dict[str, str] = field(default_factory=dict)
    sha256: str = ""
    sha256_by_arch: dict[str, str] = field(default_factory=dict)
    arch_alias: dict[str, str] = field(default_factory=dict)
    archs: dict[str, dict[str, Any]] = field(default_factory=dict)   # Scheme B
    is_res: bool = False
    ref: str = ""

    def architectures(self) -> set[str]:
        """libxpkg `entry_architectures`."""
        return set(self.archs) | set(self.sha256_by_arch) | set(self.arch_alias)

    def templated(self) -> bool:
        def t(u: str) -> bool:
            return "${arch}" in u or "${arch_alias}" in u
        return t(self.url) or any(t(u) for u in self.mirrors.values())

    def artifact_urls(self) -> dict[str, str]:
        """arch (or "*" for every architecture) -> URL as written."""
        if self.archs:
            return {a: r.get("url", "") for a, r in self.archs.items() if r.get("url")}
        if self.url:
            return {"*": self.url}
        return {}


def parse_entry(version: str, value: Any) -> Entry:
    e = Entry(version=version, raw=value)
    if isinstance(value, str):
        e.url = _str(value)
        return e
    if not isinstance(value, dict):
        return e
    e.url = _str(value.get("url"))
    if not e.url:
        e.mirrors = _str_map(value.get("url"))
        e.url = e.mirrors.get("GLOBAL") or next(iter(e.mirrors.values()), "")
    e.sha256 = _str(value.get("sha256"))
    e.ref = _str(value.get("ref"))
    if e.ref == version:
        e.ref = ""
    e.sha256_by_arch = {normalize_arch(k): v for k, v in _str_map(value.get("sha256")).items()}
    e.arch_alias = {normalize_arch(k): v for k, v in _str_map(value.get("arch_alias")).items()}
    e.is_res = value.get("res") is True
    if not (e.url or e.ref or e.sha256 or e.sha256_by_arch or e.is_res):
        for key, sub in value.items():
            if isinstance(sub, dict) and is_arch_name(key):
                url = _str(sub.get("url"))
                mirrors = {} if url else _str_map(sub.get("url"))
                if not url:
                    url = mirrors.get("GLOBAL") or next(iter(mirrors.values()), "")
                e.archs[normalize_arch(key)] = {"url": url, "sha256": _str(sub.get("sha256")),
                                                "mirrors": mirrors}
    return e


@dataclass
class Platform:
    name: str
    entries: dict[str, Entry]
    source: str = ""
    inherits: str = ""


def platforms(pkg: dict[str, Any]) -> dict[str, Platform]:
    xpm = pkg.get("xpm") if isinstance(pkg, dict) else None
    out: dict[str, Platform] = {}
    if not isinstance(xpm, dict):
        return out
    for name, section in xpm.items():
        if name == "source" or not isinstance(section, dict):
            continue
        src = _str(section.get("source"))
        if not src:
            m = _str_map(section.get("source"))
            src = m.get("GLOBAL") or next(iter(m.values()), "")
        inherits = _str(section.get("inherits")) or _str(section.get("ref"))
        entries = {str(k): parse_entry(str(k), v) for k, v in section.items()
                   if str(k) not in PLATFORM_FIELDS}
        out[name] = Platform(name, entries, src, inherits)
    # Inheritance (libxpkg resolve_inheritance): versions and source.
    for name, plat in out.items():
        seen = {name}
        parent = plat.inherits
        while parent and parent not in seen:
            seen.add(parent)
            p = out.get(parent)
            if not p:
                break
            for v, e in p.entries.items():
                plat.entries.setdefault(v, e)
            if not plat.source:
                plat.source = p.source
            parent = p.inherits
    return out


def matrix_source(pkg: dict[str, Any]) -> str:
    xpm = pkg.get("xpm") if isinstance(pkg, dict) else None
    if not isinstance(xpm, dict):
        return ""
    s = _str(xpm.get("source"))
    if not s:
        m = _str_map(xpm.get("source"))
        s = m.get("GLOBAL") or next(iter(m.values()), "")
    return s


def find_entry(plat: Platform, version: str) -> Entry | None:
    key = version
    for _ in range(8):
        e = plat.entries.get(key)
        if e is None:
            return None
        if not e.ref:
            return e
        key = e.ref
    return None


def _version_key(v: str) -> tuple:
    return tuple((0, int(p)) if p.isdigit() else (1, p) for p in re.split(r"[.\-+_]", v))


def latest_entry(plat: Platform, fallback: bool = True) -> Entry | None:
    """The entry `latest` names; without `latest`, the highest version (none when not `fallback`)."""
    if "latest" in plat.entries:
        return find_entry(plat, "latest")
    if not fallback:
        return None
    concrete = [v for v, e in plat.entries.items() if not e.ref]
    if not concrete:
        return None
    return plat.entries[max(concrete, key=_version_key)]


def declares_no_download_source(pkg: dict[str, Any], plat: Platform, e: Entry) -> bool:
    if e.is_res or e.url:
        return False
    if any(r.get("url") for r in e.archs.values()):
        return False
    if plat.source:
        return False
    return not matrix_source(pkg)


def classify(pkg: dict[str, Any], e: Entry | None) -> str:
    if e is not None:
        if e.architectures():
            return "Strong"
        if e.is_res or e.templated():
            return "Open"
    return "Weak" if package_archs(pkg) else "None"


def package_archs(pkg: dict[str, Any]) -> list[str]:
    a = pkg.get("archs") if isinstance(pkg, dict) else None
    if isinstance(a, list):
        return [normalize_arch(x) for x in a if isinstance(x, str)]
    return []


def is_subos(pkg: dict[str, Any]) -> bool:
    return isinstance(pkg, dict) and pkg.get("type") == "subos"


# ── K1 and K3 ──────────────────────────────────────────────────────────────

@dataclass
class Finding:
    code: str        # "K1" | "K3"
    file: str
    message: str
    fix: list[str] | None = None   # K3: the archs it should be


def entry_archs_for_union(pkg: dict[str, Any], pname: str, plat: Platform, e: Entry) -> set[str]:
    """What one concrete entry contributes to the union `archs` is (§5.2).

    An entry that names its architectures: those. On a platform with one host
    architecture, any other entry is for that one (§5.3): whatever it holds,
    only that machine installs it. On Linux, an entry that names none says
    nothing: one artifact without a name (K1's finding), `${arch}` or `res`
    (as many as upstream publishes), or no artifact (its hook decides).
    """
    named = e.architectures()
    if named:
        return named
    hosts = HOST_ARCHS.get(pname)
    if hosts and len(hosts) == 1:
        return {hosts[0]}
    return set()


def is_git_repository(e: Entry) -> bool:
    """A URL ending in `.git` is a repository the client clones: no artifact,
    no digest to name architectures with (brew, musl-cross-make)."""
    return bool(e.url) and e.url.split("?", 1)[0].endswith(".git") and not e.architectures()


def check_k1(file: str, pkg: dict[str, Any]) -> list[Finding]:
    """K1: on a platform with two host architectures, an entry with an artifact names them."""
    out: list[Finding] = []
    if is_subos(pkg):
        return out
    for pname, plat in sorted(platforms(pkg).items()):
        hosts = HOST_ARCHS.get(pname)
        if not hosts or len(hosts) < 2:
            continue
        for version, e in sorted(plat.entries.items()):
            if e.ref or declares_no_download_source(pkg, plat, e) or is_git_repository(e):
                continue
            if classify(pkg, e) in ("Weak", "None"):
                out.append(Finding("K1", file,
                    f'xpm.{pname}["{version}"]: one artifact and no architecture named; list it for the '
                    'ones it is (sha256 = { x86_64 = "<hash>" }, the same hash under each architecture '
                    'when it has no machine code)'))
    return out


def archs_union(pkg: dict[str, Any]) -> tuple[set[str], bool]:
    """The union of the entries' architectures, and whether it is known.

    Unknown when some entry contributes nothing that can be read: a Linux
    entry with an artifact that names no architecture (K1's finding), an
    arch-parametric one (`${arch}`, `res`), or one with no artifact, whose
    hook decides what it installs. The union then cannot be computed from the
    recipe, and K3 does not judge: an install on each architecture does.
    """
    union: set[str] = set()
    known = True
    for pname, plat in platforms(pkg).items():
        if pname not in HOST_ARCHS:
            continue
        for e in plat.entries.values():
            if e.ref:
                continue
            contributed = entry_archs_for_union(pkg, pname, plat, e)
            if not contributed:
                known = False
            union |= contributed
    return union, known


def check_k3(file: str, pkg: dict[str, Any]) -> list[Finding]:
    """K3: `package.archs` is the union of what the entries list."""
    if is_subos(pkg):
        return []
    union, known = archs_union(pkg)
    if not known or not union:
        return []
    declared = set(package_archs(pkg))
    if declared == union:
        return []
    missing, extra = sorted(union - declared), sorted(declared - union)
    parts = []
    if missing:
        parts.append("entries list " + ", ".join(missing) + " and archs does not")
    if extra:
        parts.append("archs lists " + ", ".join(extra) + " and no entry does")
    return [Finding("K3", file, "package.archs is the union of what the entries list: " + "; ".join(parts),
                    fix=order_archs(union))]


ARCH_ORDER = ["x86_64", "aarch64", "x86", "arm", "riscv64", "loongarch64"]


def order_archs(archs: Iterable[str]) -> list[str]:
    return sorted(archs, key=lambda a: (ARCH_ORDER.index(a) if a in ARCH_ORDER else 99, a))


ARCHS_LINE = re.compile(r'^(\s*archs\s*=\s*)\{[^}\n]*\}', re.MULTILINE)


def fix_archs_text(text: str, archs: list[str]) -> str | None:
    """The recipe text with its `archs = {...}` set to `archs`; None when it has no one such line."""
    matches = list(ARCHS_LINE.finditer(text))
    value = "{" + ", ".join(f'"{a}"' for a in archs) + "}"
    if not matches:
        # No `archs` yet: after the package's `type` (else `name`) line.
        for key in ("type", "name"):
            m = re.search(r'^([ \t]*)' + key + r'\s*=\s*"[^"\n]*",[^\n]*\n', text, re.MULTILINE)
            if m:
                return text[:m.end()] + f"{m.group(1)}archs = {value},\n" + text[m.end():]
        return None
    if len(matches) != 1:
        return None
    m = matches[0]
    return text[:m.start()] + m.group(1) + value + text[m.end():]
