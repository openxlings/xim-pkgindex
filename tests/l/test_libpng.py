"""测试 libpng 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_xvm_registered,
    assert_valid_xvm_node_kinds, assert_pkgconfig_resolves,
)
from tests.lib.platform_utils import skip_if_not

PKG = "libpng"
PKG_FILE = "pkgs/l/libpng.lua"


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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)


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


class TestVerify:
    # No install/uninstall case here on purpose: this package is a shared
    # dependency of most of the index, so tearing it down mid-suite would
    # take unrelated packages with it. What is asserted is the state a
    # consumer meets.

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_pkgconfig_resolves(self):
        """Both names. Upstream installs the unversioned libpng.pc as well as
    the versioned one, cairo's .pc asks for `libpng`, and the payload
    shipped only libpng16.pc.

    This also covers the relocation bug underneath it: libpng16.pc says
    `includedir=${prefix}/include/libpng16`, and a rewrite that forces
    includedir to <payload>/include leaves -I pointing at a directory with
    no png.h in it -- which still passes an existence check, because that
    directory does exist.
        """
        assert_pkgconfig_resolves("libpng", "libpng16")
