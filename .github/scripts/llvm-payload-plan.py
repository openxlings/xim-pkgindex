#!/usr/bin/env python3
"""The llvm archives the payload check takes, and the host each runs on.

    llvm-payload-plan.py --base <ref> --head <ref> [--github-output <path>]

The archives of the version entries a change touches (ci-plan.py's
`changed_versions`, `latest` aside); when it touches none -- a change to the
check itself -- the newest version's. A version is taken on every host that
pkgs/l/llvm.lua serves it on: Linux x86_64 and aarch64, macOS arm64, Windows
x86_64. What the recipe names for a host is read by loading it in the recipe
sandbox, as the client reads it: the url (GLOBAL) and the sha256, which an
entry the check takes must state. An archive this index makes -- its release
is a resource of .github/res-build-matrix.json -- is built by the same run
(`resources`), and the host's check takes that file, by the same digest.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RECIPE = "pkgs/l/llvm.lua"
HOSTS = [  # platform, arch, runner
    ("linux", "x86_64", "ubuntu-24.04"),
    ("linux", "aarch64", "ubuntu-24.04-arm"),
    ("macosx", "arm64", "macos-latest"),
    ("windows", "x86_64", "windows-latest"),
]
ARCH_KEYS = {"x86_64": ("x86_64",), "aarch64": ("aarch64", "arm64"), "arm64": ("arm64", "aarch64")}
RELEASE = re.compile(r"^https://github\.com/xlings-res/([^/]+)/releases/download/([^/]+)/([^/]+)$")

# Every entry of a platform section, one line each: version, arch (`*` for an
# entry shared by every arch), kind, url, sha256.
ENTRIES = r"""
local sandbox = dofile(arg[1])
local pkg = assert(sandbox.load_recipe(arg[2]))
local section = pkg.xpm and pkg.xpm[arg[3]]
if type(section) ~= "table" then return end
local NOT_VERSIONS = { deps = true, exports = true, source = true, url_template = true,
                       arch_alias = true, res_versioned = true, ref = true }
local function url_of(e)
    if type(e.url) == "table" then return e.url.GLOBAL or "" end
    return e.url or ""
end
for _, version in ipairs(sandbox.sorted_keys(section)) do
    local e = section[version]
    if type(version) == "string" and not NOT_VERSIONS[version] then
        if type(e) == "string" then
            print(version .. "\t*\tstring\t" .. e .. "\t")
        elseif type(e) == "table" and e.ref == nil then
            local shared = true
            for _, arch in ipairs(sandbox.sorted_keys(e)) do
                local a = e[arch]
                if type(a) == "table" and (a.url ~= nil or a.sha256 ~= nil) then
                    shared = false
                    print(version .. "\t" .. arch .. "\ttable\t" .. url_of(a) .. "\t" .. (a.sha256 or ""))
                end
            end
            if shared then
                print(version .. "\t*\ttable\t" .. url_of(e) .. "\t" .. (e.sha256 or ""))
            end
        end
    end
end
"""


def module(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), ROOT / ".github/scripts" / (name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def show(ref: str, path: str) -> str | None:
    r = subprocess.run(["git", "show", f"{ref}:{path}"], cwd=ROOT, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def entries(source: str, platform: str) -> dict[tuple[str, str], tuple[str, str, str]]:
    """(version, arch) -> (kind, url, sha256) for one platform section."""
    lua = next((c for c in ("lua5.4", "lua5.3", "lua") if subprocess.run(
        ["sh", "-c", f"command -v {c}"], capture_output=True).returncode == 0), None)
    if lua is None:
        raise SystemExit("no Lua interpreter: the recipe is read in the recipe sandbox (lua5.4)")
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write(source)
    try:
        r = subprocess.run([lua, "-", str(ROOT / ".github/scripts/recipe-sandbox.lua"), f.name, platform],
                           input=ENTRIES, capture_output=True, text=True)
    finally:
        Path(f.name).unlink()
    if r.returncode != 0:
        raise SystemExit(f"{RECIPE} does not load in the recipe sandbox: {r.stderr.strip()}")
    out = {}
    for line in r.stdout.splitlines():
        version, arch, kind, url, digest = line.split("\t")
        out[(version, arch)] = (kind, url, digest)
    return out


def ordered(version: str) -> tuple:
    return tuple(int(p) if p.isdigit() else -1 for p in re.split(r"[.\-+]", version))


def resources() -> dict[tuple[str, str], str]:
    """(package release repository, tag) -> the res-build artifact that holds it."""
    matrix = json.loads((ROOT / ".github/res-build-matrix.json").read_text())
    return {(e["what"], e["version"]): f"res-{e['what']}-{e['version']}-{e['arch']}" for e in matrix}


def plan(base: str, head: str) -> dict:
    before, after = show(base, RECIPE), show(head, RECIPE)
    if after is None:
        return {"versions": [], "include": [], "resources": []}
    changed = module("ci-plan").changed_versions(before, after)
    sections = {platform: entries(after, platform) for platform in {h[0] for h in HOSTS}}
    served = {version for table in sections.values() for version, _ in table}
    versions = sorted({v for v in (changed or set()) if v in served}, key=ordered)
    if not versions:
        versions = [max(served, key=ordered)]
    made = resources()
    include, builds = [], {}
    for version in versions:
        for platform, arch, runner in HOSTS:
            table = sections[platform]
            row = next((table[(version, key)] for key in (*ARCH_KEYS[arch], "*") if (version, key) in table), None)
            if row is None:
                continue
            kind, url, digest = row
            if kind != "table" or not url or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise SystemExit(f"{RECIPE}: {platform}/{version} ({arch}) names no archive by url and sha256")
            item = {"version": version, "platform": platform, "arch": arch, "runner": runner,
                    "url": url, "sha256": digest, "artifact": "", "file": url.rsplit("/", 1)[-1]}
            m = RELEASE.match(url)
            if m and (m.group(1), m.group(2)) in made:
                item["artifact"] = made[(m.group(1), m.group(2))]
                builds[item["artifact"]] = {"what": m.group(1), "version": m.group(2)}
            include.append(item)
    return {"versions": versions, "include": include, "resources": list(builds.values())}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", required=True)
    ap.add_argument("--head", default="HEAD")
    ap.add_argument("--github-output", type=Path)
    args = ap.parse_args()
    result = plan(args.base, args.head)
    print(json.dumps(result, indent=2))
    if args.github_output:
        with args.github_output.open("a") as f:
            f.write("matrix=" + json.dumps({"include": result["include"]}, separators=(",", ":")) + "\n")
            f.write("resources=" + json.dumps({"include": result["resources"]}, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    main()
