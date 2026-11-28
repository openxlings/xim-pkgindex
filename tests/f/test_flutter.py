"""flutter"""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "flutter"
PKG_FILE = "pkgs/f/flutter.lua"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_all_platforms_and_sha256_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local expected = {
    linux = {"x86_64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref)
    local v = assert(p[ref], "missing version " .. ref .. " on " .. plat)
    for _, arch in ipairs(arches) do
        local r = assert(v[arch], "missing " .. plat .. "/" .. arch)
        assert(type(r.url) == "string" and r.url:find("flutter_.*3%.50%.1%-stable", 1, false))
        assert(type(r.sha256) == "string" and #r.sha256 == 64 and r.sha256:match("^%x+$"))
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_and_config_bat_vs_posix(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local present = {}
local adds, rms = {}, {}
pkginfo = {
    install_dir = function() return "/pkg" end,
    version = function() return "3.50.1" end,
}
os.isfile = function(p) return present[p] == true end
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
present["/pkg/bin/flutter"] = true
assert(not installed())
present["/pkg/bin/dart"] = true
assert(installed())
assert(config())
assert(adds[1][1] == "flutter" and adds[1][2].filename == nil)
assert(adds[2][1] == "dart" and adds[2][2].binding == "flutter@3.50.1")

present = { ["/pkg/bin/flutter.bat"] = true, ["/pkg/bin/dart.bat"] = true }
adds = {}
assert(installed())
assert(config())
assert(adds[1][1] == "flutter" and adds[1][2].filename == "flutter.bat")
assert(adds[2][1] == "dart" and adds[2][2].filename == "dart.bat")

assert(uninstall())
assert(#rms == 2 and rms[1] == "dart" and rms[2] == "flutter")
''', PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_lua_and_libxpkg_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
            "xim.libxpkg.system", "xim.libxpkg.xvm",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_dart_version(self):
        assert_command_output("dart --version", contains="Dart SDK version: 3.14.0")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_flutter_version(self):
        assert_command_output("flutter --version --suppress-analytics", contains="Flutter 3.50.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("flutter")
        assert_xvm_registered("dart")
