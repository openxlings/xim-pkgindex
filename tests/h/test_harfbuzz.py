"""测试 harfbuzz 包"""
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

PKG = "harfbuzz"
PKG_FILE = "pkgs/h/harfbuzz.lua"


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
        """harfbuzz-subset is a HARD dependency of GTK 4 (no `required: false`)
    and harfbuzz-gobject is named by pango's pangoft2.pc. The published
    8.3.0 payload had neither: one library, one .pc.
        """
        assert_pkgconfig_resolves("harfbuzz", "harfbuzz-subset", "harfbuzz-gobject")
