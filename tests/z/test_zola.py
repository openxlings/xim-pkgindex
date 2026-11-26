"""Tests for the zola package."""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_command_output,
    assert_config_registers_package_name,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "zola"
PKG_FILE = "pkgs/z/zola.lua"
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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self):
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "zola")

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == "0.23.6", platform .. " latest should be 0.23.6")
    local entry = assert(p[version], "missing version entry: " .. platform)
    for _, arch in ipairs(arches) do
        local item = assert(entry[arch], platform .. "/" .. arch .. " missing entry")
        assert(type(item.url) == "string" and item.url:match("^https://"),
               platform .. "/" .. arch .. " missing or invalid url")
        local hash = item.sha256
        assert(type(hash) == "string" and #hash == 64 and hash:match("^[0-9a-f]+$"),
               platform .. "/" .. arch .. " missing or invalid sha256")
        count = count + 1
    end
end
assert(count == 5, "expected 5 platform/arch entries, got " .. count)

local au = assert(package.extensions and package.extensions.autoupdate, "missing autoupdate")
local global = assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.url, "missing autoupdate GLOBAL url")
assert(global.linux.x86_64 and global.linux.aarch64)
assert(global.macosx.x86_64 and global.macosx.aarch64)
assert(global.windows.x86_64)
''', PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_uses_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc_modification(self):
        assert_no_bashrc_modification(PKG_FILE)


class TestInstall:
    @pytest.mark.install
    @skip_if_not("linux")
    def test_install_and_verify(self, xlings_home):
        if under_test(PKG):
            assert_install_succeeds(PKG, xlings_home)
        else:
            assert_xim_add_succeeds(PKG_FILE, xlings_home)
        assert_xvm_registered("zola", xlings_home)
        out = assert_command_output(["zola", "--version"], xlings_home)
        assert re.search(r"zola\s+0\.23\.6", out), f"unexpected zola --version output: {out!r}"
