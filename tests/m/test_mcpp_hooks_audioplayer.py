"""Test the mcpp-hooks-audioplayer package."""

import pytest

from tests.lib.assertions import (
    assert_command_output,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_xim_add_succeeds,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not
from tests.lib.xpkg_parser import parse_xpkg

PKG = "mcpp-hooks-audioplayer"
INSTALL_PKG = "local:mcpp-hooks-audioplayer@0.0.3"
PKG_FILE = "pkgs/m/mcpp-hooks-audioplayer.lua"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_package_isolation(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(INSTALL_PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help(self):
        assert_xvm_shim_exists(PKG)
        assert_command_output(
            f"{PKG} --help", contains="nailong-xiao|beiliya1"
        )
