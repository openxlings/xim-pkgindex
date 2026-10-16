"""luban-fonts: the fonts the Luban OS window ships with, on every system
(xlings design 2026-10-16 L §13); luban-os depends on it."""
import os
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
)
from tests.lib.platform_utils import project_root

PKG_FILE = "pkgs/luban/luban-fonts.lua"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


def read(rel):
    with open(os.path.join(project_root(), rel), encoding="utf-8") as handle:
        return handle.read()


class TestStatic:
    @pytest.mark.static
    def test_recipe_shape(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_every_system_has_it(self):
        source = read(PKG_FILE)
        assert 'macosx = { ref = "linux" }' in source and 'windows = { ref = "linux" }' in source
        assert re.search(r'sha256 = "[0-9a-f]{64}"', source)

    @pytest.mark.static
    def test_luban_os_depends_on_it_everywhere(self):
        assert read("pkgs/luban/luban-os.lua").count('"xim:luban-fonts"') == 3

    @pytest.mark.static
    def test_it_holds_what_luban_os_loads(self):
        # luban/os/desktop/src/host.cpp in xlings loads these by name.
        build = read("tools/res/build.sh")
        for font in ("JetBrainsMono-Regular.ttf", "JetBrainsMono-Bold.ttf", "Inter-Regular.ttf",
                     "SarasaMonoSC-Regular.ttf", "SarasaMonoSC-Bold.ttf", "NotoSansSC-Regular.otf",
                     "fusion-pixel-12px-proportional-zh_hans.ttf"):
            assert font in build, font
