"""测试 glib 包"""
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

PKG = "glib"
PKG_FILE = "pkgs/g/glib.lua"


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
        """gmodule-no-export-2.0 is the regression this file exists for. The
    published 2.80.0 payload ships gmodule-2.0.pc naming it in `Requires:`
    and does not ship the file, and pkg-config resolves Requires
    transitively -- so gmodule-2.0, gio-2.0, and every GNOME package
    downstream of them failed to resolve, while all of them installed
    cleanly and registered their xvm nodes.
        """
        assert_pkgconfig_resolves("glib-2.0", "gobject-2.0", "gio-2.0", "gmodule-2.0", "gmodule-no-export-2.0")
