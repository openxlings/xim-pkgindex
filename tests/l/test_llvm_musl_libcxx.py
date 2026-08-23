"""测试 llvm-musl-libcxx 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not

PKG = "llvm-musl-libcxx"
PKG_FILE = "pkgs/l/llvm-musl-libcxx.lua"


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
    def test_both_target_arches_have_sha256(self, meta):
        # The payload is per-TARGET-arch: one musl libc++ per arch, each
        # pinned by its own sha256. A missing arch leaves that target's users
        # downloading an unverifiable (or 404) asset.
        rc = meta.raw_content
        assert 'x86_64 = "' in rc, "missing x86_64 sha256"
        assert 'aarch64 = "' in rc, "missing aarch64 sha256"

    @pytest.mark.static
    def test_static_only_archives(self, meta):
        # The musl story is fully static ELF; a dynamic libc++ on musl is
        # nothing this target wants, and shipping one would double the asset
        # for no consumer.
        rc = meta.raw_content
        assert "libc++.a" in rc, "payload must ship the static archive"
        assert ".so" not in rc, "payload must not ship dynamic libc++"


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
        assert_install_succeeds(PKG)
