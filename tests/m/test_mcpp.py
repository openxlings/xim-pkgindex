"""测试 mcpp 包"""
import re
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not

PKG = "mcpp"
INSTALL_PKG = "local:mcpp@0.0.52"
PKG_FILE = "pkgs/m/mcpp.lua"


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
    def test_latest_0052_uses_xlings_res(self, meta):
        # 0.0.x mcpp assets are distributed through the XLINGS_RES mirrors.
        def platform_block(platform, next_marker):
            start = meta.raw_content.index(f"        {platform} = {{")
            end = meta.raw_content.index(next_marker, start)
            return meta.raw_content[start:end]

        platforms = (
            ("linux", "        macosx = {"),
            ("macosx", "        windows = {"),
            ("windows", "\n        },\n    },"),
        )
        for platform, next_marker in platforms:
            block = platform_block(platform, next_marker)
            assert re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"0\.0\.52"\s*\}', block)
            assert re.search(r'\["0\.0\.52"\]\s*=\s*"XLINGS_RES"', block)

    @pytest.mark.static
    def test_install_uses_runtime_dir(self, meta):
        assert "path.directory(archive)" in meta.raw_content
        assert "path.filename(mcpp_dir)" in meta.raw_content


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
        assert_install_succeeds(INSTALL_PKG, timeout=420)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_mcpp(self):
        assert_command_output("xlings use mcpp local:0.0.52 >/dev/null && mcpp --version", contains="mcpp 0.0.52")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_mcpp_shim(self):
        assert_xvm_shim_exists("mcpp")
