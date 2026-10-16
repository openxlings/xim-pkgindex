"""labwc-desktop: the traditional Luban desktop session, one relocatable tree,
and the luban-desktop edition that runs it (xlings: Luban OS architecture
design §9.3)."""
import json
import os
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
)
from tests.lib.platform_utils import project_root

PKG_FILE = "pkgs/luban/labwc-desktop.lua"
EDITION_FILE = "pkgs/luban/luban-desktop.lua"
SESSION = "tools/res/labwc-desktop/share/wayland-sessions/labwc-desktop.desktop"


def text(rel):
    with open(os.path.join(project_root(), rel), encoding="utf-8") as handle:
        return handle.read()


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_recipe_shape(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_every_architecture_has_its_own_build(self):
        source = text(PKG_FILE)
        for arch in ("x86_64", "aarch64"):
            assert f"labwc-desktop-0.7.2-r1-linux-{arch}.tar.gz" in source
        assert "@SHA256" not in source, "a digest left unfilled"
        assert len(re.findall(r'sha256 = "[0-9a-f]{64}"', source)) == 2

    @pytest.mark.static
    def test_the_session_is_declared_the_freedesktop_way(self):
        """What opensal-wlr starts: Exec, and the opensal interfaces it uses."""
        session = text(SESSION)
        assert "[Desktop Entry]" in session
        assert re.search(r"^Exec=labwc$", session, re.M)
        assert re.search(r"^X-Opensal-Interfaces=.*\bsurface\b", session, re.M)
        assert 'dst = "share/wayland-sessions"' in text(PKG_FILE), "config() places the session in the SubOS's share"

    @pytest.mark.static
    def test_its_fonts_stay_in_its_tree(self):
        # Projected into a root's share/fonts they stopped its machine desktop
        # from starting (bisected on aarch64); xdesk carries its own.
        assert 'dst = "share/fonts"' not in text(PKG_FILE)
