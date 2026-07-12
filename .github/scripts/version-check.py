#!/usr/bin/env python3
"""Upstream version checker (and optional bumper) for xim-pkgindex.

Scans `pkgs/**/*.lua` for explicit `package.ci.update = true` opt-in and a
legacy per-platform marker inside the `xpm` table — either `url_template`
 (hardcoded url+sha256 packages) or `res_versioned = true` (XLINGS_RES
packages, e.g. xlings itself). For each
opted-in package, queries the GitHub Releases API for the latest tag,
compares against the version recorded in `xpm.<plat>.["latest"].ref`, and
prints a JSON report of every package whose upstream has moved ahead.

In `--apply` mode the script additionally downloads each new artifact,
computes its sha256, and rewrites the lua file in-place: a new
`["<upstream>"] = { url = ..., sha256 = ... }` block is **appended**
right after `["latest"]` on every opted-in platform, and `["latest"].ref`
is bumped to point at it. Existing version blocks are left intact (so
pinned consumers keep working). The companion workflow
`version-bump.yml` then commits each modified file to its own branch
and opens a PR.

See docs/spec/url-template.md for the contract this script consumes.

Usage
-----

    # Phase 1: dry-run (default) — JSON report on stdout, no file changes
    python3 .github/scripts/version-check.py [--workspace <path>]

    # Phase 2: apply — modify lua files in place
    python3 .github/scripts/version-check.py --apply [--only <pkg>]

`--only <pkg>` restricts both the scan and the bump to a single package
identified by its lua file basename (e.g. `zoxide`).

Exit code is 0 on a clean run regardless of whether updates were found;
non-zero only on operational errors.
"""

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


