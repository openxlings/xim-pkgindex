"""Tests for the oh-my-pi package."""
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_command_output,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
)
from tests.lib.platform_utils import skip_if_not
from tests.lib.xpkg_parser import parse_xpkg

PKG = "oh-my-pi"
PKG_FILE = "pkgs/o/oh-my-pi.lua"
RELEASE_VERSION = "18.5.0"


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
    def test_all_requested_platforms(self, meta):
        assert set(meta.platforms) == {"linux", "macosx", "windows"}

    @pytest.mark.static
    def test_version_matrix_is_complete(self):
        lua = shutil.which("lua") or shutil.which("lua5.4")
        if not lua:
            pytest.skip("Lua is required to inspect package metadata")
        script = f'import = function() end; dofile("{PKG_FILE}")\n' + r'''
local wanted = { x86_64 = "x64", aarch64 = "arm64" }
assert(#package.archs == 2, "expected two architectures")
for _, arch in ipairs(package.archs) do assert(wanted[arch], "unexpected architecture") end
local baseline
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    local entries = assert(package.xpm[platform], platform)
    assert(entries.source:find("${version}", 1, true) and
           entries.source:find("${arch_alias}", 1, true), "source cannot resolve both architectures")
    local latest = assert(entries.latest.ref, platform .. " has no latest")
    assert(entries[latest], platform .. " latest has no version entry")
    local versions = {}
    for version, entry in pairs(entries) do
        if version ~= "source" and version ~= "latest" then
            versions[version] = true
            local hashes = assert(entry.sha256, platform .. "/" .. version .. " has no hashes")
            local aliases = assert(entry.arch_alias, platform .. "/" .. version .. " has no aliases")
            for arch, alias in pairs(wanted) do
                local digest = assert(hashes[arch], platform .. "/" .. version .. "/" .. arch)
                assert(#digest == 64 and digest:match("^[0-9a-f]+$"), "invalid digest")
                assert(aliases[arch] == alias, "incorrect asset architecture")
                local url = entries.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
                assert(url:find("/v" .. version .. "/", 1, true), "incorrect release URL")
                assert(url:find("omp-"), "missing OMP asset")
            end
            for arch in pairs(hashes) do assert(wanted[arch], "unexpected hash architecture") end
            for arch in pairs(aliases) do assert(wanted[arch], "unexpected asset architecture") end
        end
    end
    if baseline then
        assert(baseline.latest == latest, "platform latest versions differ")
        for version in pairs(baseline.versions) do assert(versions[version], "missing platform version") end
        for version in pairs(versions) do assert(baseline.versions[version], "unexpected platform version") end
    else
        baseline = { latest = latest, versions = versions }
    end
end
'''
        subprocess.run([lua, "-e", script], check=True)

    @pytest.mark.static
    def test_host_loader_not_replaced(self):
        lua = shutil.which("lua") or shutil.which("lua5.4")
        if not lua:
            pytest.skip("Lua is required to inspect package metadata")
        script = f'import = function() end; dofile("{PKG_FILE}"); assert(package.xpm.linux.deps == nil)'
        subprocess.run([lua, "-e", script], check=True)

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


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("omp --version", contains=RELEASE_VERSION)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_completions(self):
        assert_command_output("omp completions bash", contains="complete -F _omp omp")
