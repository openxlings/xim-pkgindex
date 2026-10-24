"""libSM runtime package metadata and index registration."""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api, assert_xim_add_succeeds,
)
PKG = "pkgs/l/libSM.lua"

@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(PKG)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)

@pytest.mark.isolation
def test_isolation():
    assert_no_exec_xvm(PKG)
    assert_no_bashrc_modification(PKG)
    assert_no_direct_path_modification(PKG)
    assert_uses_new_api(PKG)

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds(PKG)
