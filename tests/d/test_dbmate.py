"""Tests for the dbmate package."""
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
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "dbmate"
PKG_FILE = "pkgs/d/dbmate.lua"
RELEASE_VERSION = "2.38.2"
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


def _dbmate_bin() -> str:
    suffix = ".exe" if os.name == "nt" else ""
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    candidates = [subos] if subos else ["current", "default"]
    for name in candidates:
        candidate = Path(xlings_home()) / "subos" / name / "bin" / f"dbmate{suffix}"
        if candidate.is_file():
            return str(candidate)
    for ns in ("local", "xim"):
        pkg_dir = Path(xlings_home()) / "data" / "xpkgs" / f"{ns}-x-{PKG}"
        if pkg_dir.is_dir():
            for ver_dir in sorted(pkg_dir.iterdir(), reverse=True):
                candidate = ver_dir / f"dbmate{suffix}"
                if candidate.is_file():
                    return str(candidate)
    found = shutil.which("dbmate")
    assert found, "dbmate binary not found in subos bin, xpkgs, or PATH"
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
        assert meta.programs == ["dbmate"]
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping_and_autoupdate(self):
        _run_lua(
            r'''
function import() end
dofile("pkgs/d/dbmate.lua")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.extensions and package.extensions.autoupdate)

local xpm = package.xpm
assert(xpm.linux.latest.ref == "2.38.2")
assert(xpm.macosx.latest.ref == "2.38.2")
assert(xpm.windows.latest.ref == "2.38.2")

assert(xpm.linux["2.38.2"].arch_alias.x86_64 == "amd64")
assert(xpm.linux["2.38.2"].arch_alias.aarch64 == "arm64")
assert(xpm.macosx["2.38.2"].arch_alias.x86_64 == "amd64")
assert(xpm.macosx["2.38.2"].arch_alias.aarch64 == "arm64")
assert(xpm.windows["2.38.2"].arch_alias.x86_64 == "amd64")
assert(xpm.windows["2.38.2"].arch_alias.aarch64 == nil)
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
        assert_install_succeeds(under_test(PKG, RELEASE_VERSION))


class TestVerify:
    @skip_if_not("linux")
    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            cur_json = Path(xlings_home()) / "subos" / "current" / ".xlings.json"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if cur_json.is_file() else "default")
        assert_xvm_registered(PKG)

    @skip_if_not("linux")
    @pytest.mark.verify
    def test_dbmate_version(self):
        res = subprocess.run(
            [_dbmate_bin(), "--version"],
            text=True,
            capture_output=True,
            check=True,
            timeout=15,
        )
        assert RELEASE_VERSION in res.stdout

    @skip_if_not("linux")
    @pytest.mark.verify
    def test_dbmate_help(self):
        res = subprocess.run(
            [_dbmate_bin(), "--help"],
            text=True,
            capture_output=True,
            check=True,
            timeout=15,
        )
        assert "dbmate" in res.stdout
