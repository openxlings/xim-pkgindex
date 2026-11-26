"""Tests for the packer package (`packer` CLI)."""
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "packer"
PKG_FILE = "pkgs/p/packer.lua"


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

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_all_platforms_and_arches_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["packer"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "packer")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)

local expected_arches = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}

for plat, arches in pairs(expected_arches) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "1.16.3")
    local ver = assert(section["1.16.3"], "missing 1.16.3 in " .. plat)
    assert(ver.sha256)
    for _, arch in ipairs(arches) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_no_anti_patterns(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    @skip_if_not("linux")
    def test_install_and_run_packer(self):
        assert_xim_add_succeeds(PKG_FILE)
        assert_install_succeeds(PKG)
        assert_xvm_registered("packer")

        shim = xlings_home() / "bin" / "packer"
        assert shim.is_file() or shim.is_symlink(), f"missing shim at {shim}"

        res = subprocess.run(
            [str(shim), "version"],
            text=True,
            capture_output=True,
            timeout=15,
            check=True,
        )
        assert "1.16.3" in res.stdout
