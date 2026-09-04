"""测试 libjpeg-turbo 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_uninstall_succeeds, assert_xvm_registered,
    assert_valid_xvm_node_kinds, assert_pkgconfig_resolves,
)
from tests.lib.platform_utils import skip_if_not

PKG = "libjpeg-turbo"
PKG_FILE = "pkgs/l/libjpeg-turbo.lua"


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


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)

    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_uninstall(self):
        assert_uninstall_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    # The assertion that actually means something for a library package.
    # "xvm registered the node" only says the recipe ran; it says nothing
    # about whether a consumer can use the payload, and the two came apart
    # badly in this index -- glib shipped gmodule-2.0.pc without the
    # gmodule-no-export-2.0.pc it names in Requires, and every GNOME .pc
    # stopped resolving while every package still installed clean.
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_pkgconfig_resolves(self):
        assert_pkgconfig_resolves("libjpeg", "libturbojpeg")
