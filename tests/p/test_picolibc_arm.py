"""测试 picolibc-arm 包"""
import os
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, project_root, xpkgs_dir

PKG = "picolibc-arm"
PKG_FILE = "pkgs/p/picolibc-arm.lua"

# ⭐⭐ 七个档位, 按**三元组**索引 —— 这是这个包与它三个兄弟唯一形状不同的地方。
#
# riscv 的 `mabi` 就是浮点 ABI(`lp64d` 与 `lp64` 是两个值), 所以
# `<march>/<mabi>` 能分开每一档。ARM 的 `mabi` 是过程调用标准, 两个变体都是
# `aapcs`, 浮点 ABI 在三元组的 `eabi`/`eabihf` 后缀里。实测:按兄弟的约定,
# 七个档位塌成五个目录, 而 `armv7e-m/aapcs/libc.a` 带着 `Tag_ABI_HardFP_use`
# —— 硬浮点的构建, 恰好坐在软浮点那一行会去找它的位置上。构建期什么都没报。
PROFILES = [
    ("thumbv6m-none-eabi",        "thumbv6m"),
    ("thumbv7m-none-eabi",        "thumbv7m"),
    ("thumbv7em-none-eabi",       "thumbv7em"),
    ("thumbv7em-none-eabihf",     "thumbv7em"),
    ("thumbv8m.base-none-eabi",   "thumbv8m.base"),
    ("thumbv8m.main-none-eabi",   "thumbv8m.main"),
    ("thumbv8m.main-none-eabihf", "thumbv8m.main"),
]
REQUIRED_LIB_FILES = ["libc.a", "libm.a", "libsemihost.a", "crt0-semihost.o",
                      "picolibc.ld", "picolibcpp.ld"]


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
    def test_one_hash_for_every_host(self, source_text):
        """载荷是目标代码, 与宿主无关 ⇒ 三个平台必须是同一个 sha256."""
        import re
        hashes = set(re.findall(r'sha256 = "([0-9a-f]{64})"', source_text))
        assert len(hashes) == 1, f"期望全平台同一个 sha256, 实际 {len(hashes)} 个"
        assert source_text.count("sha256 =") == 3, "linux/macosx/windows 各一条"

    @pytest.mark.static
    def test_every_profile_is_keyed_by_triple(self, source_text):
        """⚠️⚠️ 七个档位都必须以**三元组**为键, 一个不少.

        少一个 = 那一行的用户第一次链接才发现包是残的; 而用
        `<march>/<mabi>` 做键 = 软硬浮点静默互相覆盖, 构建期毫无迹象。
        """
        for triple, _ in PROFILES:
            assert f'triple = "{triple}"' in source_text, f"profiles 表缺 {triple}"
        assert 'path.join(dir, "lib", p.triple)' in source_text, \
            "install 不是按三元组找 lib 目录"
        assert "p.march" not in source_text and "p.mabi" not in source_text, \
            "还在用 <march>/<mabi> 做键, 软硬浮点会互相覆盖"

    @pytest.mark.static
    def test_install_hook_checks_the_builtins(self, source_text):
        """install 必须断言 builtins 在位, 且按**消费者会要的名字**断言.

        compiler-rt 的架构识别根本不认 `thumb*` 三元组 —— 用
        `thumbv6m-none-eabi` 配出来的构建树里没有 builtins 目标, cmake 成功、
        ninja 报 "no work to do"。所以它以 `armv6m-none-eabi` 构建、产出
        `libclang_rt.builtins-armv6m.a`, 再以 mcpp 会索取的名字存进载荷。
        """
        assert 'libclang_rt.builtins-' in source_text, "install hook 不再检查 builtins"
        for _, arch in PROFILES:
            assert f'arch = "{arch}"' in source_text, f"profiles 表缺 {arch}"

    @pytest.mark.static
    def test_target_headers_do_not_enter_the_host_sysroot(self, source_text):
        """这些是 thumb*-none-eabi 的**目标**头, 不是宿主库的头."""
        assert "subos_sysrootdir" not in source_text, \
            "目标头绝不能发布进 subos sysroot"
        assert "xvm.files" not in source_text, \
            "目标头绝不能声明成 subos 文件"

    @pytest.mark.static
    def test_no_auto_update_or_self_mirror(self, source_text):
        """版本 bump 要重新构建, 不是重新下载; 而且 GLOBAL 已经是 xlings-res."""
        assert "mirror = true" not in source_text
        assert "update = true" not in source_text


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


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_all_seven_profiles_landed_complete(self):
        """七个档位都要齐, 而不是只有验收用例用到的那个.

        一个只解出 thumbv7m 的 install 会让验收全绿, 而 thumbv6m 的用户在
        第一次链接时才发现包是残的。
        """
        roots = [d for d in os.listdir(xpkgs_dir())
                 if d.endswith("-x-picolibc-arm")]
        assert roots, "载荷未落盘"
        base = os.path.join(xpkgs_dir(), roots[0])
        version = sorted(os.listdir(base))[-1]
        root = os.path.join(base, version)

        for triple, arch in PROFILES:
            libdir = os.path.join(root, "lib", triple)
            incdir = os.path.join(root, "include", triple)
            for name in REQUIRED_LIB_FILES + [f"libclang_rt.builtins-{arch}.a"]:
                assert os.path.isfile(os.path.join(libdir, name)), \
                    f"缺 lib/{triple}/{name}"
            assert os.path.isfile(os.path.join(incdir, "stdio.h")), \
                f"缺 include/{triple}/stdio.h"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_soft_and_hard_float_are_not_the_same_library(self):
        """⚠️⚠️ 同一个 march 的软硬浮点必须是两份**不同**的 libc.a.

        这是这个包按三元组索引的全部理由。塌成一个目录时构建期什么都不报,
        用户拿到的是带 `Tag_ABI_HardFP_use` 的库链进软浮点程序 —— 一次静默的
        ABI 替换。用字节比较而不是读 ELF 属性, 是因为前者不需要工具链。
        """
        roots = [d for d in os.listdir(xpkgs_dir())
                 if d.endswith("-x-picolibc-arm")]
        assert roots, "载荷未落盘"
        base = os.path.join(xpkgs_dir(), roots[0])
        version = sorted(os.listdir(base))[-1]
        root = os.path.join(base, version)

        for soft, hard in [("thumbv7em-none-eabi", "thumbv7em-none-eabihf"),
                           ("thumbv8m.main-none-eabi", "thumbv8m.main-none-eabihf")]:
            a = open(os.path.join(root, "lib", soft, "libc.a"), "rb").read()
            b = open(os.path.join(root, "lib", hard, "libc.a"), "rb").read()
            assert a != b, (
                f"{soft} 与 {hard} 的 libc.a 完全相同 —— 两档塌成了一份")
