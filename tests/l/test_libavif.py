"""Tests for the libavif package (a conda-forge repack served from xlings-res)."""
import glob
import os
import subprocess
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "libavif"
PKG_FILE = "pkgs/l/libavif.lua"
VERSION = "0.9.3"
SONAME = "libavif.so.13"


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
    def test_both_mirrors_carry_the_same_names(self, meta):
        for arch in ("x86_64", "aarch64"):
            name = f"libavif-0.9.3-linux-{arch}.tar.gz"
            assert f"https://github.com/xlings-res/libavif/releases/download/0.9.3/{name}" in meta.raw_content
            assert f"https://gitcode.com/xlings-res/libavif/releases/download/0.9.3/{name}" in meta.raw_content

    @pytest.mark.static
    def test_pinned_and_not_auto_updated(self, meta):
        # 0.9.3 is the SONAME libavif.so.13 Playwright's WebKit links against
        assert "autoupdate" not in meta.raw_content
        assert 'ref = "0.9.3"' in meta.raw_content

    @pytest.mark.static
    def test_depends_on_the_aom_it_was_built_against(self, meta):
        assert '"xim:aom@3.3.0"' in meta.raw_content


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


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(PKG, timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_the_soname_is_in_the_payload(self):
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-libavif", "*", "lib", SONAME)))
        assert hits, f"no libavif payload under {xpkgs_dir()}"
        out = subprocess.run(["readelf", "-d", os.path.realpath(hits[-1])], capture_output=True, text=True).stdout
        assert f"[{SONAME}]" in out, out
