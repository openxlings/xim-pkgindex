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
        def platform_block(platform, next_platform):
            start = meta.raw_content.index(f"        {platform} = {{")
            end = meta.raw_content.index(f"        {next_platform} = {{", start)
            return meta.raw_content[start:end]

        mirrored_versions = ("0.4.44", "0.4.43", "0.4.42", "0.4.41", "0.4.40")
        for platform, next_platform in (("linux", "macosx"), ("macosx", "windows")):
            block = platform_block(platform, next_platform)
            assert re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"0\.4\.44"\s*\}', block)
            for version in mirrored_versions:
                escaped = re.escape(version)
                assert re.search(rf'\["{escaped}"\]\s*=\s*"XLINGS_RES"', block)

        windows = meta.raw_content[meta.raw_content.index("        windows = {"):]
        assert re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"0\.4\.44"\s*\}', windows)
        for version in mirrored_versions:
            escaped = re.escape(version)
            assert re.search(rf'\["{escaped}"\]\s*=\s*"XLINGS_RES"', windows)


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
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xlings(self):
        assert_command_output("xlings --version 2>&1 | head -1", contains="xlings")
