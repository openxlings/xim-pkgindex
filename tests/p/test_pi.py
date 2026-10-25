"""Tests for the native Pi coding-agent package."""
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_command_output,
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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not
from tests.lib.xpkg_parser import parse_xpkg

PKG = "pi"
PKG_FILE = "pkgs/p/pi.lua"
RELEASE_VERSION = "1.4.0"
SUPPORTED_ARCHES = {"x86_64": "x64", "aarch64": "arm64"}


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
    def test_package_name_and_xvm_kind(self, meta):
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_release_matrix_has_six_verified_assets(self):
        lua = shutil.which("lua") or shutil.which("lua5.4")
        if not lua:
            pytest.skip("Lua is required to inspect package metadata")
        script = f'import = function() end; dofile("{PKG_FILE}")\n' + r'''
local expected = { x86_64 = "x64", aarch64 = "arm64" }
local expected_hashes = {
    linux = {
        x86_64 = "8fd5543a52a889d60ad57ccbf6c969e73c75c5240aae18ac40b506947a63dc38",
        aarch64 = "b60b3fda830a43c1dc3f5edb5fc7b681f22a0a930b48cdac13b97570c6045819",
    },
    macosx = {
        x86_64 = "62fb78fcdbc7c0dbd21044dd44bfb3af20df447285bb55e9debf86ff4838776d",
        aarch64 = "97291e7d2eb2d7d95ab1f67d26de7902302201bc8786c132bbbc9e53fa8526cc",
    },
    windows = {
        x86_64 = "f7dbd39814bf6763f01e7f688ad089615de1d0eb55fc8915a49acdc2088f4404",
        aarch64 = "122d3a1825eac4aa17081c769188c1d058febf579a9407091ae829626997ea96",
    },
}
assert(#package.archs == 2, "Pi release supports x86_64 and aarch64")
for _, arch in ipairs(package.archs) do assert(expected[arch], "unexpected package architecture") end
local platform_urls = {
    linux = "pi-linux-",
    macosx = "pi-darwin-",
    windows = "pi-windows-",
}
for platform, prefix in pairs(platform_urls) do
    local entries = assert(package.xpm[platform], platform)
    assert(entries.latest.ref == "1.4.0", platform .. " latest is not 1.4.0")
    local entry = assert(entries["1.0.0"], platform .. " is missing v1.0.0")
    assert(entry.revision == nil, "unexpected packaging revision")
    local hashes = assert(entry.sha256, "missing platform checksums")
    local aliases = assert(entry.arch_alias, "missing architecture aliases")
    local source = assert(entries.source, "missing platform source template")
    assert(source:find("${version}", 1, true), "URL does not follow version tags")
    for arch, alias in pairs(expected) do
        local digest = assert(hashes[arch], platform .. "/" .. arch .. " hash missing")
        assert(digest == expected_hashes[platform][arch], platform .. "/" .. arch .. " checksum mismatch")
        assert(#digest == 64 and digest:match("^[0-9a-f]+$"), "invalid SHA-256")
        assert(aliases[arch] == alias, "wrong release architecture alias")
        local url = source:gsub("%${version}", "1.0.0"):gsub("%${arch_alias}", alias)
        assert(url:find(prefix .. alias, 1, true), "asset URL/architecture mismatch")
        if platform == "windows" then assert(url:match("%.zip$"), "Windows asset is not ZIP")
        else assert(url:match("%.tar%.gz$"), "Unix asset is not tar.gz") end
    end
    for arch in pairs(hashes) do assert(expected[arch], "unexpected checksum architecture") end
    for arch in pairs(aliases) do assert(expected[arch], "unexpected URL architecture") end
    for version in pairs(entries) do
        if version ~= "source" and version ~= "latest" and version ~= "deps" then
            assert(version == "1.0.0" or version == "1.4.0", "unexpected release")
        end
    end
end
'''
        subprocess.run([lua, "-e", script], check=True)

    @pytest.mark.static
    def test_platform_scoped_dependencies(self):
        lua = shutil.which("lua") or shutil.which("lua5.4")
        if not lua:
            pytest.skip("Lua is required to inspect package metadata")
        script = f'import = function() end; dofile("{PKG_FILE}")\n' + r'''
local linux_deps = package.xpm.linux.deps or {}
local macos_deps = package.xpm.macosx.deps or {}
local windows_deps = assert(package.xpm.windows.deps, "Windows dependencies are missing")
assert(linux_deps.runtime == nil and linux_deps.build == nil,
       "Linux must not declare runtime or build dependencies")
assert(macos_deps.runtime == nil and macos_deps.build == nil,
       "macOS must not declare runtime or build dependencies")
assert(windows_deps.runtime == nil, "Windows 7zip must not be a runtime dependency")
assert(type(windows_deps.build) == "table" and #windows_deps.build == 1
       and windows_deps.build[1] == "xim:7zip",
       "Windows must declare only build-time xim:7zip")
'''
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
        assert_install_succeeds(PKG, timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("pi --version", contains=RELEASE_VERSION)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help(self):
        assert_command_output("pi --help", contains="AI coding assistant")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_pi(self):
        assert_xvm_shim_exists(PKG)
