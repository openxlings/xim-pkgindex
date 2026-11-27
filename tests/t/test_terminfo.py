"""terminfo: ncurses' terminal descriptions, compiled, as data (xlings design
2026-10-16 L §10). Built once by tools/res/build.sh terminfo."""
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

PKG_FILE = "pkgs/t/terminfo.lua"


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
        assert re.search(r'archs = \{"x86_64", "aarch64"\}', source)
        assert "terminfo-6.6.20261010.tar.gz" in source and "-linux-" not in source
        assert re.search(r'sha256 = "[0-9a-f]{64}"', _one_digest(source))

    @pytest.mark.static
    def test_the_names_terminals_set_are_there(self, source):
        # install() refuses a payload without the usual ones.
        assert '"x", "xterm-256color"' in source and '"l", "linux"' in source

    @pytest.mark.static
    def test_its_input_is_pinned(self):
        with open(os.path.join(project_root(), "tools/res/inputs.txt"), encoding="utf-8") as f:
            assert re.search(r"^ncurses-terminfo\.src 6\.6\.20261010 [0-9a-f]{64}$", f.read(), re.M)
