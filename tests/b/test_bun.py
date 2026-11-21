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
VERSION = "1.3.11"

UPSTREAM = {
    "linux": {
        "x86_64": ("x64-baseline", "abe346f63414547cdf6b35b7a649a490c728b93d006226156923918a84c0e59b"),
        "aarch64": ("aarch64", "d13944da12a53ecc74bf6a720bd1d04c4555c038dfe422365356a7be47691fdf"),
    },
    "macosx": {
        "x86_64": ("x64-baseline", "fb6739b08bf54550edaa7c824cd5b2dca45b6a06afef408443087a63105f6f8d"),
        "aarch64": ("aarch64", "6f5a3467ed9caec4795bf78cd476507d9f870c7d57b86c945fcb338126772ffc"),
    },
    "windows": {
        "x86_64": ("x64-baseline", "9d0e0f923e9626f3bc6044fc32e0d3ab29039aea753f5678ef8801cf26f75288"),
        "aarch64": ("aarch64", "c7f661d7529ec3f2fdfc1eac39a760c65f526955bce06b74859c532cb4bf00d7"),
    },
}
SOURCES = {
    "linux": "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-${arch_alias}.zip",
    "macosx": "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-darwin-${arch_alias}.zip",
    "windows": "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-windows-${arch_alias}.zip",
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
