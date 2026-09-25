"""测试 vcpkg 包"""
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

PKG = "vcpkg"
PKG_FILE = "pkgs/v/vcpkg.lua"


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
    def test_every_arch_has_a_checksum(self, meta):
        """每个平台声明的每个架构都必须有 sha256 -- 多镜像资源服务惯例
        (xpkg-creater §1.2.1): 缺一个架构就是缺一次校验, fail-closed。
        """
        content = meta.raw_content
        for plat in ("linux", "macosx", "windows"):
            import re
            m = re.search(
                rf'{plat}\s*=\s*\{{.*?\["2026\.7\.27"\]\s*=\s*\{{(.*?)\}},?\s*\}},',
                content, re.DOTALL)
            assert m, f"未找到 {plat} 的 2026.7.27 版本条目"
            block = m.group(1)
            shas = re.findall(r'=\s*"([0-9a-fA-F]{64})"', block)
            assert len(shas) >= 2, f"{plat}: 每个受支持架构都应有各自的 sha256, 实际找到 {len(shas)} 个"


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
    def test_vcpkg_version(self):
        assert_command_output("vcpkg version", contains="vcpkg package management program version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_vcpkg(self):
        assert_xvm_registered("vcpkg")
