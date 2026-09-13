"""Tests for the esbuild package: the platform binary npm publishes as
`@esbuild/<platform>`, fetched as its tarball and installed without node."""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "esbuild"
PKG_FILE = "pkgs/e/esbuild.lua"
VERSION = "0.25.12"


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
    def test_every_host_carries_both_arches(self, code):
        """npm names the platform, not xlings, so each host table carries a
        per-arch map; every host/arch the index names and npm ships is here."""
        for host in ("linux", "macosx", "windows"):
            assert re.search(host + r'\s*=\s*\{', code), f"no {host} table"
        urls = re.findall(r'registry\.npmjs\.org/@esbuild/([a-z0-9-]+)/-/\1-' + re.escape(VERSION) + r'\.tgz', code)
        assert sorted(urls) == sorted(
            ["linux-x64", "linux-arm64", "linux-ia32", "darwin-x64", "darwin-arm64",
             "win32-x64", "win32-arm64", "win32-ia32"]
        ), urls
        hashes = re.findall(r'sha256 = "([0-9a-f]{64})"', code)
        assert len(hashes) == 8 and len(set(hashes)) == 8, "eight tarballs, eight hashes"

    @pytest.mark.static
    def test_latest_points_at_the_measured_version(self, code):
        assert code.count('["latest"] = { ref = "' + VERSION + '" }') == 3

    @pytest.mark.static
    def test_no_cn_mirror_invented(self, code):
        assert "gitcode.com/xlings-res" not in code
        assert "ci = {" not in code

    @pytest.mark.static
    def test_install_handles_both_archive_layouts(self, code):
        """POSIX tarballs carry package/bin/esbuild, win32 ones package/esbuild.exe."""
        assert '"esbuild.exe"' in code
        assert 'path.join("bin", exe)' in code
        assert 'os.isfile(staged)' in code


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_esbuild_version(self):
        assert_command_output("esbuild --version", contains=VERSION)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_esbuild(self):
        assert_xvm_registered("esbuild")
