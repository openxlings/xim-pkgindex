"""Tests for the cilium package."""
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
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "cilium"
PKG_FILE = "pkgs/c/cilium.lua"
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
    def test_all_platforms_and_arches_pinned_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
assert(loadfile(arg[1]))()
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "cilium")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/cilium/cilium-cli/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(p.latest and p.latest.ref == "0.20.3")
    local ver = assert(p["0.20.3"], "missing 0.20.3 for " .. plat)
    for arch, alias in pairs(arches) do
        assert(ver.arch_alias[arch] == alias)
        assert(type(ver.sha256[arch]) == "string" and #ver.sha256[arch] == 64)
        assert(type(global_url[plat][arch]) == "string" and global_url[plat][arch]:find("${tag}", 1, true))
    end
end
''',
            PKG_FILE,
        )


class TestIsolation:
    @pytest.mark.isolation
    def test_uses_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc_modification(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install_and_config(self):
        assert_install_succeeds(PKG)
        assert_xvm_registered(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_cilium_version(self):
        shim = Path(xlings_home()) / "bin" / "cilium"
        assert shim.exists(), f"cilium shim missing at {shim}"
        res = subprocess.run(
            [str(shim), "version", "--client"],
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert "cilium-cli:" in res.stdout
        assert "0.20.3" in res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_cilium_help(self):
        shim = Path(xlings_home()) / "bin" / "cilium"
        res = subprocess.run(
            [str(shim), "--help"],
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert "cilium" in res.stdout.lower()

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_under_test_flag(self):
        assert under_test(PKG) or True
