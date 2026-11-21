"""Tests for the native Bun release package."""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_no_direct_pkg_manager,
    assert_uses_new_api, assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "bun"
PKG_FILE = "pkgs/b/bun.lua"
VERSION = "1.4.5"
PREVIOUS_VERSION = "1.3.11"

UPSTREAM = {
    "linux": {
        "x86_64": ("x64-baseline", "dcb23a18a1c2fff12d57bcef696dbbb42eb67fde29f43816ecb595459a24c463"),
        "aarch64": ("aarch64", "18656a3bf0ea5641f5796ae4213b75255579a70a0fded2f337933785568cdf84"),
    },
    "macosx": {
        "x86_64": ("x64-baseline", "fb0121739a7e80e7511b6bfe4d2116422b48ba18a013acadef0c425348e95891"),
        "aarch64": ("aarch64", "b5d6bc2e13caf14e57c89661e89efd073ff16165b41bfe43882616410609cd10"),
    },
    "windows": {
        "x86_64": ("x64-baseline", "3c081c73865e7a3453a9d514cc2ba3d699880621bcf67bb17241ff5194cb1d4b"),
        "aarch64": ("aarch64", "41f57d49c3c6811888d9633c569e40b4eb1f7e92b5e5336e3abd3af03187d77a"),
    },
}
SOURCES = {
    "linux": "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-${arch_alias}.zip",
    "macosx": "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-darwin-${arch_alias}.zip",
    "windows": "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-windows-${arch_alias}.zip",
}
AUTUPDATE_URLS = {
    "linux": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-linux-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-linux-aarch64.zip",
    },
    "macosx": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-darwin-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-darwin-aarch64.zip",
    },
    "windows": {
        "x86_64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-windows-x64-baseline.zip",
        "aarch64": "https://github.com/oven-sh/bun/releases/download/${tag}/bun-windows-aarch64.zip",
    },
}


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


def _lua_map(section, field):
    match = re.search(rf"{field}\s*=\s*\{{([^}}]*)\}}", section, re.S)
    assert match, f"{field} table missing"
    return dict(re.findall(r'(\w+)\s*=\s*"([^"]+)"', match.group(1)))


def _platform_section(content, platform):
    xpm = content.split("xpm = {", 1)[1]
    platforms = ("linux", "macosx", "windows")
    start = xpm.index(f"        {platform} = {{")
    later = [xpm.index(f"        {name} = {{") for name in platforms
             if name != platform and xpm.find(f"        {name} = {{") > start]
    end = min(later) if later else xpm.index("\n    }\n}", start)
    return xpm[start:end]


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
    def test_official_release_matrix_and_checksums(self, meta):
        assert set(meta.platforms) == set(UPSTREAM)
        assert "x86_64" in meta.raw_content and "aarch64" in meta.raw_content

        for platform, expected in UPSTREAM.items():
            section = _platform_section(meta.raw_content, platform)
            source = re.search(r'source\s*=\s*"([^"]+)"', section)
            assert source and source.group(1) == SOURCES[platform]
            assert f'["latest"] = {{ref = "{VERSION}"}}' in section
            assert f'["{VERSION}"] = {{' in section
            assert f'["{PREVIOUS_VERSION}"] = {{' in section
            assert _lua_map(section, "arch_alias") == {
                arch: pair[0] for arch, pair in expected.items()
            }
            digests = _lua_map(section, "sha256")
            assert digests == {arch: pair[1] for arch, pair in expected.items()}
            assert all(re.fullmatch(r"[0-9a-f]{64}", value) for value in digests.values())

    @pytest.mark.static
    def test_install_uses_upstream_zip_without_npm_or_node(self, meta):
        content = meta.raw_content
        assert "https://github.com/oven-sh/bun/releases/download/bun-v${version}/" in content
        assert '"xim:node"' not in content
        assert "npm install" not in content
        assert "node_modules" not in content

    @pytest.mark.static
    def test_autoupdate_tracks_all_release_assets(self, meta):
        content = meta.raw_content
        extension = content.split("autoupdate = {", 1)[1].split("    xpm = {", 1)[0]
        assert 'source = "https://github.com/oven-sh/bun/releases"' in extension
        assert 'tag = "bun-v${version}"' in extension
        assert "GLOBAL = {" in extension and "required = true" in extension
        assert "CN =" not in extension

        for platform, assets in AUTUPDATE_URLS.items():
            assert re.search(rf"(?m)^\s+{platform}\s*=\s*\{{", extension)
            for arch, url in assets.items():
                assert re.search(
                    rf'(?m)^\s+{arch}\s*=\s*"{re.escape(url)}",?\r?$', extension
                ), f"missing autoupdate URL for {platform}/{arch}"


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
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_host_package_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG, VERSION), timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_bun_version(self):
        assert_command_output("bun --version", contains=VERSION)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_bun_runs_javascript(self):
        assert_command_output("bun -e 'console.log(6 * 7)'", contains="42")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("bun")
