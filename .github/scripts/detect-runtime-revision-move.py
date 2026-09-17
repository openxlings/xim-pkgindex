#!/usr/bin/env python3
"""Detect a C-runtime revision move between two index trees.

A "runtime revision move" is a package descriptor whose `xpm.<platform>`
branch declares `exports = { runtime = { abi = ... } }` -- the schema
mcpp-community/mcpp reads to bind a toolchain's payload directory (see
libxpkg's ExportsRuntime schema, xpkg.cppm) -- AND whose `["latest"] =
{ ref = ... }` for that platform differs between the two trees.

Detection is by the FIELD, not by the package name: `glibc` is today's only
Linux x86_64 example, but `musl` carries the same shape, and this script
would catch a move in either (or in a future third runtime) the same way.
A package that only declares `exports.runtime.libdirs` (dozens of shared
libraries do, e.g. libXext) does not count -- `abi` is what makes a runtime
package a RuntimeBinding provider rather than an ordinary library with a
private lib directory.

Why this class of change gets its own gate: mcpp-community/mcpp#660. A
consumer's CI cache restores only the xpkgs payload store, not the whole
mcpp home. A fresh install never sees that shape -- it downloads whatever
`latest` says today and never holds a stale toolchain fixup over a payload
directory that used to exist under a different name. Only a build that (1)
resolved the OLD revision once, so a toolchain is patched against it, and
then (2) resolves the NEW revision with the version-tracking state gone but
the old payload directory still on disk, reproduces the incident. See
runtime-revision-gate.yml for the two-leg build this script's answer feeds.

Usage:
    detect-runtime-revision-move.py --repo <path> --base <git-ref> --head <git-ref>
        [--github-output <path>]

Exits 0 always (detection is informational; the caller decides what a
"moved" result means). Prints one line per moved package to stdout and,
with --github-output, appends `moved=true|false` and `packages=<json>`.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lua_table import PLATFORMS, platform_body, declares_runtime_abi, latest_ref  # noqa: E402


def git(args: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True
    )


def show(ref: str, path: str, cwd: Path) -> str | None:
    r = git(["show", f"{ref}:{path}"], cwd)
    return r.stdout if r.returncode == 0 else None


def list_lua_files(ref: str, cwd: Path) -> list[str]:
    r = git(["ls-tree", "-r", "--name-only", ref, "--", "pkgs/"], cwd)
    if r.returncode != 0:
        raise RuntimeError(f"git ls-tree {ref} failed: {r.stderr}")
    return [line for line in r.stdout.splitlines() if line.endswith(".lua")]


def scan(repo: Path, base: str, head: str) -> list[dict]:
    head_files = set(list_lua_files(head, repo))
    base_files = set(list_lua_files(base, repo))
    common = sorted(head_files & base_files)

    moved = []
    for path in common:
        base_src = show(base, path, repo)
        head_src = show(head, path, repo)
        if base_src is None or head_src is None:
            continue
        for platform in PLATFORMS:
            base_plat = platform_body(base_src, platform)
            head_plat = platform_body(head_src, platform)
            if not (declares_runtime_abi(base_plat) or declares_runtime_abi(head_plat)):
                continue
            base_r = latest_ref(base_plat)
            head_r = latest_ref(head_plat)
            if base_r is not None and head_r is not None and base_r != head_r:
                moved.append({
                    "path": path,
                    "platform": platform,
                    "base_ref": base_r,
                    "head_ref": head_r,
                })
    return moved


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", default=".", type=Path)
    ap.add_argument("--base", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--github-output", type=Path, default=None)
    args = ap.parse_args()

    repo = args.repo.resolve()
    moved = scan(repo, args.base, args.head)

    if not moved:
        print("no runtime revision moved")
    else:
        for entry in moved:
            print(
                f"runtime revision moved: {entry['path']} [{entry['platform']}] "
                f"{entry['base_ref']} -> {entry['head_ref']}"
            )

    if args.github_output is not None:
        with open(args.github_output, "a", encoding="utf-8") as f:
            f.write(f"moved={'true' if moved else 'false'}\n")
            f.write(f"packages={json.dumps(moved)}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
