"""测试 xlings 包"""
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

PKG = "xlings"
INSTALL_PKG = "local:xlings@0.4.51"
PKG_FILE = "pkgs/x/xlings.lua"


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
    def test_recent_versions_use_xlings_res(self, meta):
        # Version-agnostic: the `latest` ref (whatever it currently is) must map
        # to an XLINGS_RES entry in every platform block, and a few stable
        # historical versions stay XLINGS_RES. Avoids going stale on each bump.
        def platform_block(platform, next_platform):
            start = meta.raw_content.index(f"        {platform} = {{")
            if next_platform is None:
                return meta.raw_content[start:]
            end = meta.raw_content.index(f"        {next_platform} = {{", start)
            return meta.raw_content[start:end]

        stable_versions = ("0.4.44", "0.4.43", "0.4.42", "0.4.41", "0.4.40")
        for platform, next_platform in (("linux", "macosx"), ("macosx", "windows"), ("windows", None)):
            block = platform_block(platform, next_platform)
            m = re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([0-9.]+)"\s*\}', block)
            assert m, f"no `latest` ref in {platform} block"
            latest = m.group(1)
            assert re.search(rf'\["{re.escape(latest)}"\]\s*=\s*"XLINGS_RES"', block)
            for version in stable_versions:
                assert re.search(rf'\["{re.escape(version)}"\]\s*=\s*"XLINGS_RES"', block)


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
        assert_install_succeeds(INSTALL_PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xlings(self):
        assert_command_output(
            "xlings use xlings@0.4.51 >/dev/null && xlings --version 2>&1 | head -1",
            contains="xlings 0.4.51",
        )
