"""Blender resource selection, isolation and payload completeness."""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)

PKG_FILE = "pkgs/b/blender.lua"


@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(PKG_FILE)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)


@pytest.mark.isolation
def test_isolation():
    assert_no_exec_xvm(PKG_FILE)
    assert_no_bashrc_modification(PKG_FILE)
    assert_no_direct_path_modification(PKG_FILE)
    assert_uses_new_api(PKG_FILE)
    src = Path(PKG_FILE).read_text()
    assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
        "xim.libxpkg.pkginfo", "xim.libxpkg.system", "xim.libxpkg.xvm"}
    assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


@pytest.mark.index
def test_index():
    assert_xim_add_succeeds(PKG_FILE)


def run_lua(script, *args):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


@pytest.mark.static
def test_native_resources():
    run_lua('''
import = function() end
dofile(arg[1])
for _, platform in ipairs({"linux", "windows", "macosx"}) do
    local p = package.xpm[platform]
    local v = assert(p[p.latest.ref])
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local r = v[arch]
        if platform == "linux" and arch == "aarch64" then
            assert(r == nil, "no upstream Linux ARM64 LTS build")
        else
            assert(r and #r.sha256 == 64 and r.sha256:match("^%x+$"))
            local token = arch == "x86_64" and "x64" or "arm64"
            assert(r.url:find(platform == "macosx" and "macos" or platform, 1, true))
            assert(r.url:find(token, 1, true))
        end
    end
end
''', PKG_FILE)


@pytest.mark.static
@pytest.mark.parametrize("files", [
    ["blender", "4.5/scripts/modules/bpy/__init__.py"],
    ["blender.exe", "4.5/scripts/modules/bpy/__init__.py"],
    ["Blender.app/Contents/MacOS/Blender",
     "Blender.app/Contents/Resources/4.5/scripts/modules/bpy/__init__.py"],
])
def test_installed_rejects_incomplete_payload(files):
    run_lua('''
import = function() end
dofile(arg[1])
pkginfo = { install_dir = function() return "/pkg" end }
local present = {}
os.isfile = function(p) return present[p] == true end
assert(not installed())
for i = 2, #arg do present["/pkg/" .. arg[i]] = true end
assert(installed())
for i = 2, #arg do
    local f = "/pkg/" .. arg[i]
    present[f] = nil
    assert(not installed(), "accepted missing " .. f)
    present[f] = true
end
''', PKG_FILE, *files)
