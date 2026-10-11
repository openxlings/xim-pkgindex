import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import assert_required_fields, assert_valid_type, assert_valid_spec, assert_xim_add_succeeds

PKG_FILE = "pkgs/l/limine.lua"

@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(PKG_FILE)
    assert_required_fields(meta)
    assert_valid_type(meta)
    assert_valid_spec(meta)

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds(PKG_FILE)
