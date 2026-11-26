"""Tests for the yt-dlp package."""
import subprocess

from tests.lib.assertions import (
    assert_install_succeeds,
    assert_no_typos,
    assert_platform_supported,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test
from tests.lib.xpkg_parser import parse_xpkg

PKG = "yt-dlp"
PKG_FILE = "pkgs/y/yt-dlp.lua"


def test_yt_dlp_metadata():
    pkg = parse_xpkg(PKG_FILE)
    assert_valid_spec(pkg)
    assert_valid_type(pkg)
    assert_required_fields(pkg)
    assert_no_typos(pkg)
    assert_uses_new_api(PKG_FILE)
    assert_platform_supported(pkg)


@skip_if_not("linux")
@under_test(PKG)
def test_yt_dlp_install_and_run():
    assert_xim_add_succeeds(PKG_FILE)
    assert_install_succeeds(PKG)
    assert_xvm_registered(PKG)
    res = subprocess.run(
        ["yt-dlp", "--version"],
        capture_output=True,
        text=True,
        check=True,
    )
    assert "2026.11.23" in res.stdout
