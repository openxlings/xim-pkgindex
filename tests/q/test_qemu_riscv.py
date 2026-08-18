"""测试 qemu-riscv 包"""
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

PKG = "qemu-riscv"
PKG_FILE = "pkgs/q/qemu-riscv.lua"

# xPack's asset spelling per platform. The recipe carries these as `arch_alias`
# plus a platform-scope `source`; pinning them here is what makes a silent
# rename (or a dropped platform) a test failure instead of a 404 at install
# time on a machine nobody in CI is holding.
EXPECTED_ASSET_ARCH = {"x86_64": "x64", "aarch64": "arm64"}
EXPECTED_OS_TOKEN = {"linux": "linux", "macosx": "darwin", "windows": "win32"}


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    from tests.lib.platform_utils import project_root
    import os
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
    def test_upstream_os_token_per_platform(self, source_text):
        """每个平台的 source 必须用 xPack 自己的 OS 拼写, 不是 xlings 的.

        xlings 说 macosx/windows, xPack 说 darwin/win32. 三个平台共用一个根
        source 会让 macOS 和 Windows 静默 404 —— 而 CI 只跑 Linux, 所以这
        条只能靠断言守, 跑不出来.
        """
        for platform, token in EXPECTED_OS_TOKEN.items():
            marker = f"xpack-qemu-riscv-${{version}}-{token}-"
            assert marker in source_text, (
                f"{platform} 的 source 缺少 xPack 的 OS 拼写 '{token}': "
                f"期望包含 {marker}")

    @pytest.mark.static
    def test_arch_alias_maps_to_xpack_spelling(self, source_text):
        """arch_alias 必须把 x86_64/aarch64 映射到 xPack 的 x64/arm64."""
        for canonical, alias in EXPECTED_ASSET_ARCH.items():
            assert f'{canonical} = "{alias}"' in source_text, (
                f"缺少 arch_alias {canonical} -> {alias}")

    @pytest.mark.static
    def test_windows_declares_no_arm64_asset(self, source_text):
        """xPack 不发 win32-arm64. 声明它 = 把 x64 归档喂给 arm64 主机.

        archs 是跨平台的并集, 架构解析 fail-closed, 所以 windows 段只能有
        x86_64 一个 sha256.
        """
        windows_block = source_text.split("windows = {", 1)[1]
        assert "aarch64" not in windows_block.split("},\n    },", 1)[0], (
            "windows 段声明了 aarch64, 但 xPack 没有 win32-arm64 资产")


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
        # 解包后 365MB (bin + libexec 51 个库 + share/qemu 固件), 默认 180s 不够
        assert_install_succeeds(PKG, timeout=900)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_version(self):
        assert_command_output("qemu-system-riscv64 --version",
                              contains="QEMU emulator version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_both_emulators_get_a_shim(self):
        """两个 program 都要落 shim, 不只是被 --version 摸到的那个.

        用 shim 落盘而不是 `xvm info`: 后者在某些 home 上对**任何**包都只回
        Runtime Tips (2026-08-19 实测, ninja 这种长期可用的包同样挂), 那是
        环境条件, 不是包未注册 —— 拿它当判据会把环境问题读成业务否定.
        """
        for prog in ("qemu-system-riscv64", "qemu-system-riscv32"):
            assert_xvm_shim_exists(prog)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_boots_firmware_through_the_shim(self):
        """真跑一次, 而不是只问版本.

        `--version` 对这个包证明不了任何有用的东西: 它不加载 opensbi, 不解析
        `share/qemu` 的 datadir, 也不碰 `$ORIGIN/../libexec` 里那 51 个共享库.
        一个只搬了两个可执行文件的 install hook 会让 `--version` 通过, 然后在
        第一次真启动时死掉.

        判据两侧都钉过 (2026-08-19, xpack 9.2.4-1):
          * 固件在位  -> 打印 `OpenSBI v1.5.1` banner;
          * 把 share/qemu/opensbi-riscv64-generic-fw_dynamic.bin 移走
            -> `Unable to find the RISC-V BIOS "..."`, 不再有 banner.
        所以 banner 出现 = datadir 解析对了且盘上的固件真的被执行了.

        (`-L /nonexistent` 不是有效对照: -L 是追加, 默认搜索路径仍在.)

        opensbi 起来后会一直等, 所以 timeout 与 head 一起把它收住.
        """
        assert_command_output(
            "timeout 10 qemu-system-riscv64 -machine virt -nographic "
            "-no-reboot -bios default 2>&1 | head -20",
            contains="OpenSBI")
