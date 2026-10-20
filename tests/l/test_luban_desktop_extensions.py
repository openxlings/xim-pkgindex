"""What Luban reads of a recipe (xlings design 2026-10-19 §5.4, §8, §13):
`extensions` in registered namespaces and within their rules, the official
desktops' tiers, and the pointer theme every official desktop brings."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
REGISTERED = {"luban"}           # xpkg spec §3.1's registry
DESKTOPS = ["compositor", "labwc", "lxqt", "kde", "xdesk"]

# Loads a recipe the way the catalog does (import() a no-op) and prints its
# package table's extensions and linux deps as JSON.
DUMP = r'''
local function proxy()
    return setmetatable({}, { __index = function() return function() return {} end end })
end
function import(name)
    local short = name:match("[^.]+$") or name
    rawset(_G, short, proxy())
end
is_host = function() return false end
os.arch = os.arch or function() return "x86_64" end
dofile(arg[1])
local function enc(v)
    local t = type(v)
    if t == "table" then
        if #v > 0 or next(v) == nil then
            local out = {}
            for _, x in ipairs(v) do out[#out + 1] = enc(x) end
            return "[" .. table.concat(out, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local out = {}
        for _, k in ipairs(keys) do out[#out + 1] = string.format("%q", tostring(k)) .. ":" .. enc(v[k]) end
        return "{" .. table.concat(out, ",") .. "}"
    elseif t == "string" then return string.format("%q", v)
    elseif t == "number" or t == "boolean" then return tostring(v)
    else return "null" end
end
local linux = package.xpm and package.xpm.linux or {}
print(enc({ extensions = package.extensions or {}, deps = linux.deps or {}, categories = package.categories or {} }))
'''


def load(name):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua interpreter required")
    out = subprocess.run([lua, "-", str(ROOT / "pkgs/luban" / f"{name}.lua")], input=DUMP, capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout.replace("\\\n", "\\n"))


def luban_recipes():
    return sorted(p.stem for p in (ROOT / "pkgs/luban").glob("*.lua"))


@pytest.mark.static
@pytest.mark.parametrize("name", luban_recipes())
def test_extensions_are_registered_and_small(name):
    ext = load(name)["extensions"]
    if not ext:
        return
    assert set(ext) <= REGISTERED, f"{name}: unregistered namespace {set(ext) - REGISTERED}"
    assert len(json.dumps(ext, separators=(",", ":"))) <= 4096, f"{name}: extensions over 4 KiB"
    luban = ext.get("luban", {})
    if "tier" in luban:
        assert luban["tier"] in (1, 2, 3, 4), name
    if "gpu" in luban:
        assert luban["gpu"] in ("better", "needed"), name
    for key in ("title", "summary"):
        if key in luban:
            assert isinstance(luban[key], dict) and luban[key].get("en"), f"{name}: {key} needs English"
    if "highlights" in luban:
        assert isinstance(luban["highlights"], list) and all(isinstance(h, str) for h in luban["highlights"])


@pytest.mark.static
@pytest.mark.parametrize("name", DESKTOPS)
def test_an_official_desktop_says_what_it_is(name):
    meta = load(name)
    assert "luban-desktop" in meta["categories"]
    luban = meta["extensions"].get("luban", {})
    assert luban.get("title", {}).get("en"), name
    if name == "xdesk":
        assert "tier" not in luban, "xdesk is not on the T1-T4 axis"
    else:
        assert luban.get("tier") in (1, 2, 3, 4), name


@pytest.mark.static
@pytest.mark.parametrize("name", DESKTOPS)
def test_every_official_desktop_brings_the_pointer_theme(name):
    """luban:cursors is a dependency of labwc and xdesk; the rest reach it through labwc."""
    seen, todo = set(), [name]
    while todo:
        n = todo.pop()
        if n in seen:
            continue
        seen.add(n)
        path = ROOT / "pkgs/luban" / f"{n}.lua"
        if not path.exists():
            continue
        for dep in load(n)["deps"]:
            dep = dep.split("@")[0]
            ns, _, short = dep.rpartition(":")
            if ns in ("", "luban"):
                todo.append(short)
    assert "cursors" in seen, f"{name} does not bring luban:cursors"
