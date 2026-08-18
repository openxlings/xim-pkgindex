"""测试 picolibc-riscv 包"""
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

PKG = "picolibc-riscv"
PKG_FILE = "pkgs/p/picolibc-riscv.lua"

# 载荷带的档位, 以及每个档位必须齐的东西。这张表就是包的契约:
# 少一个 profile 或少一个文件, 用户第一次裸机构建才会发现。
PROFILES = [("rv64gc", "lp64d", "riscv64"), ("rv32imac", "ilp32", "riscv32")]
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
        """载荷是目标代码, 与宿主无关 ⇒ 三个平台必须是同一个 sha256.

        写成 per-arch 表会让镜像工具把它当成有架构区分的资产, 并去抓根本
        不存在的第二个 URL。
        """
        import re
        hashes = set(re.findall(r'sha256 = "([0-9a-f]{64})"', source_text))
        assert len(hashes) == 1, f"期望全平台同一个 sha256, 实际 {len(hashes)} 个"
        assert source_text.count("sha256 =") == 3, "linux/macosx/windows 各一条"

    @pytest.mark.static
    def test_install_hook_checks_the_builtins(self, source_text):
        """install 必须断言 libclang_rt.builtins 在位.

        这是这个 artifact 存在的理由: picolibc 的 printf 走 ryu 浮点格式化,
        要 128 位移位, rv64 没有对应指令 ⇒ 没有 builtins 就 __ashlti3 /
        __lshrti3 未定义。⚠️ 常见的「测一下 64 位除法」根本碰不到这条 ——
        rv64gc 有硬件 divu。
        """
        assert 'libclang_rt.builtins-' in source_text, \
            "install hook 不再检查 builtins"
        for _, _, arch in PROFILES:
            assert f'arch = "{arch}"' in source_text, f"profiles 表缺 {arch}"

    @pytest.mark.static
    def test_target_headers_do_not_enter_the_host_sysroot(self, source_text):
        """⚠️ 这些是 riscv*-none-elf 的**目标**头, 不是宿主库的头.

        照 zlib.lua 那样往 subos 的 usr/include 里拷 = 让每个普通构建的
        宿主 libc 被 riscv 的头遮住。config() 只能注册 umbrella 节点。
        """
        assert "subos_sysrootdir" not in source_text, \
            "目标头绝不能发布进 subos sysroot"
        assert "xvm.files" not in source_text, \
            "目标头绝不能声明成 subos 文件"

    @pytest.mark.static
    def test_no_auto_update_or_self_mirror(self, source_text):
        """版本 bump 要重新构建, 不是重新下载; 而且 GLOBAL 已经是 xlings-res.

        `update = true` 会把 latest 指向一个还不存在的 URL;
        `mirror = true` 会让镜像镜像它自己。
        """
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
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_both_profiles_landed_complete(self):
        """两个档位都要齐, 而不是只有被验收用例用到的那个.

        一个只解出 rv64 的 install 会让 rv64 的验收全绿, 而 rv32 用户在
        第一次链接时才发现包是半个。
        """
        roots = [d for d in os.listdir(xpkgs_dir())
                 if d.endswith("-x-picolibc-riscv")]
        assert roots, "载荷未落盘"
        base = os.path.join(xpkgs_dir(), roots[0])
        version = sorted(os.listdir(base))[-1]
        root = os.path.join(base, version)

        for march, mabi, arch in PROFILES:
            libdir = os.path.join(root, "lib", march, mabi)
            incdir = os.path.join(root, "include", march, mabi)
            for name in REQUIRED_LIB_FILES + [f"libclang_rt.builtins-{arch}.a"]:
                assert os.path.isfile(os.path.join(libdir, name)), \
                    f"缺 lib/{march}/{mabi}/{name}"
            assert os.path.isfile(os.path.join(incdir, "stdio.h")), \
                f"缺 include/{march}/{mabi}/stdio.h"
