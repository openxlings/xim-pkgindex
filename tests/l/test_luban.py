"""luban: the Luban OS command, released with xlings as its own payload
(bin/luban of each xlings archive; xlings tools/luban_release.sh)."""
import os
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
)
from tests.lib.platform_utils import project_root

PKG_FILE = "pkgs/luban/luban.lua"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def source():
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


class TestStatic:
    @pytest.mark.static
    def test_recipe_shape(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_every_platform_xlings_is_released_for(self, source):
        for platform in ("linux", "macosx", "windows"):
            assert re.search(rf"\n        {platform} = \{{", source), platform
        assert source.count('url = "XLINGS_RES"') >= 3

    @pytest.mark.static
    def test_its_version_is_an_xlings_release(self, source):
        for latest in re.findall(r'\["latest"\] = \{ ref = "([0-9.]+)" \}', source):
            assert re.fullmatch(r"\d{4}\.\d{1,2}\.\d{1,2}\.[1-9]\d*", latest), "a date version, N from 1"
            assert f'["{latest}"]' in source
        assert "@SHA256" not in source, "a digest left unfilled"

    @pytest.mark.static
    def test_luban_is_a_program_of_the_routing_table(self, source):
        assert 'programs = {"luban"}' in source
        assert 'xvm.add("luban"' in source
        assert 'xvm.remove("luban")' in source
