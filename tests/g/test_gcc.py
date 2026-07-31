"""测试 gcc 包"""
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

PKG = "gcc"
PKG_FILE = "pkgs/g/gcc.lua"


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


class TestSubosPath:
    """gcc 记录到 xvm 的 subos 路径必须是可移植写法。

    xvm 版本库是**整个 home 共享**的一份，而 sysroot 是 per-subos 的。写死安装
    那一刻活动的 subos，对装 gcc 的那个 subos 正确、对其余全部错误 —— 用户切了
    subos，g++ 还在对着旧的头文件编译。写 `subos/current`（`self init` 建立、
    `subos use --global` 维护的 symlink）不需要占位符也不需要新字段。

    LINK 轴（loader/rpath，写进 payload 的 specs）方向相反：payload 全 home 共享
    且可以被绕过 shim 直接调用，所以那里**不许**出现 subos 路径。两条轴一起断言，
    否则改对一条会掩盖另一条。
    """

    @pytest.mark.static
    def test_alias_sysroot_uses_the_marker(self):
        src = open(PKG_FILE, encoding='utf-8').read()
        assert '${XLINGS_DYNAMIC_SUBOS_DIR}' in src, (
            "alias 的 --sysroot 必须写 xlings 的 marker；"
            "写死活动 subos 会让其他 subos 里的 g++ 用错头文件"
        )
        # marker 必须真的进了 alias，而不是只出现在注释里
        assert "alias_args = ' --sysroot=${XLINGS_DYNAMIC_SUBOS_DIR}'" in src

    @pytest.mark.static
    def test_alias_does_not_bake_a_concrete_subos(self):
        """subos_sysrootdir() 求值出的是**当前**活动 subos —— 它可以用于物化
        （往那棵树里装东西），但绝不能进 alias：alias 存在共享的版本库里。"""
        src = open(PKG_FILE, encoding='utf-8').read()
        alias_region = src.split('-- HEADER axis')[-1].split('xvm.add("xim-gnu-gcc"')[0]
        assert 'subos_sysrootdir' not in alias_region, (
            "alias 区域不得出现 subos_sysrootdir()：那会把安装时的 subos 烧进"
            "一个所有 subos 共享的记录里"
        )

    @pytest.mark.static
    def test_specs_rewrite_stays_payload_direct(self):
        src = open(PKG_FILE, encoding='utf-8').read()
        # specs 走 rpath + 动态链接器，两者都必须指向 payload
        assert 'pkginfo.install_dir(), "lib64"' in src, (
            "specs 的 rpath 必须是 payload-direct"
        )
        assert 'subos_sysrootdir' not in src.split('__rewrite_specs_linux')[-1], (
            "specs 重写路径里不得出现 subos —— payload 是全 home 共享的，"
            "而且直接调用 <install_dir>/bin/gcc 时根本不经过任何 subos"
        )


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_gcc(self):
        assert_command_output("gcc --version | head -1", contains="gcc")

