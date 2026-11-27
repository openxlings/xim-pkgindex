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
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "esbuild"
PKG_FILE = "pkgs/e/esbuild.lua"
VERSION = "0.28.2"
PREVIOUS_VERSION = "0.25.12"
PLATFORMS = [
    "linux-x64", "linux-arm64", "linux-ia32",
    "darwin-x64", "darwin-arm64",
    "win32-x64", "win32-arm64", "win32-ia32",
]
PINNED_SHA256_0_28_2 = {
    "9573bb2233aab0f9ea7647d5cca9726113cc1768de61d66b17267f4db84488f6",
    "a96dbfa41d3ef5dbd1ef22b1c10d5187be9267e86093a870f06402a7ec931596",
    "47540b6a8fce26aac6559630dc232f83fe20642e87f1f1fab47512f0ea425084",
    "abb6a7a895aaf2cc0df36fecc3bf0042479ffec51a643a056d54e9109f27db55",
    "1980cde09749094452b20d36ff267585ccb3f72749c7bc97291cd9996ccf5a2a",
    "7286c3611b6f1f4c4d9ec90adcbc478407ff0d28ead96567f361d53e67613e19",
    "b3cffeaa165134f7da679c8619266953afd5f41641a254615a57e757f67c7336",
    "e05a9b0cb0c9c6facfb02222d00064dd37baf5c1163f6c0eea936cb93f87a011",
}


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
        for ver in (VERSION, PREVIOUS_VERSION):
            urls = re.findall(
                r'registry\.npmjs\.org/@esbuild/([a-z0-9-]+)/-/\1-' + re.escape(ver) + r'\.tgz',
                code,
            )
            assert sorted(urls) == sorted(PLATFORMS), (ver, urls)
        hashes = re.findall(r'sha256 = "([0-9a-f]{64})"', code)
        assert len(hashes) == 16 and len(set(hashes)) == 16, "sixteen tarballs across two versions, sixteen hashes"
        assert PINNED_SHA256_0_28_2.issubset(set(hashes)), "0.28.2 pinned sha256s missing"

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
        assert 'fs.is_file(staged)' in code


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(under_test(PKG, VERSION))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_esbuild_version(self):
        assert_command_output("esbuild --version", contains=VERSION)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_esbuild(self):
        assert_xvm_registered("esbuild")
