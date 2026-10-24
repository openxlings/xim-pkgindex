"""Tests for the oh-my-pi package."""
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

PKG_FILE = "pkgs/o/oh-my-pi.lua"
INSTALL_PKG = "local:oh-my-pi@18.11.3"
RELEASE_VERSION = "18.11.3"


def assert_version_matrix(pkg_file):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua is required to inspect package metadata")
    script = "import = function() end; dofile(" + json.dumps(str(pkg_file)) + ")\n" + r'''
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
            local hashes, aliases = entry.sha256, entry.arch_alias
            local prefixes = { linux = "linux", macosx = "darwin", windows = "windows" }
            for arch, alias in pairs(wanted) do
                local resource = not hashes and assert(entry[arch], platform .. "/" .. version .. "/" .. arch)
                local digest = hashes and hashes[arch] or resource.sha256
                assert(type(digest) == "string" and #digest == 64 and digest:match("^[0-9a-f]+$"), "invalid digest")
                local url
                if hashes then
                    assert(aliases and aliases[arch] == alias, "incorrect asset architecture")
                    url = entries.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
                else
                    url = resource.url
                    for key in pairs(resource) do
                        assert(key == "url" or key == "sha256", "unexpected resource field")
                    end
                end
                local expected = "https://github.com/can1357/oh-my-pi/releases/download/v" .. version ..
                    "/omp-" .. prefixes[platform] .. "-" .. alias .. (platform == "windows" and ".exe" or "")
                assert(url == expected, "incorrect release URL or asset architecture")
            end
            if hashes then
                for arch in pairs(hashes) do assert(wanted[arch], "unexpected hash architecture") end
                for arch in pairs(aliases) do assert(wanted[arch], "unexpected asset architecture") end
            else
                for arch in pairs(entry) do assert(wanted[arch], "unexpected resource architecture") end
            end
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
    result = subprocess.run([lua, "-e", script], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr


def omp_output(*args):
    # Use the candidate PATH supplied by the harness; a login shell can select
    # an older globally configured omp instead.
    result = subprocess.run(["omp", *args], capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0, output
    return output


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
        assert_version_matrix(PKG_FILE)

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
        assert_install_succeeds(INSTALL_PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        version = os.environ.get("XLINGS_TEST_VERSION", RELEASE_VERSION)
        assert version in omp_output("--version")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_completions(self):
        assert "complete -F _omp omp" in omp_output("completions", "bash")


@pytest.mark.static
@pytest.mark.parametrize("mutation", [
    "",
    'package.xpm.linux["2.0.0"].aarch64 = nil',
    'package.xpm.linux["2.0.0"].x86_64.sha256 = "bad"',
    'package.xpm.linux["2.0.0"].aarch64.url = package.xpm.linux["2.0.0"].x86_64.url',
    'package.xpm.linux["2.0.0"].riscv64 = package.xpm.linux["2.0.0"].x86_64',
])
def test_mixed_historical_and_explicit_resource_matrices(tmp_path, mutation):
    recipe = tmp_path / "oh-my-pi.lua"
    recipe.write_text(r'''
package = { archs = { "x86_64", "aarch64" }, xpm = {} }
for platform, prefix in pairs({ linux = "linux", macosx = "darwin", windows = "windows" }) do
    local source = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-" ..
        prefix .. "-${arch_alias}" .. (platform == "windows" and ".exe" or "")
    local entry = {
        source = source, latest = { ref = "2.0.0" },
        ["1.0.0"] = { arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
            sha256 = { x86_64 = string.rep("a", 64), aarch64 = string.rep("b", 64) } },
        ["2.0.0"] = {},
    }
    for arch, alias in pairs({ x86_64 = "x64", aarch64 = "arm64" }) do
        local url = source:gsub("%${version}", "2.0.0"):gsub("%${arch_alias}", alias)
        entry["2.0.0"][arch] = { url = url, sha256 = string.rep("c", 64) }
    end
    package.xpm[platform] = entry
end
''' + mutation, encoding="utf-8")
    if mutation:
        with pytest.raises(AssertionError):
            assert_version_matrix(recipe)
    else:
        assert_version_matrix(recipe)
