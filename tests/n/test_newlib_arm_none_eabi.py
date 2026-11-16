"""测试 newlib-arm-none-eabi 包"""
import os
import re
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, project_root, xpkgs_dir

PKG = "newlib-arm-none-eabi"
PKG_FILE = "pkgs/n/newlib-arm-none-eabi.lua"

# CubeMX 生成的工程用 `--specs=nano.specs --specs=nosys.specs` 链接; 下面这些名字
# 是 Arm GNU Toolchain 的, 少一个那样的工程就链不上。
NANO_NAMES = ["libc_nano.a", "libg_nano.a", "librdimon_nano.a"]
SPECS = ["nano.specs", "nosys.specs", "rdimon.specs"]


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


def multilibs(source_text):
    body = re.search(r'local multilibs = \{(.*?)\n\}', source_text, re.S).group(1)
    return re.findall(r'"([^"]+)"', body)


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
    def test_one_version_table_for_every_host(self, source_text):
        """载荷是目标代码, 与宿主无关 ⇒ 三个平台共用同一张版本表."""
        for os_name in ("linux", "macosx", "windows"):
            assert f"{os_name} = versions" in source_text, f"{os_name} 没有用共享的版本表"

    @pytest.mark.static
    def test_multilibs_are_rmprofile(self, source_text):
        """multilib 表必须是 arm-none-eabi-gcc (rmprofile) 的全部行, 含默认的 `.`."""
        rows = multilibs(source_text)
        assert rows[0] == ".", "缺默认 multilib `.`"
        for row in ("thumb/v6-m/nofp", "thumb/v7-m/nofp", "thumb/v7e-m+fp/hard",
                    "thumb/v7e-m+fp/softfp", "thumb/v8-m.main+fp/hard"):
            assert row in rows, f"multilib 表缺 {row}"
        assert len(rows) == len(set(rows)), "multilib 表有重复行"

    @pytest.mark.static
    def test_install_asserts_arm_toolchain_names(self, source_text):
        for name in NANO_NAMES:
            assert f'"{name}"' in source_text, f"install 不检查 {name}"
        for specs in SPECS:
            assert f'"lib/{specs}"' in source_text, f"install 不检查 {specs}"

    @pytest.mark.static
    def test_target_headers_do_not_enter_the_host_sysroot(self, source_text):
        assert "subos_sysrootdir" not in source_text, "目标头绝不能发布进 subos sysroot"
        assert "xvm.files" not in source_text, "目标头绝不能声明成 subos 文件"

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
    def test_hard_and_soft_float_are_not_the_same_library(self):
        """⚠️ 同一 march 的 softfp 与 hard 必须是两份不同的 libc_nano.a.

        塌成一个目录时构建期什么都不报, 硬浮点的库被链进软浮点程序。
        """
        roots = [d for d in os.listdir(xpkgs_dir()) if d.endswith("-x-newlib-arm-none-eabi")]
        assert roots, "载荷未落盘"
        base = os.path.join(xpkgs_dir(), roots[0])
        lib = os.path.join(base, sorted(os.listdir(base))[-1], "arm-none-eabi", "lib")
        for march in ("thumb/v7e-m+fp", "thumb/v8-m.main+fp"):
            a = open(os.path.join(lib, march, "softfp", "libc_nano.a"), "rb").read()
            b = open(os.path.join(lib, march, "hard", "libc_nano.a"), "rb").read()
            assert a != b, f"{march} 的 softfp 与 hard 是同一份 libc_nano.a"
