"""procps-ng: the process tools in full, static, for a Luban core system
(xlings design 2026-10-19 §20)."""
import os

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
)
from tests.lib.platform_utils import project_root

PKG_FILE = "pkgs/p/procps-ng.lua"


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
    def test_both_architectures_from_the_factory(self, source):
        assert 'url = "XLINGS_RES"' in source
        assert "x86_64 = " in source and "aarch64 = " in source

    @pytest.mark.static
    def test_the_programs_a_system_expects(self, source):
        for prog in ("ps", "top", "free", "pgrep", "pkill", "pidof", "uptime", "vmstat", "watch"):
            assert f'"{prog}"' in source, prog
        assert "TERMINFO_DIRS" in source

    @pytest.mark.static
    def test_the_factory_builds_it_static(self):
        with open(os.path.join(project_root(), "tools/res/build.sh"), encoding="utf-8") as f:
            build = f.read()
        assert "procps-ng)" in build and "LDFLAGS=-all-static" in build
