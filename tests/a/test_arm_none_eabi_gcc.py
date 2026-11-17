"""测试 arm-none-eabi-gcc 包"""
import os
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, project_root

PKG = "arm-none-eabi-gcc"
PKG_FILE = "pkgs/a/arm-none-eabi-gcc.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


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
    def test_every_program_is_target_prefixed(self, meta):
        """所有命令都带 `arm-none-eabi-` 前缀: 一个裸 `gcc`/`ld` 会盖掉宿主工具链."""
        for prog in meta.programs:
            assert prog.startswith("arm-none-eabi-"), f"{prog} 没有目标前缀"

    @pytest.mark.static
    def test_no_c_library_in_the_compiler(self, source_text):
        """C 库与 libstdc++ 是独立的包; 编译器包不依赖、也不登记任何 C 库."""
        for libc in ("newlib", "picolibc", "libstdcxx"):
            assert f'"xim:{libc}' not in source_text, f"编译器包不应依赖 {libc}"
        assert "subos_sysrootdir" not in source_text, "目标头/库绝不能进 subos sysroot"


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
        assert_install_succeeds(PKG, timeout=900)
