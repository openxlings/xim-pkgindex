"""Tests for the kopia package (fast and secure open source backup)."""
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_valid_xvm_node_kinds,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager, assert_config_registers_package_name,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "kopia"
PKG_FILE = "pkgs/k/kopia.lua"
VERSION = "0.23.1"
REPO = Path(__file__).resolve().parents[2]


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        check=True,
        cwd=REPO,
    ).stdout


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
        assert meta.spec == "2"

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_platforms_arches_sha256_and_autoupdate(self, meta):
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)
        assert meta.programs == ["kopia"]
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "kopia")

local expected = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
local alias_map = { x86_64 = "x64", aarch64 = "arm64" }

for plat, arches in pairs(expected) do
    local sec = assert(package.xpm[plat], "missing platform " .. plat)
    assert(sec.latest and sec.latest.ref == ver, "latest mismatch on " .. plat)
    assert(sec.deps == nil, "unexpected runtime deps on " .. plat)
    assert(type(sec.source) == "string" and sec.source:find("${version}", 1, true))
    local entry = assert(sec[ver], "missing version " .. ver .. " on " .. plat)
    for _, arch in ipairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias_map[arch],
               "arch_alias mismatch on " .. plat .. "/" .. arch)
        local h = assert(entry.sha256 and entry.sha256[arch],
                         "missing sha256 on " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"),
               "invalid sha256 on " .. plat .. "/" .. arch)
    end
end

local auto = assert(package.extensions and package.extensions.autoupdate, "missing autoupdate")
assert(auto.source == "https://github.com/kopia/kopia/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local urls = assert(auto.resources.GLOBAL.url)
for plat, arches in pairs(expected) do
    assert(urls[plat], "missing autoupdate url for " .. plat)
    for _, arch in ipairs(arches) do
        assert(urls[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
    end
end
''', PKG_FILE, VERSION)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc_modification(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_uses_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)


@skip_if_not("linux")
class TestInstallLinux:
    def test_install_and_verify(self):
        assert_xim_add_succeeds(PKG_FILE)
        assert_install_succeeds(PKG)
        assert_xvm_registered(PKG)
        assert_command_output(
            ["kopia", "--version"],
            expected_pattern=VERSION,
        )
