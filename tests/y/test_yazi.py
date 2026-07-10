"""Tests for the yazi package."""
import re

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_platform_supported,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_xim_add_succeeds,
)
from tests.lib.xpkg_parser import parse_xpkg

PKG_FILE = "pkgs/y/yazi.lua"
VERSION = "26.5.6"
ASSETS = {
    "linux": (
        "yazi-x86_64-unknown-linux-musl.zip",
        "1031a02560d053301537195a6661d227c15cb4ce5c30481050b31e2b88681bff",
    ),
    "macosx": (
        "yazi-aarch64-apple-darwin.zip",
        "7abd71725e2fe27bed036becbf6ce79fa17964eb68491d34190011c94b8c7ca8",
    ),
    "windows": (
        "yazi-x86_64-pc-windows-msvc.zip",
        "6c6c52a4b2648e179f917bdaa7c57e793d18561b380a8bfa025f10cd1b9b2ad1",
    ),
}


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


def _platform_block(raw_content: str, platform: str) -> str:
    start = raw_content.index(f"        {platform} = {{")
    tail = raw_content[start:]
    next_match = re.search(r"\n        (linux|macosx|windows) = \{", tail[1:])
    if next_match:
        return tail[:1 + next_match.start()]
    end_match = re.search(r"^    \},", tail, re.MULTILINE)
    return tail[:end_match.start()]


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
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_latest_uses_official_global_and_gitcode_cn(self, meta):
        for platform in ("linux", "macosx", "windows"):
            asset, sha256 = ASSETS[platform]
            block = _platform_block(meta.raw_content, platform)
            assert re.search(rf'\["latest"\]\s*=\s*\{{\s*ref\s*=\s*"{VERSION}"\s*\}}', block)
            assert f"github.com/sxyazi/yazi/releases/download/v{VERSION}/{asset}" in block
            assert f"gitcode.com/xlings-res/yazi/releases/download/{VERSION}/{asset}" in block
            assert f'sha256 = "{sha256}"' in block


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
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)
