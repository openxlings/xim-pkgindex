"""luban:cursors: the Luban pointer theme, pixel art from one text source
(xlings design 2026-10-19 §15.2)."""
import importlib.util
import os
import re
import struct

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
)
from tests.lib.platform_utils import project_root

PKG_FILE = "pkgs/luban/cursors.lua"
MAKE = "tools/res/cursors/make.py"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def source():
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


@pytest.fixture(scope="module")
def make():
    spec = importlib.util.spec_from_file_location("make_cursors", os.path.join(project_root(), MAKE))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestStatic:
    @pytest.mark.static
    def test_recipe_shape(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_one_archive_for_every_system(self, source):
        assert "luban-cursors-2026.10.19.tar.gz" in source and "-linux-" not in source
        assert re.search(r'sha256 = "[0-9a-f]{64}"', source)
        for platform in ("linux = versions", "macosx = versions", "windows = versions"):
            assert platform in source

    @pytest.mark.static
    def test_it_is_the_default_theme_and_the_hosts(self, source):
        assert '"icons", "default", "index.theme"' in source
        assert '"luban", "cursors", "cursors.json"' in source

    @pytest.mark.static
    def test_the_source_has_every_shape_opensal_names(self, make):
        cursors, aliases, order = make.parse(os.path.join(project_root(), "tools/res/cursors/luban.cursors"))
        assert set(make.REQUIRED) <= set(cursors)
        for legacy in ("left_ptr", "xterm", "hand2", "watch", "fleur", "sb_h_double_arrow"):
            assert legacy in dict(aliases), legacy

    @pytest.mark.static
    def test_it_makes_xcursor_files_at_whole_multiples(self, make, tmp_path):
        make.main(["make.py", str(tmp_path)])
        f = tmp_path / "share/icons/Luban/cursors/default"
        data = f.read_bytes()
        assert data[:4] == b"Xcur"
        ntoc = struct.unpack("<I", data[12:16])[0]
        sizes = sorted(struct.unpack("<III", data[16 + 12 * k:28 + 12 * k])[1] for k in range(ntoc))
        assert sizes == [24, 48, 72]
        assert (tmp_path / "share/icons/Luban/cursors/left_ptr").is_symlink()
        assert "Inherits=Luban" in (tmp_path / "share/icons/default/index.theme").read_text()
        assert (tmp_path / "share/luban/cursors/pointer-48.png").read_bytes()[:4] == b"\x89PNG"
