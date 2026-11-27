"""adwaita-cursors: GNOME's Adwaita cursor theme and the default theme naming
it, as data (xlings design 2026-10-16 L §10)."""
import os
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
)
from tests.lib.platform_utils import project_root


def _one_digest(text):
    """An entry names the architectures its one artifact is for
    (`sha256 = { x86_64 = "<h>", aarch64 = "<h>" }`, the index's check K1):
    read each such table as the one digest it holds."""
    def one(m):
        values = set(re.findall(r'"([0-9a-fA-F]{64})"', m.group(0)))
        return f'sha256 = "{values.pop()}"' if len(values) == 1 else m.group(0)
    return re.sub(r'sha256\s*=\s*\{[^{}]*\}', one, text)

PKG_FILE = "pkgs/a/adwaita-cursors.lua"


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
    def test_one_archive_for_every_architecture(self, source):
        assert "adwaita-cursors-49.0.tar.gz" in source and "-linux-" not in source
        assert re.search(r'sha256 = "[0-9a-f]{64}"', _one_digest(source))

    @pytest.mark.static
    def test_it_is_the_default_theme(self, source):
        assert '"icons", "default", "index.theme"' in source

    @pytest.mark.static
    def test_the_x11_names_link_to_what_it_ships(self):
        with open(os.path.join(project_root(), "tools/res/build.sh"), encoding="utf-8") as f:
            build = f.read()
        for legacy in ("left_ptr default", "xterm text", "hand2 pointer", "watch wait"):
            assert f"\n{legacy}\n" in build, legacy