# Match every "<word> = { ... }" block at top-level of `xpm = { ... }`,
# where <word> is a platform name. Naive but enough for the limited set
# of well-formed lua files this repo contains.
_PLATFORM_KEYS = ("linux", "macosx", "windows")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def find_xpm_block(lua: str) -> str | None:
    """Return the body of the `xpm = { ... }` table, or None if absent."""
    m = re.search(r"\bxpm\s*=\s*\{", lua)
    if not m:
        return None
    start = m.end()
    depth = 1
    i = start
    while i < len(lua) and depth > 0:
        c = lua[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    if depth != 0:
        return None
    return lua[start : i - 1]


def find_platform_block(xpm_body: str, platform: str) -> str | None:
    """Return the body of `<platform> = { ... }` from inside xpm."""
    m = re.search(rf"\b{re.escape(platform)}\s*=\s*\{{", xpm_body)
    if not m:
        return None
    start = m.end()
    depth = 1
    i = start
    while i < len(xpm_body) and depth > 0:
        c = xpm_body[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    if depth != 0:
        return None
    return xpm_body[start : i - 1]


def extract_url_template(platform_body: str) -> str | None:
    m = re.search(r'\burl_template\s*=\s*"([^"]+)"', platform_body)
    return m.group(1) if m else None


def extract_source_template(xpm_body: str, platform_body: str) -> str | None:
    """Read a URL-template source at platform or xpm scope.

    `source = "xlings-res"` is a runtime resource selector and is not an
    update template.  Only templates containing ${version} participate in
    upstream release discovery.
    """
    for body in (platform_body, xpm_body):
        m = re.search(r'\bsource\s*=\s*"([^"\n]+)"', body)
        if m and "${version}" in m.group(1):
            return m.group(1)
    return None


def expand_version_template(template: str, version: str) -> str:
    return template.replace("${version}", version).replace("{version}", version)


def extract_res_versioned(platform_body: str) -> bool:
    """True if the platform opts into XLINGS_RES-style auto-bump.

    Marked with `res_versioned = true`. Such a platform tracks its `repo`'s
    latest GitHub release just like `url_template`. Apply mode accepts a new
    version only after the mirrored xlings-res release contains a binary and
    matching sha256 sidecar for every opted-in platform resource.
    """
    return re.search(r'\bres_versioned\s*=\s*true\b', platform_body) is not None


def extract_ci_update(lua: str) -> bool:
    """Return package.ci.update, defaulting to false.

    CI metadata is deliberately package-scoped and opt-in.  A permissive
    parser is used here because package files are Lua, while the existing
    checker remains intentionally dependency-free in CI.
    """
    m = re.search(r'\bci\s*=\s*\{', lua)
    if not m:
        return False
    start = m.end()
    depth = 1
    i = start
    while i < len(lua) and depth > 0:
        if lua[i] == "{":
            depth += 1
        elif lua[i] == "}":
            depth -= 1
        i += 1
    body = lua[start : i - 1] if depth == 0 else ""
    return re.search(r'\bupdate\s*=\s*true\b', body) is not None


def extract_latest_ref(platform_body: str) -> str | None:
    m = re.search(
        r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"',
        platform_body,
    )
    return m.group(1) if m else None


def extract_field(lua: str, name: str) -> str | None:
    m = re.search(rf'\b{re.escape(name)}\s*=\s*"([^"]+)"', lua)
    return m.group(1) if m else None


def parse_github_repo(repo_url: str) -> tuple[str, str] | None:
    m = re.match(r"https?://github\.com/([\w.-]+)/([\w.-]+?)(?:\.git)?/?$", repo_url)
    return (m.group(1), m.group(2)) if m else None


def github_latest_release(owner: str, name: str, token: str | None) -> dict[str, Any]:
    url = f"https://api.github.com/repos/{owner}/{name}/releases/latest"
    req = urllib.request.Request(url, headers={"User-Agent": "xim-pkgindex-version-check"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def normalize_version(tag: str) -> str:
    return tag[1:] if tag.startswith("v") else tag


def load_ci_policy(workspace: Path) -> dict[str, Any]:
    """Read the dependency-free central .github/xpkg-ci.yml policy."""
    path = workspace / ".github" / "xpkg-ci.yml"
    policy: dict[str, Any] = {"enabled": True, "interval": "3d", "max_packages_per_run": 50, "request_budget": 500}
    if not path.is_file():
        return policy
    text = path.read_text(encoding="utf-8")
    for key in ("enabled",):
        m = re.search(rf"^\s+{key}:\s*(true|false)\s*$", text, re.MULTILINE)
        if m:
            policy[key] = m.group(1) == "true"
    for key in ("interval", "wakeup_cron"):
        m = re.search(rf"^\s+{key}:\s*([^#\n]+?)\s*$", text, re.MULTILINE)
        if m:
            policy[key] = m.group(1).strip().strip('"')
    for key in ("max_packages_per_run", "request_budget"):
        m = re.search(rf"^\s+{key}:\s*(\d+)\s*$", text, re.MULTILINE)
        if m:
            policy[key] = int(m.group(1))
    if not re.fullmatch(r"[1-9][0-9]*d", str(policy["interval"])):
        raise ValueError(".github/xpkg-ci.yml update.interval must be a positive duration such as 3d")
    return policy


def check_package(lua_path: Path, token: str | None) -> dict[str, Any] | None:
    """Return a JSON-serializable record for this package, or None to skip.

    Status values:
      "skip"          — opt-out (no url_template anywhere)
      "skip-no-repo"  — repo missing or not on GitHub
      "skip-bad-template" — template missing the {version} placeholder
      "up-to-date"    — opted in, upstream version matches current latest
      "update-available" — opted in, upstream is ahead of current latest
      "error"         — any operational failure (network, HTTP, parse)
    """
    text = read_text(lua_path)
    if not extract_ci_update(text):
        return None
    xpm = find_xpm_block(text)
    if not xpm:
        return None

    platforms: dict[str, dict[str, Any]] = {}
    for plat in _PLATFORM_KEYS:
        body = find_platform_block(xpm, plat)
        if not body:
            continue
        tmpl = extract_url_template(body) or extract_source_template(xpm, body)
        res = extract_res_versioned(body)
        ref = extract_latest_ref(body)
        if tmpl or res or ref:
            platforms[plat] = {"url_template": tmpl, "res_versioned": res, "ref": ref}

    # Opt-in is either url_template (hardcoded url+sha256 mode) or
    # res_versioned (XLINGS_RES mode). A platform that sets neither is
    # manually maintained and skipped.
    if not any(p.get("url_template") or p.get("res_versioned")
               for p in platforms.values()):
        return None

    # Validate each opted-in template has the placeholder.
    for plat, info in platforms.items():
        if info.get("url_template") and "{version}" not in info["url_template"]:
            return {
                "pkg": lua_path.stem,
                "path": str(lua_path),
                "status": "skip-bad-template",
                "reason": f"{plat}.url_template does not contain {{version}}",
            }

    # All opted-in platforms must agree on the current version.
    current_versions = {
        plat: info["ref"]
        for plat, info in platforms.items()
        if (info.get("url_template") or info.get("res_versioned")) and info.get("ref")
    }
    if len(set(current_versions.values())) != 1:
        return {
            "pkg": lua_path.stem,
            "path": str(lua_path),
            "status": "skip-bad-template",
            "reason": f"per-platform 'latest' refs disagree: {current_versions}",
        }
    current = next(iter(current_versions.values()))

    repo_url = extract_field(text, "repo")
    if not repo_url:
        return {
            "pkg": lua_path.stem,
            "path": str(lua_path),
            "status": "skip-no-repo",
            "reason": "package.repo missing",
        }
    parsed = parse_github_repo(repo_url)
    if not parsed:
        return {
            "pkg": lua_path.stem,
            "path": str(lua_path),
            "status": "skip-no-repo",
            "reason": f"package.repo is not a GitHub URL ({repo_url})",
        }

    owner, name = parsed
    try:
        rel = github_latest_release(owner, name, token)
    except urllib.error.HTTPError as e:
        return {
            "pkg": lua_path.stem,
            "path": str(lua_path),
            "status": "error",
            "reason": f"GitHub HTTP {e.code}: {e.reason}",
        }
    except (urllib.error.URLError, TimeoutError) as e:
        return {
            "pkg": lua_path.stem,
            "path": str(lua_path),
            "status": "error",
            "reason": f"network error: {e}",
        }

    tag = rel.get("tag_name", "")
    if not tag:
        return {
            "pkg": lua_path.stem,
            "path": str(lua_path),
            "status": "error",
            "reason": "GitHub release has no tag_name",
        }
    upstream = normalize_version(tag)

    record: dict[str, Any] = {
        "pkg": lua_path.stem,
        "path": str(lua_path),
        "repo": f"{owner}/{name}",
        "tag": tag,
        "current": current,
        "upstream": upstream,
    }

    if upstream == current:
        record["status"] = "up-to-date"
        return record

    record["status"] = "update-available"
    proposed: dict[str, str] = {}
    res_platforms: list[str] = []
    for plat, info in platforms.items():
        if info.get("url_template"):
            proposed[plat] = expand_version_template(info["url_template"], upstream)
        elif info.get("res_versioned"):
            res_platforms.append(plat)
    record["proposed_urls"] = proposed
    record["proposed_res"] = res_platforms
    return record


def find_block_range(text: str, key: str, search_from: int = 0) -> tuple[int, int] | None:
    """Return the (body_start, body_end) offset range of `<key> = { ... }`.

    body_start is just past the opening `{`; body_end is the index of the
    matching closing `}` (exclusive of it). Returns None if not found or
    if braces are unbalanced.
    """
    m = re.search(rf"\b{re.escape(key)}\s*=\s*\{{", text[search_from:])
    if not m:
        return None
    body_start = search_from + m.end()
    depth = 1
    i = body_start
    while i < len(text) and depth > 0:
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    if depth != 0:
        return None
    return (body_start, i - 1)


def compute_sha256(url: str, token: str | None) -> str:
    """Stream the URL and return its sha256 hex digest."""
    h = hashlib.sha256()
    req = urllib.request.Request(
        url, headers={"User-Agent": "xim-pkgindex-version-bump"}
    )
    # Auth header is harmless for public release artifacts but lifts rate
    # limits when GitHub returns a redirect through api.github.com.
    if token and "github.com" in url:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=180) as resp:
        while True:
            chunk = resp.read(64 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def fetch_text(url: str, token: str | None) -> str:
    req = urllib.request.Request(
        url, headers={"User-Agent": "xim-pkgindex-version-bump"}
    )
    if token and "github.com" in url:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def github_release_by_tag(owner: str, name: str, tag: str,
                          token: str | None) -> dict[str, Any]:
    url = f"https://api.github.com/repos/{owner}/{name}/releases/tags/{tag}"
    req = urllib.request.Request(
        url, headers={"User-Agent": "xim-pkgindex-version-bump"}
    )
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def canonical_arch(arch: str) -> str:
    value = arch.lower().replace("-", "_")
    if value in {"amd64", "x64", "x86_64"}:
        return "x86_64"
    if value in {"arm64", "armv8", "aarch64"}:
        return "aarch64"
    return value


def release_arches(package_name: str, version: str, platform: str,
                   assets: dict[str, str]) -> set[str]:
    prefix = f"{package_name}-{version}-{platform}-"
    result = set()
    for name in assets:
        if (not name.startswith(prefix)
                or name.endswith(".sha256")
                or not (name.endswith(".tar.gz") or name.endswith(".zip"))):
            continue
        suffix = name[len(prefix):]
        result.add(canonical_arch(
            suffix.removesuffix(".tar.gz").removesuffix(".zip")))
    return result


def resolve_res_hashes(package_name: str, current: str, version: str,
                       platforms: list[str], token: str | None) -> dict[str, Any]:
    """Verify xlings-res release assets and return platform->arch->sha256.

    The sidecar supplies the expected digest; the binary is streamed and
    hashed independently. Missing platform assets, sidecars, malformed
    digests, or mismatches abort the entire version bump.
    """
    try:
        current_release = github_release_by_tag(
            "xlings-res", package_name, current, token)
        release = github_release_by_tag("xlings-res", package_name, version, token)
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
        return {"status": "error", "reason": f"resource release unavailable: {e}"}

    assets = {
        item.get("name", ""): item.get("browser_download_url", "")
        for item in release.get("assets", [])
        if item.get("name") and item.get("browser_download_url")
    }
    current_assets = {
        item.get("name", ""): item.get("browser_download_url", "")
        for item in current_release.get("assets", [])
        if item.get("name") and item.get("browser_download_url")
    }
    result: dict[str, dict[str, str]] = {}
    for platform in platforms:
        expected_arches = release_arches(
            package_name, current, platform, current_assets)
        actual_arches = release_arches(package_name, version, platform, assets)
        if not expected_arches:
            return {
                "status": "error",
                "reason": f"current release has no resource asset for {platform}",
            }
        if actual_arches != expected_arches:
            return {
                "status": "error",
                "reason": (
                    f"architecture set changed for {platform}: "
                    f"{sorted(expected_arches)} -> {sorted(actual_arches)}"
                ),
            }
        prefix = f"{package_name}-{version}-{platform}-"
        binaries = [
            name for name in assets
            if name.startswith(prefix)
            and (name.endswith(".tar.gz") or name.endswith(".zip"))
            and not name.endswith(".sha256")
        ]
        if not binaries:
            return {"status": "error", "reason": f"no resource asset for {platform}"}
        hashes: dict[str, str] = {}
        for filename in sorted(binaries):
            suffix = filename[len(prefix):]
            arch = suffix.removesuffix(".tar.gz").removesuffix(".zip")
            arch = canonical_arch(arch)
            sidecar = filename + ".sha256"
            if sidecar not in assets:
                return {"status": "error", "reason": f"missing sidecar: {sidecar}"}
            try:
                sidecar_text = fetch_text(assets[sidecar], token).strip()
                match = re.fullmatch(r"([0-9a-fA-F]{64})\s+\*?(.+)", sidecar_text)
                if not match or match.group(2) != filename:
                    return {"status": "error", "reason": f"invalid sidecar: {sidecar}"}
                expected = match.group(1).lower()
                actual = compute_sha256(assets[filename], token)
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
                return {"status": "error", "reason": f"failed to verify {filename}: {e}"}
            if actual != expected:
                return {
                    "status": "error",
                    "reason": f"sha256 mismatch for {filename}: got {actual}, want {expected}",
                }
            hashes[arch] = expected
        result[platform] = hashes
    return result


def apply_bump(
    lua_path: Path,
    current: str,
    upstream: str,
    proposed_urls: dict[str, str],
    token: str | None,
    res_platforms: list[str] | None = None,
) -> dict[str, Any]:
    """Edit lua_path in place: append a new `["<upstream>"]` entry per
    platform and bump `["latest"].ref` from <current> to <upstream>.
    Existing version entries are untouched.

    Two entry shapes, per platform:
      - url_template platforms (in `proposed_urls`): the artifact is
        downloaded, its sha256 computed, and a
        `["<upstream>"] = { url = ..., sha256 = ... }` block appended.
      - res_versioned platforms (in `res_platforms`): mirrored binaries and
        sidecars are verified first, then a V1-compatible `url = "XLINGS_RES"`
        resource table with per-arch sha256 values is appended.

    Returns a record describing what happened (status + per-platform).
    """
    res_platforms = res_platforms or []
    text = lua_path.read_text(encoding="utf-8")

    # Locate xpm block once so per-platform searches stay scoped to it.
    xpm = find_block_range(text, "xpm")
    if not xpm:
        return {"status": "error", "reason": "xpm block not found"}

    edits: list[tuple[int, int, str]] = []
    per_platform: dict[str, Any] = {}

    res_hashes: dict[str, Any] = {}
    if res_platforms:
        res_hashes = resolve_res_hashes(
            lua_path.stem, current, upstream, res_platforms, token)
        if res_hashes.get("status") == "error":
            return res_hashes
    for plat, new_url in proposed_urls.items():
        plat_range = find_block_range(text, plat, xpm[0])
        if not plat_range or plat_range[1] > xpm[1]:
            continue
        plat_body = text[plat_range[0] : plat_range[1]]

        # Capture the leading whitespace of the `["latest"]` line so the
        # new version block we append matches the existing indentation.
        latest_pat = re.compile(
            r'(?m)^(?P<indent>[ \t]*)\["latest"\]\s*=\s*\{\s*ref\s*=\s*"'
            + re.escape(current)
            + r'"\s*\}\s*,?[ \t]*\n'
        )
        m = latest_pat.search(plat_body)
        if not m:
            # Either ref doesn't match expected current (already bumped?)
            # or the block is shaped differently. Skip this platform.
            continue
        indent = m.group("indent")

        try:
            sha = compute_sha256(new_url, token)
        except (urllib.error.URLError, TimeoutError) as e:
            return {
                "status": "error",
                "reason": f"failed to download {new_url}: {e}",
            }

        # Build the replacement: keep the latest line (with bumped ref)
        # and immediately follow it with the new version block.
        replacement = (
            f'{indent}["latest"] = {{ ref = "{upstream}" }},\n'
            f'{indent}["{upstream}"] = {{\n'
            f'{indent}    url = "{new_url}",\n'
            f'{indent}    sha256 = "{sha}",\n'
            f'{indent}}},\n'
        )

        edits.append(
            (
                plat_range[0] + m.start(),
                plat_range[0] + m.end(),
                replacement,
            )
        )
        per_platform[plat] = sha

    # XLINGS_RES platforms: retain the sentinel URL for V1 readers while
    # supplying architecture hashes to V2/current readers.
    for plat in res_platforms:
        plat_range = find_block_range(text, plat, xpm[0])
        if not plat_range or plat_range[1] > xpm[1]:
            continue
        plat_body = text[plat_range[0] : plat_range[1]]
        latest_pat = re.compile(
            r'(?m)^(?P<indent>[ \t]*)\["latest"\]\s*=\s*\{\s*ref\s*=\s*"'
            + re.escape(current)
            + r'"\s*\}\s*,?[ \t]*\n'
        )
        m = latest_pat.search(plat_body)
        if not m:
            continue
        indent = m.group("indent")
        hashes = res_hashes.get(plat, {})
        if not hashes:
            return {"status": "error", "reason": f"no verified hashes for {plat}"}
        hash_lines = "".join(
            f'{indent}        {arch} = "{digest}",\n'
            for arch, digest in sorted(hashes.items())
        )
        replacement = (
            f'{indent}["latest"] = {{ ref = "{upstream}" }},\n'
            f'{indent}["{upstream}"] = {{\n'
            f'{indent}    url = "XLINGS_RES",\n'
            f'{indent}    sha256 = {{\n'
            f'{hash_lines}'
            f'{indent}    }},\n'
            f'{indent}}},\n'
        )
        edits.append(
            (plat_range[0] + m.start(), plat_range[0] + m.end(), replacement)
        )
        per_platform[plat] = hashes

    if not edits:
        return {"status": "no-edit", "reason": "no matching latest line on any platform"}

    # Apply edits from the end of the file backward so earlier offsets
    # stay valid.
    new_text = text
    for start, end, repl in sorted(edits, key=lambda e: -e[0]):
        new_text = new_text[:start] + repl + new_text[end:]

    lua_path.write_text(new_text, encoding="utf-8")
    return {"status": "applied", "platforms": per_platform}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--workspace",
        default=os.environ.get("GITHUB_WORKSPACE") or ".",
        help="Repo root (defaults to GITHUB_WORKSPACE or '.').",
    )
    ap.add_argument(
        "--token",
        default=os.environ.get("GITHUB_TOKEN"),
        help="GitHub API token (for rate-limit headroom). "
        "Falls back to $GITHUB_TOKEN.",
    )
    ap.add_argument(
        "--apply",
        action="store_true",
        help="Modify lua files in place: append a new version block and "
        "bump ['latest'].ref for every package whose upstream is ahead. "
        "Without this flag the script is dry-run only.",
    )
    ap.add_argument(
        "--only",
        default=None,
        help="Restrict scanning (and bumping) to a single package by lua "
        "basename (e.g. 'zoxide' for pkgs/z/zoxide.lua).",
    )
    args = ap.parse_args()

    pkg_dir = Path(args.workspace) / "pkgs"
    if not pkg_dir.is_dir():
        print(f"error: {pkg_dir} not found", file=sys.stderr)
        return 2
    try:
        policy = load_ci_policy(Path(args.workspace))
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    if not policy.get("enabled", True):
        print(json.dumps({"policy": policy, "summary": {}, "packages": []}, indent=2))
        return 0

    records: list[dict[str, Any]] = []
    skipped = 0
    for lua in sorted(pkg_dir.glob("*/*.lua")):
        if args.only and lua.stem != args.only:
            continue
        rec = check_package(lua, args.token)
        if rec is None:
            skipped += 1
            continue
        records.append(rec)

    if args.apply:
        for rec in records:
            if rec["status"] != "update-available":
                continue
            applied = apply_bump(
                Path(rec["path"]),
                rec["current"],
                rec["upstream"],
                rec["proposed_urls"],
                args.token,
                rec.get("proposed_res", []),
            )
            rec["apply"] = applied

    summary = {
        "scanned": len(records) + skipped,
        "skipped_manual": skipped,
        "checked": len(records),
        "update_available": sum(1 for r in records if r["status"] == "update-available"),
        "up_to_date": sum(1 for r in records if r["status"] == "up-to-date"),
        "errors": sum(1 for r in records if r["status"] in ("error", "skip-no-repo", "skip-bad-template")),
        "applied": sum(
            1
            for r in records
            if r.get("apply", {}).get("status") == "applied"
        ),
    }
    out = {"policy": policy, "summary": summary, "packages": records}
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
