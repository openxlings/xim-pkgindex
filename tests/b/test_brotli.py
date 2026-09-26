"""测试 brotli 包"""
import glob
import os
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "brotli"
PKG_FILE = "pkgs/b/brotli.lua"


@pytest.fixture(scope='module')
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
    def test_both_mirrors(self, meta):
        for arch in ("x86_64", "aarch64"):
            name = f"brotli-1.2.0-r1-linux-{arch}.tar.gz"
            assert f"https://github.com/xlings-res/brotli/releases/download/1.2.0/{name}" in meta.raw_content
            assert f"https://gitcode.com/xlings-res/brotli/releases/download/1.2.0/{name}" in meta.raw_content


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
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG, timeout=180)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_library_is_relocated(self):
        """libbrotlidec.so.1 在载荷中, 且不再含 conda 的构建前缀。"""
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-brotli", "*", "lib", "libbrotlidec.so.1")))
        assert hits, f"no brotli payload under {xpkgs_dir()}"
        assert b"placehold" not in open(os.path.realpath(hits[-1]), "rb").read()
