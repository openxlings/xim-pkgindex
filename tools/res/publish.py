#!/usr/bin/env python3
"""Publish res-build artifacts to xlings-res GitHub releases.

    tools/res/publish.py <artifacts-dir>        # dry run: what it would do
    tools/res/publish.py <artifacts-dir> --execute

<artifacts-dir> holds `gh run download` output: one directory per artifact,
named res-<what>-<version>-<arch>, each with a payload and its .sha256.

A release is immutable: an asset is added when its release lacks it, never
replaced. An asset of the same name already published is compared by digest
and, when it differs (a rebuild of something published), the published one is
kept and said so. The GitCode mirror is filled from a CN machine with gtc and
verified by content (GitHub runners stall on GitCode's object storage).
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import xpkg_ci  # noqa: E402  (ensure_mirror_repos: both repos, idempotently)

# What tools/res/build.sh calls a resource, where its releases live.
PACKAGE = {"kernel-virt": "linux-kernel-virt"}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def gh(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["gh", *args], text=True, capture_output=True)


def main() -> int:
    root = Path(sys.argv[1])
    execute = "--execute" in sys.argv
    plan = []
    for art in sorted(p for p in root.iterdir() if p.is_dir() and p.name.startswith("res-")):
        payloads = [f for f in art.iterdir() if f.is_file() and not f.name.endswith(".sha256")]
        if len(payloads) != 1:
            print(f"::error::{art.name}: expected one payload, found {[p.name for p in payloads]}")
            return 1
        payload = payloads[0]
        sidecar = payload.with_name(payload.name + ".sha256")
        digest = sha256(payload)
        if not sidecar.is_file() or sidecar.read_text().split()[0] != digest:
            print(f"::error::{payload.name}: its .sha256 does not match its bytes")
            return 1
        stem = art.name[len("res-"):]
        what_version, arch = stem.rsplit("-", 1)
        # <what>-<version>: the version starts at the first dash before a digit.
        i = next(i for i, c in enumerate(what_version) if c == "-" and what_version[i + 1:i + 2].isdigit())
        what = what_version[:i]
        version = what_version[len(what) + 1:]
        package = PACKAGE.get(what, what)
        plan.append({"package": package, "tag": version, "arch": arch, "file": str(payload),
                     "sidecar": str(sidecar), "sha256": digest})

    results = []
    for item in plan:
        repo = f"xlings-res/{item['package']}"
        name = Path(item["file"]).name
        view = gh("release", "view", item["tag"], "--repo", repo, "--json", "assets")
        existing = {}
        if view.returncode == 0:
            existing = {a["name"]: (a.get("digest") or "").removeprefix("sha256:")
                        for a in json.loads(view.stdout).get("assets", [])}
        if name in existing:
            same = existing[name] == item["sha256"]
            results.append({**item, "action": "published" if same else "kept-published",
                            "published_sha256": existing[name]})
            continue
        action = "create-release" if view.returncode != 0 else "upload"
        results.append({**item, "action": action})
        if not execute:
            continue
        problem = xpkg_ci.ensure_mirror_repos(item["package"], repo, repo)
        if problem:
            print(f"::error::{problem}")
            return 1
        if action == "create-release":
            r = gh("release", "create", item["tag"], "--repo", repo, "--title", item["tag"],
                   "--notes", f"{item['package']} {item['tag']}, built by xim-pkgindex tools/res/build.sh "
                              f"(provenance inside each payload).", item["file"], item["sidecar"])
            if r.returncode != 0 and "already exists" in r.stderr:
                r = gh("release", "upload", item["tag"], "--repo", repo, item["file"], item["sidecar"])
        else:
            r = gh("release", "upload", item["tag"], "--repo", repo, item["file"], item["sidecar"])
        if r.returncode != 0:
            print(f"::error::{repo}@{item['tag']} {name}: {r.stderr.strip()}")
            return 1
    for r in results:
        print(f"{r['action']:<15} {r['package']:<16} {r['tag']:<22} {Path(r['file']).name}  {r['sha256']}")
    Path(root / "published.json").write_text(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
