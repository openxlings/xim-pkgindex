"""Tests for the syncthing package."""
from pathlib import Path
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
    assert_xvm_registered,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not

PKG = "syncthing"
PKG_FILE = "pkgs/s/syncthing.lua"
VERSION = "2.1.7"
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

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_platforms_arches_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "syncthing")

local auto = assert(package.extensions and package.extensions.autoupdate, "missing autoupdate")
assert(auto.source == "https://github.com/syncthing/syncthing/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(not section.deps, "static binary should not declare deps on " .. plat)
    local version = assert(section.latest and section.latest.ref)
    assert(version == "2.1.7")
    local entry = assert(section[version], "missing version entry on " .. plat)
    assert(entry.arch_alias.x86_64 == "amd64")
    assert(entry.arch_alias.aarch64 == "arm64")
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^[0-9a-f]+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
    end
end
''',
            PKG_FILE,
        )


class TestIsolation:
    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc_modification(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_uses_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install_succeeds(self):
        assert_install_succeeds(PKG)

    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_xvm_shim_exists(self):
        assert_xvm_shim_exists(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version_output(self):
        assert_command_output(["syncthing", "--version"], f"syncthing v{VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_output(self):
        assert_command_output(["syncthing", "--help"], "Usage: syncthing")
