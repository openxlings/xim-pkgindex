"""Tests for the direnv package."""
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
    assert_platform_supported,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not

PKG = "direnv"
PKG_FILE = "pkgs/d/direnv.lua"
VERSION = "2.38.2"
REPO_ROOT = Path(__file__).resolve().parents[2]


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
        cwd=REPO_ROOT,
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
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_uses_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.static
    def test_no_forbidden_patterns(self):
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.static
    def test_resource_architecture_mapping_and_autoupdate(self):
        _run_lua(
            r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "direnv")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/direnv/direnv/releases")
local global = assert(au.resources and au.resources.GLOBAL, "missing GLOBAL autoupdate resource")
assert(global.required == true)
assert(global.url.linux.x86_64 and global.url.linux.aarch64)
assert(global.url.macosx.x86_64 and global.url.macosx.aarch64)
assert(not global.url.windows, "direnv should not declare windows autoupdate")
''',
            PKG_FILE,
        )


@pytest.mark.lifecycle
class TestLifecycle:
    @skip_if_not("linux")
    def test_install_and_run_direnv(self):
        assert_xim_add_succeeds(PKG_FILE)
        assert_install_succeeds(PKG)
        assert_xvm_registered(PKG)
        assert_xvm_shim_exists(PKG)
        assert_command_output("direnv version", VERSION)
