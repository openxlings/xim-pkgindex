"""Tests for the android-platform package: android.jar and framework.aidl,
versioned by API level rather than by Google's own Pkg.Revision, because the
API level is the number a consumer actually pins.
"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)
from tests.lib.platform_utils import skip_if_not

PKG = "android-platform"
PKG_FILE = "pkgs/a/android-platform.lua"


def _code(content: str) -> str:
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def code(meta):
    return _code(meta.raw_content)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.static
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.static
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.static
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.static
    def test_every_api_level_declared_on_every_host(self, code):
        for host in ("linux", "macosx", "windows"):
            assert re.search(host + r'\s*=\s*\{', code), f"no {host} table"
        assert code.count('["36"]') == 3, "API 36 must be aliased on every host"
        assert code.count('["35"]') == 3, "API 35 must be aliased on every host"
        assert code.count('["34"]') == 3, "API 34 must be aliased on every host"

    @pytest.mark.static
    def test_no_per_host_variation_in_url_or_hash(self, code):
        """The archive is host-independent (measured: no host-os attribute on
        the platform <archive> in repository2-3.xml), so all three hosts'
        url/sha256 pairs for one API level must be byte-identical -- a
        difference here would mean a copy-paste error, not a real per-host
        distinction. `code` has comments stripped, so only the three live
        xpm entries are counted."""
        for level, revision in (("36", "36-r2"), ("35", "35-r2")):
            urls = re.findall(r'platform-' + level + r'_r02\.zip', code)
            assert len(urls) == 3, f"the API {level} URL must appear once per host (3 total)"
            hashes = re.findall(
                r'\["' + revision + r'"\]\s*=\s*\{\s*url = \{ GLOBAL = "[^"]+" \},\s*sha256 = "([0-9a-f]{64})"',
                code)
            assert len(hashes) == 3 and len(set(hashes)) == 1, \
                f"API {level}'s sha256 must be identical across all three host tables"

    @pytest.mark.static
    def test_every_sha256_is_64_hex_chars(self, meta):
        for m in re.finditer(r'sha256\s*=\s*"([0-9a-f]+)"', meta.raw_content):
            assert len(m.group(1)) == 64

    @pytest.mark.static
    def test_no_cn_mirror_invented(self, code):
        assert "gitcode.com/xlings-res" not in code
        assert "ci = {" not in code

    @pytest.mark.static
    def test_extract_dir_derived_from_version_not_hardcoded_per_entry(self, code):
        """android-35 vs android-34 -- one function recovers the API level
        from the resolved version string rather than two separate constants,
        so a third level needs only a new xpm entry."""
        assert "extract_dir" in code
        assert re.search(r'pkginfo\.version\(\)', code)

    @pytest.mark.static
    def test_install_asserts_both_files(self, code):
        assert "android.jar" in code
        assert "framework.aidl" in code


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    @pytest.mark.parametrize("revision", ["36-r2", "35-r2"])
    def test_installed_level_has_both_files(self, revision):
        from tests.lib.platform_utils import xpkgs_dir
        import glob
        import os
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(f"{xpkgs_dir()}/{ns}-x-android-platform/{revision}"))
        if not hits:
            pytest.skip(f"android-platform@{revision} is not installed")
        d = hits[-1]
        assert os.path.isfile(os.path.join(d, "android.jar"))
        assert os.path.isfile(os.path.join(d, "framework.aidl"))
