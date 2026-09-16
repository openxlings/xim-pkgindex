"""测试 pnpm 包"""
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

PKG = "pnpm"
PKG_FILE = "pkgs/p/pnpm.lua"
PNPM7_VERSION = "7.33.7"
PNPM7_ASSETS = {
    "pnpm-linux-x64": "ee39e4fc291bd83a0cdf2087cc9de29c0ff7a7999edff845959ca08483f0cca0",
    "pnpm-macos-arm64": "0e33b74ca8e2407e07f8be499e7e36531e239b81a627396f559e48270a0c012f",
    "pnpm-win-x64.exe": "3c1329114beedf8a3882acdd7c7bd99153afb685fc6ac34ec54a6eb69cf721f6",
}


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


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
    def test_pnpm7_assets(self, meta):
        for asset, sha256 in PNPM7_ASSETS.items():
            url = f"https://github.com/pnpm/pnpm/releases/download/v{PNPM7_VERSION}/{asset}"
            assert url in meta.raw_content
            assert sha256 in meta.raw_content

    @pytest.mark.static
    def test_latest_stays_on_current_major(self, meta):
        refs = re.findall(
            r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"\s*\}',
            meta.raw_content,
        )
        assert len(refs) == 3
        assert len(set(refs)) == 1
        assert int(refs[0].split(".", 1)[0]) > 7

    @pytest.mark.static
    def test_pnpm7_skips_elfpatch(self, meta):
        assert re.search(
            r'if pkginfo\.version\(\) == "7\.33\.7" then.*?elfpatch\.skip\(\)',
            meta.raw_content,
            re.DOTALL,
        )


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(f"{PKG}@7", timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_pnpm(self):
        assert_command_output("pnpm --version", contains=PNPM7_VERSION)
