"""测试 probe-rs 包"""
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

PKG = "probe-rs"
PKG_FILE = "pkgs/p/probe-rs.lua"

# 上游的资产名是 Rust 目标三元组, 与 xlings 的 linux/macosx/windows 没有任何
# 重叠 —— 所以配方把整条三元组直接写进 `arch_alias`, 而不是派生. 把它们钉在
# 这里, 是为了让一次静默改名(或掉一个平台)变成测试失败, 而不是变成某台 CI
# 手里没有的机器上的一个 404.
EXPECTED_TRIPLE = {
    "linux":   {"x86_64": "x86_64-unknown-linux-gnu",
                "aarch64": "aarch64-unknown-linux-gnu"},
    "macosx":  {"x86_64": "x86_64-apple-darwin",
                "aarch64": "aarch64-apple-darwin"},
    "windows": {"x86_64": "x86_64-pc-windows-msvc"},
}


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
    def test_every_host_target_has_both_mirrors(self, source_text):
        """五个宿主目标 × 两个镜像 = 十条 URL, 一条不少.

        少一条 = 那台机器上一个 404, 而 CI 只跑 Linux/x86_64 的 GLOBAL 一格,
        所以另外九格只能靠断言守.
        """
        for platform, by_arch in EXPECTED_TRIPLE.items():
            for arch, triple in by_arch.items():
                ext = "zip" if platform == "windows" else "tar.xz"
                asset = f"probe-rs-tools-{triple}.{ext}"
                for mirror, host in (("GLOBAL", "github.com/probe-rs/probe-rs"),
                                     ("CN", "gitcode.com/xlings-res/probe-rs")):
                    assert f"{host}/releases/download/" in source_text, \
                        f"{mirror} 的主机名不对"
                    assert asset in source_text, (
                        f"{platform}/{arch} 的资产 {asset} 不在配方里")

    @pytest.mark.static
    def test_windows_declares_no_arm64_asset(self, source_text):
        """上游不发 win32-arm64. 声明它 = 把 x64 归档喂给 arm64 主机."""
        windows_block = source_text.split("windows = {", 1)[1].split("},\n    },", 1)[0]
        assert "aarch64" not in windows_block, (
            "windows 段声明了 aarch64, 但上游没有 win32-arm64 资产")

    @pytest.mark.static
    def test_install_moves_programs_into_bin(self, source_text):
        """⭐⭐ 程序必须落到 bin/ 下, 而上游把它们放在归档根上.

        mcpp 的 runner 查找先看 `<payload>/bin`, 再看 PATH. 板级包写
        `mcpp::runner("probe-rs")` 就是要从这份载荷里解析到它 —— 这正是「写
        程序名而不是拼路径」买到的东西. 载荷若按解包原样留着, 查找会静默落到
        PATH, 捡到那里恰好有的 shim 或系统副本.
        """
        assert 'os.mkdir(bindir)' in source_text, "install 没有建立 bin/"
        assert 'path.join(bindir, prog .. exe)' in source_text, \
            "install 没有把程序移进 bin/"
        assert 'raise("probe-rs payload is missing bin/probe-rs"' in source_text, \
            "install 没有断言 bin/probe-rs 存在, 布局变化会晚很多才现形"

    @pytest.mark.static
    def test_install_handles_the_flat_windows_archive(self, source_text):
        """⚠️⚠️ 两种归档形状不同, 而只有 Windows 那台机器看得见.

        `.tar.xz` 解到 `probe-rs-tools-<triple>/` 下; Windows 的 `.zip` 是
        **平的** —— `probe-rs.exe` 直接躺在解包目录里, 没有外层目录. 按 tar
        形状写的 install 在 Windows 上死于
        `no directory contains probe-rs.exe`, CI 只有 Windows runner 报得出来.

        所以 payload_root 回答的是「哪个目录**装着**这个程序」—— 两种形状都有
        答案 —— 而 install 搬**文件**不搬目录: 平形状下那个目录是共享的解包根,
        搬走它会连别的包的文件一起搬走.
        """
        assert 'if os.isfile(path.join(base, exe)) then' in source_text, \
            "payload_root 不认平铺的 Windows 归档"
        assert 'os.mv(from, path.join(bindir, prog .. exe))' in source_text, \
            "install 搬的是目录而不是文件, 平形状下会连累共享解包根"

    @pytest.mark.static
    def test_mirror_tag_prefix(self, source_text):
        """上游 tag 带 `v`, xlings-res tag 是裸版本号 —— 两边不能抄错.

        抄错的后果是 CN 用户 404, 而 CI 只跑 GLOBAL, 永远看不到.
        """
        for line in source_text.splitlines():
            stripped = line.strip()
            if stripped.startswith("GLOBAL ="):
                assert "/releases/download/v0.32.0/" in stripped, \
                    f"上游 tag 少了 v 前缀: {stripped}"
            if stripped.startswith("CN ="):
                assert "/releases/download/0.32.0/" in stripped, \
                    f"镜像 tag 不该有 v 前缀: {stripped}"

    @pytest.mark.static
    def test_only_probe_rs_is_registered(self, meta):
        """归档还带 cargo-embed / cargo-flash, 它们是 Cargo 子命令.

        注册它们等于把两个 cargo-* 名字放到 PATH 上, 而这个索引里没有任何
        东西能驱动它们.
        """
        assert meta.programs == ["probe-rs"], (
            f"programs 应当只有 probe-rs, 实际是 {meta.programs}")


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
    def test_version(self):
        assert_command_output("probe-rs --version", contains="probe-rs")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_shim(self):
        assert_xvm_shim_exists("probe-rs")
