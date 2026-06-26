"""测试 llvm-tools 包"""
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

PKG = "llvm-tools"
PKG_FILE = "pkgs/l/llvm-tools.lua"


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
    def test_supports_macosx_arm64(self, meta):
        # Apple Silicon slim bundle, mirroring llvm.lua's macOS-ARM64 source.
        macosx = re.search(r"macosx\s*=\s*\{(.*?)\n        \}", meta.raw_content, re.DOTALL)
        assert macosx, "missing macosx xpm block"
        body = macosx.group(1)
        assert "llvm-tools-20.1.7-macosx-arm64.tar.xz" in body, \
            "macosx must reference the macosx-arm64 bundle"
        assert "github.com/xlings-res/llvm" in body and "gitcode.com/xlings-res/llvm" in body, \
            "macosx must provide both GLOBAL and CN mirrors"
        assert "arm64" in meta.raw_content, "archs should include arm64"

    @pytest.mark.static
    def test_supports_22_1_8(self, meta):
        # 22.1.8 tools available on macOS + windows (carved from upstream);
        # linux 22.1.8 pending the maintainer slim-build pipeline.
        rc = meta.raw_content
        assert "llvm-tools-22.1.8-macosx-arm64.tar.xz" in rc, \
            "macosx must reference the 22.1.8 tools bundle"
        assert "llvm-tools-22.1.8-windows-x86_64.zip" in rc, \
            "windows must reference the 22.1.8 tools bundle"


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
    def test_clang_format(self):
        assert_command_output("clang-format --version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_clang_tidy(self):
        assert_command_output("clang-tidy --version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_clangd(self):
        assert_command_output("clangd --version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_llvm_tools(self):
        assert_xvm_registered("llvm-tools")
