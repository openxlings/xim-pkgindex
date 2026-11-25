"""Tests for the kubectl package."""
import json
import os
import shutil
import subprocess

import pytest

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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test
from tests.lib.xpkg_parser import parse_xpkg

PKG = "kubectl"
PKG_FILE = "pkgs/k/kubectl.lua"
RELEASE_VERSION = "1.37.2"


def assert_version_matrix(pkg_file: str):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua is required to inspect package metadata")
    script = "import = function() end; dofile(" + json.dumps(str(pkg_file)) + ")\n" + r'''
local wanted = { x86_64 = "amd64", aarch64 = "arm64" }
local prefixes = { linux = "linux", macosx = "darwin", windows = "windows" }
assert(#package.archs == 2, "expected two architectures")
for _, arch in ipairs(package.archs) do
    assert(wanted[arch], "unexpected architecture: " .. tostring(arch))
end

local auto_urls = package.extensions.autoupdate.resources.GLOBAL.url
local baseline
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    local entries = assert(package.xpm[platform], "missing platform: " .. platform)
    local latest = assert(entries.latest and entries.latest.ref, platform .. " has no latest ref")
    assert(entries[latest], platform .. " latest has no version entry")

    local auto_plat = assert(auto_urls[platform], "autoupdate missing platform: " .. platform)
    for arch, alias in pairs(wanted) do
        local expected_tmpl = "https://dl.k8s.io/release/v${version}/bin/" ..
            prefixes[platform] .. "/" .. alias ..
            (platform == "windows" and "/kubectl.exe" or "/kubectl")
        assert(auto_plat[arch] == expected_tmpl,
               "unexpected autoupdate template for " .. platform .. "/" .. arch)
    end

    local versions = {}
    for version, entry in pairs(entries) do
        if version ~= "latest" then
            versions[version] = true
            for arch, alias in pairs(wanted) do
                local res = assert(entry[arch], platform .. "/" .. version .. "/" .. arch .. " missing")
                assert(type(res.sha256) == "string" and #res.sha256 == 64 and res.sha256:match("^[0-9a-f]+$"),
                       "invalid sha256 for " .. platform .. "/" .. version .. "/" .. arch)
                local expected_url = "https://dl.k8s.io/release/v" .. version .. "/bin/" ..
                    prefixes[platform] .. "/" .. alias ..
                    (platform == "windows" and "/kubectl.exe" or "/kubectl")
                assert(res.url == expected_url,
                       "unexpected URL for " .. platform .. "/" .. version .. "/" .. arch)
                for key in pairs(res) do
                    assert(key == "url" or key == "sha256", "unexpected resource field: " .. tostring(key))
                end
            end
            for arch in pairs(entry) do
                assert(wanted[arch], "unexpected entry architecture: " .. tostring(arch))
            end
        end
    end

    if baseline then
        assert(baseline.latest == latest, "platform latest versions differ")
        for v in pairs(baseline.versions) do assert(versions[v], "missing platform version: " .. v) end
        for v in pairs(versions) do assert(baseline.versions[v], "unexpected platform version: " .. v) end
    else
        baseline = { latest = latest, versions = versions }
    end
end
'''
    result = subprocess.run([lua, "-e", script], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr


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
    def test_package_node(self, meta):
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_programs_and_platforms(self, meta):
        assert meta.programs == ["kubectl"]
        assert set(meta.platforms) == {"linux", "macosx", "windows"}

    @pytest.mark.static
    def test_version_matrix_is_complete(self):
        assert_version_matrix(PKG_FILE)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)


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
    def test_no_direct_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG, RELEASE_VERSION), timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        version = os.environ.get("XLINGS_TEST_VERSION", RELEASE_VERSION)
        result = subprocess.run(
            ["kubectl", "version", "--client"],
            capture_output=True, text=True, timeout=15,
        )
        out = result.stdout + result.stderr
        assert result.returncode == 0, out
        assert f"v{version}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("kubectl")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_shim_exists(self):
        assert_xvm_shim_exists("kubectl")
