"""Tests for the k0sctl package."""
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
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
)
from tests.lib.platform_utils import skip_if_not, xlings_home

PKG = "k0sctl"
PKG_FILE = "pkgs/k/k0sctl.lua"
RELEASE_VERSION = "0.33.1"
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


def _k0sctl_bin() -> str:
    suffix = ".exe" if os.name == "nt" else ""
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    candidates = [subos] if subos else ["current", "default"]
    for name in candidates:
        candidate = Path(xlings_home()) / "subos" / name / "bin" / f"k0sctl{suffix}"
        if candidate.is_file():
            return str(candidate)
    found = shutil.which("k0sctl")
    assert found, "k0sctl binary not found in subos bin or PATH"
    return found


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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_supported_platforms(self, meta):
        assert meta.programs == ["k0sctl"]
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping_and_autoupdate(self):
        _run_lua(
            r'''
function import() end
dofile("pkgs/k/k0sctl.lua")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.extensions and package.extensions.autoupdate)

local xpm = package.xpm
assert(xpm.linux.latest.ref == "0.33.1")
assert(xpm.macosx.latest.ref == "0.33.1")
assert(xpm.windows.latest.ref == "0.33.1")

assert(xpm.linux["0.33.1"].arch_alias.x86_64 == "amd64")
assert(xpm.linux["0.33.1"].arch_alias.aarch64 == "arm64")
assert(xpm.macosx["0.33.1"].arch_alias.x86_64 == "amd64")
assert(xpm.macosx["0.33.1"].arch_alias.aarch64 == "arm64")
assert(xpm.windows["0.33.1"].arch_alias.x86_64 == "amd64")
assert(xpm.windows["0.33.1"].arch_alias.aarch64 == nil)
'''
        )


class TestIsolation:
    @pytest.mark.isolation
    def test_uses_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc_modification(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @skip_if_not("linux")
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @skip_if_not("linux")
    @pytest.mark.verify
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @skip_if_not("linux")
    @pytest.mark.verify
    def test_k0sctl_version(self):
        res = subprocess.run(
            [_k0sctl_bin(), "version"],
            text=True,
            capture_output=True,
            check=True,
            timeout=15,
        )
        assert RELEASE_VERSION in res.stdout

    @skip_if_not("linux")
    @pytest.mark.verify
    def test_k0sctl_help(self):
        res = subprocess.run(
            [_k0sctl_bin(), "--help"],
            text=True,
            capture_output=True,
            check=True,
            timeout=15,
        )
        assert "k0sctl" in res.stdout
