"""luban-os: the Luban OS window, released with xlings; a glibc and X11
program an install patches onto the index's (xlings: Luban OS architecture
design §14.7)."""
import os
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
)
from tests.lib.platform_utils import project_root

PKG_FILE = "pkgs/l/luban-os.lua"


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
    def test_it_declares_every_library_it_links(self, source):
        """tools/luban_os_release.sh in xlings checks the binary needs no more than these."""
        for dep in ("xim:glibc", "xim:gcc-runtime", "xim:libX11", "xim:libxcb", "xim:libXcursor",
                    "xim:libXext", "xim:libXfixes", "xim:libXi", "xim:libXrandr"):
            assert f'"{dep}' in source, dep

    @pytest.mark.static
    def test_its_version_is_an_xlings_release(self, source):
        latest = re.search(r'\["latest"\] = \{ ref = "([0-9.]+)" \}', source).group(1)
        assert re.fullmatch(r"\d{4}\.\d{1,2}\.\d{1,2}\.[1-9]\d*", latest), "a date version, N from 1"
        assert f'["{latest}"]' in source
        assert "@SHA256" not in source, "a digest left unfilled"

    @pytest.mark.static
    def test_the_desktop_entry_goes_with_it(self, source):
        assert ".local/share/applications" in source
        assert "os.tryrm(entry_file())" in source, "uninstall removes the entry"
