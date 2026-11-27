#!/usr/bin/env python3
"""The architecture census of the index, and its architecture coverage table.

    python3 tools/arch_census.py census [--root <checkout>] [--json <out>] [--list <class>]
    python3 tools/arch_census.py coverage [--root <checkout>] [--output <md>] [--json <out>]

`census` classifies the Linux entry `latest` names in every recipe the way the
client does (tools/xpkg_arch.py) and prints the table of the design's §2.2:
how many enumerate their architectures (Strong), are arch-parametric (Open),
have one artifact by URL, one through `source`, only hooks (Weak), name no
architecture at all (None), or have no Linux entry. `--list <class>` prints
the recipes of one row (strong, open, url, url-x86_64, url-multi, source,
hook, hook-x86_64, none, none-url, absent).

`coverage` writes the coverage table (design §5.6): for every package and
host architecture of Linux, whether its `latest` entry is installable there
(the entry names the architecture, or is arch-parametric, or has no artifact),
and whether its whole dependency closure is. An entry that names no
architecture is "unstated": it may be anything, and counts as not shown
installable. The table answers "which packages, once added, make the most
packages installable on aarch64".

Recipes are loaded as Lua (lua5.4) in the recipe sandbox; no network.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import xpkg_arch as xa  # noqa: E402


def census_rows(root: Path) -> dict[str, list[str]]:
    loaded = xa.load_recipes(xa.all_recipe_files(root), root=root)
    rows: dict[str, list[str]] = defaultdict(list)
    for file, item in sorted(loaded.items()):
        pkg = item.get("package")
        if not isinstance(pkg, dict):
            rows["load-error"].append(file)
            continue
        plats = xa.platforms(pkg)
        linux = plats.get("linux")
        e = xa.latest_entry(linux) if linux else None
        if e is None:
            rows["absent"].append(file)
            continue
        cls = xa.classify(pkg, e)
        # The census of the design (§2.2) counts an `"XLINGS_RES"` entry with
        # the arch-parametric ones: its asset name carries the architecture
        # (`<name>-<version>-linux-<arch>.tar.gz`). libxpkg reads it as one
        # artifact with no architecture named, and K1 asks it to name them.
        if cls in ("Weak", "None") and e.url == "XLINGS_RES":
            cls = "Open"
        archs = set(xa.package_archs(pkg))
        if cls == "Strong":
            rows["strong"].append(file)
            if "aarch64" in e.architectures():
                rows["strong-aarch64"].append(file)
            elif e.architectures() == {"x86_64"}:
                rows["strong-x86_64"].append(file)
            else:
                rows["strong-other"].append(file)
        elif cls == "Open":
            rows["open"].append(file)
        else:
            nosrc = xa.declares_no_download_source(pkg, linux, e)
            if cls == "None":
                rows["none"].append(file)
                if e.url:
                    rows["none-url"].append(file)
                    if isinstance(e.raw, str) or isinstance(e.raw.get("url"), str):
                        rows["none-url-string"].append(file)
            elif e.url:
                rows["url"].append(file)
                rows["url-x86_64" if archs == {"x86_64"} else "url-multi"].append(file)
            elif nosrc:
                rows["hook"].append(file)
                if archs == {"x86_64"}:
                    rows["hook-x86_64"].append(file)
            else:
                rows["source"].append(file)
    return rows


def cmd_census(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    rows = census_rows(root)
    if args.list:
        for f in rows.get(args.list, []):
            print(f)
        return 0
    total = sum(len(rows[k]) for k in ("strong", "open", "url", "source", "hook", "none", "absent", "load-error"))
    n = lambda k: len(rows.get(k, []))  # noqa: E731
    print(f"recipes: {total}")
    print("| class | count | detail |")
    print("|---|---|---|")
    print(f"| enumerated (Strong) | {n('strong')} | {n('strong-aarch64')} name aarch64; "
          f"{n('strong-x86_64')} only x86_64; {n('strong-other')} other |")
    print(f"| template or res (Open) | {n('open')} | |")
    print(f"| one artifact, URL (Weak) | {n('url')} | {n('url-x86_64')} declare only x86_64; "
          f"{n('url-multi')} declare more |")
    print(f"| one artifact, through source (Weak) | {n('source')} | |")
    print(f"| only hooks, no artifact (Weak) | {n('hook')} | {n('hook-x86_64')} declare only x86_64 |")
    print(f"| no archs (None) | {n('none')} | {n('none-url')} with a URL ({n('none-url-string')} a string, the rest a mirror table) |")
    print(f"| no Linux entry or no version | {n('absent')} | |")
    if n("load-error"):
        print(f"| does not load | {n('load-error')} | {' '.join(rows['load-error'])} |")
    if args.json:
        Path(args.json).write_text(json.dumps(rows, indent=1, sort_keys=True) + "\n")
    return 0


# ── coverage ───────────────────────────────────────────────────────────────

def _dep_name(dep: str) -> str | None:
    """`xim:glibc@2.39` -> glibc; deps of another index are outside this table."""
    d = dep.strip()
    if ":" in d:
        ns, d = d.split(":", 1)
        if ns not in ("xim", ""):
            return None
    return d.split("@", 1)[0] or None


def _linux_deps(pkg: dict, version: str) -> list[str]:
    xpm = pkg.get("xpm") or {}
    sec = xpm.get("linux") if isinstance(xpm, dict) else None
    if not isinstance(sec, dict):
        return []
    deps: list[str] = []

    def take(v):
        if isinstance(v, list):
            deps.extend(x for x in v if isinstance(x, str))
        elif isinstance(v, dict):
            for key in ("runtime", "build"):
                take(v.get(key))
            deps.extend(x for k, x in v.items() if k.isdigit() and isinstance(x, str))
    take(sec.get("deps"))
    entry = sec.get(version)
    if isinstance(entry, dict):
        take(entry.get("deps"))
    return deps


def coverage(root: Path) -> dict[str, dict]:
    loaded = xa.load_recipes(xa.all_recipe_files(root), root=root)
    table: dict[str, dict] = {}
    for file, item in loaded.items():
        pkg = item.get("package")
        if not isinstance(pkg, dict) or not isinstance(pkg.get("name"), str):
            continue
        linux = xa.platforms(pkg).get("linux")
        e = xa.latest_entry(linux) if linux else None
        row = {"file": file, "archs": {}, "deps": []}
        if e is None:
            for a in xa.HOST_ARCHS["linux"]:
                row["archs"][a] = "absent"
        else:
            named = e.architectures()
            nosrc = xa.declares_no_download_source(pkg, linux, e)
            for a in xa.HOST_ARCHS["linux"]:
                if named:
                    row["archs"][a] = "yes" if a in named else "no"
                elif e.is_res or e.templated() or nosrc:
                    row["archs"][a] = "yes"
                else:
                    row["archs"][a] = "unstated"
            row["deps"] = sorted({d for d in (_dep_name(x) for x in _linux_deps(pkg, e.version)) if d})
        table[pkg["name"]] = row
    # The closure: installable when the package and every dependency is.
    for arch in xa.HOST_ARCHS["linux"]:
        memo: dict[str, tuple[bool, list[str]]] = {}

        def closure(name: str, stack: tuple[str, ...]) -> tuple[bool, list[str]]:
            if name in memo:
                return memo[name]
            row = table.get(name)
            if row is None:
                return True, []   # another index's, or a name this table does not hold
            if name in stack:
                return True, []
            missing = [] if row["archs"][arch] == "yes" else [name]
            for d in row["deps"]:
                ok, m = closure(d, stack + (name,))
                missing.extend(x for x in m if x not in missing)
            memo[name] = (not missing, missing)
            return memo[name]
        for name, row in table.items():
            ok, missing = closure(name, ())
            row.setdefault("closure", {})[arch] = {"ok": ok, "missing": missing}
    return table


MARK = {"yes": "yes", "no": "no", "unstated": "unstated", "absent": "-"}


def cmd_coverage(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    table = coverage(root)
    names = sorted(table)
    blockers = Counter()
    for name in names:
        c = table[name]["closure"]["aarch64"]
        if table[name]["archs"]["aarch64"] != "absent":
            for m in c["missing"]:
                blockers[m] += 1
    lines = [
        "# Architecture coverage",
        "",
        "Generated by `python3 tools/arch_census.py coverage` from the recipes in this",
        "index; do not edit by hand. For every package, whether the Linux entry its",
        "`latest` names can be installed on each host architecture, and whether its",
        "whole dependency closure can:",
        "",
        "- **yes**: the entry names the architecture (a per-architecture resource or",
        "  checksum), builds its URL from it (`${arch}`), or has no artifact;",
        "- **no**: the entry names other architectures and not this one;",
        "- **unstated**: one artifact and no architecture named: what it holds is not",
        "  known from the recipe (the client installs it and checks the machine of",
        "  the files it exposes);",
        "- **-**: no Linux entry.",
        "",
        "The closure column names what is missing in the closure (the package",
        "itself, or a dependency).",
        "",
    ]
    summary = Counter()
    for name in names:
        for a in xa.HOST_ARCHS["linux"]:
            summary[(a, table[name]["archs"][a])] += 1
            if table[name]["archs"][a] != "absent":
                summary[(a, "closure-ok" if table[name]["closure"][a]["ok"] else "closure-no")] += 1
    lines += ["## Summary", "", "| | x86_64 | aarch64 |", "|---|---|---|"]
    for key, label in (("yes", "installable"), ("no", "not provided"), ("unstated", "unstated"),
                       ("absent", "no Linux entry"), ("closure-ok", "closure installable"),
                       ("closure-no", "closure not installable")):
        lines.append(f"| {label} | {summary[('x86_64', key)]} | {summary[('aarch64', key)]} |")
    lines += ["", "## What to add for aarch64", "",
              "The packages that stand in the most closures on aarch64 (a package counts",
              "in its own closure):", "", "| package | closures it is missing from |", "|---|---|"]
    for name, count in blockers.most_common(30):
        lines.append(f"| `{name}` | {count} |")
    lines += ["", "## Packages", "", "| package | x86_64 | aarch64 | closure on aarch64 |", "|---|---|---|---|"]
    for name in names:
        row = table[name]
        if row["archs"]["aarch64"] == "absent":
            cl = "-"
        else:
            c = row["closure"]["aarch64"]
            cl = "yes" if c["ok"] else "missing: " + ", ".join(f"`{m}`" for m in c["missing"][:6]) + (
                f" and {len(c['missing']) - 6} more" if len(c["missing"]) > 6 else "")
        lines.append(f"| `{name}` | {MARK[row['archs']['x86_64']]} | {MARK[row['archs']['aarch64']]} | {cl} |")
    text = "\n".join(lines) + "\n"
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    if args.json:
        Path(args.json).write_text(json.dumps(table, indent=1, sort_keys=True) + "\n")
    if args.check and args.output:
        return 0
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("census")
    p.add_argument("--root", default=str(xa.ROOT))
    p.add_argument("--json")
    p.add_argument("--list")
    p.set_defaults(func=cmd_census)
    p = sub.add_parser("coverage")
    p.add_argument("--root", default=str(xa.ROOT))
    p.add_argument("--output")
    p.add_argument("--json")
    p.add_argument("--check", action="store_true")
    p.set_defaults(func=cmd_coverage)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
