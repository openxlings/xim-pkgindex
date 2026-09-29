"""qt5: Qt 5.15.2 qtbase + ICU 56 from the official Qt repository, via libs/qtsdk.lua"""
from pathlib import Path
import re

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.recipe_deps import declared_deps
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)

RECIPE = Path("pkgs/q/qt5.lua")


@pytest.mark.static
def test_recipe():
    meta = parse_xpkg(str(RECIPE))
    for check in (assert_required_fields, assert_valid_spec, assert_valid_type):
        check(meta)
    text = RECIPE.read_text()
    # every archive is pinned, and installed() re-checks what install() fetched
    assert len(re.findall(r'sha256 = "[0-9a-f]{64}"', text)) == 2
    assert "qtsdk.fetch_and_extract" in text and "qtsdk.read_marker" in text
    assert "lib/libQt5Core.so.5" in text and "lib/libicuuc.so.56" in text


@pytest.mark.static
def test_7zip_is_a_build_dependency():
    """7-Zip only unpacks the archives in install(); as a runtime dependency it
    would put 7z and 7zz on the user's PATH (docs/contributing.md §5.5)."""
    deps = declared_deps(str(RECIPE))["linux"]
    assert "xim:7zip" in deps["build"]
    assert "xim:7zip" not in deps["runtime"]
    assert "xim:glibc" in deps["runtime"]


@pytest.mark.isolation
def test_isolation():
    for check in (assert_no_exec_xvm, assert_no_bashrc_modification,
                  assert_no_direct_path_modification, assert_uses_new_api):
        check(str(RECIPE))


@pytest.mark.index
def test_index():
    assert_xim_add_succeeds(str(RECIPE))
