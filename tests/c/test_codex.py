"""测试 codex 包"""
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

PKG = "codex"
PKG_FILE = "pkgs/c/codex.lua"

# 上游为每个 target 构建的六个三元组
TARGETS = [
    "x86_64-unknown-linux-musl", "aarch64-unknown-linux-musl",
    "x86_64-apple-darwin", "aarch64-apple-darwin",
    "x86_64-pc-windows-msvc", "aarch64-pc-windows-msvc",
]


def lua_code(path=PKG_FILE):
    """去掉 `--` 行注释后的配方正文

    注释里会引用 npm 包名和 `codex-<target>` 这个不该用的裸二进制来解释
    为什么不那么做，直接扫全文会把说明本身当成违规。
    """
    content = open(path, encoding='utf-8').read()
    return re.sub(r'--[^\n]*', '', content)


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


class TestDesign:
    @pytest.mark.static
    def test_all_platforms_declared(self, meta):
        """三平台都要声明 —— 上游对每个平台都发 codex-package"""
        for plat in ("linux", "windows", "macosx"):
            assert meta.platforms.get(plat), f"xpm 缺少 {plat} 平台"

    @pytest.mark.static
    def test_native_binary_not_npm(self):
        """原生发布包，不再经由 npm 安装"""
        code = lua_code()
        assert "github.com/openai/codex/releases/download" in code
        assert "npm install" not in code
        assert "@openai/codex" not in code
        assert "node_modules" not in code
        # node/npm 曾是 xpm.<platform>.deps
        assert '"node", "npm"' not in code

    @pytest.mark.static
    def test_all_six_targets_covered(self):
        """六个 target 一个都不能少"""
        code = lua_code()
        for t in TARGETS:
            assert t in code, f"缺少 target {t}"

    @pytest.mark.static
    def test_uses_the_package_asset_not_the_bare_binary(self):
        """必须用 codex-package-*，不能用裸 codex-<target>

        裸二进制没有 codex-path/rg、codex-resources/{bwrap,zsh}，装出来的
        codex 能过 --version 但用起来是残的。
        """
        code = lua_code()
        assert re.search(r'"codex-package-"\s*\.\.', code), "asset 名必须是 codex-package-<target>"
        for t in TARGETS:
            # 不能出现直接拼裸二进制名的写法
            assert not re.search(r'"codex-"\s*\.\.\s*target', code)

    @pytest.mark.static
    def test_keeps_the_whole_package_layout(self):
        """整包搬运，不挑出 entrypoint

        codex 通过 codex-package.json 在运行时定位 codex-path / codex-resources。
        """
        code = lua_code()
        for entry in ("bin", "codex-path", "codex-resources", "codex-package.json"):
            assert '"%s"' % entry in code, f"_PAYLOAD 缺少 {entry}"
        assert "codex-package.json" in code
        # 装完必须校验 entrypoint 和 layout 描述文件都在
        assert re.search(r'raise\(', code), "install() 必须在 payload 不完整时 raise"

    @pytest.mark.static
    def test_no_os_exists_in_hooks(self):
        """`os.exists` 在 xim hook runtime 里没有绑定

        调用它会让 install 以 `attempt to call a nil value (field 'exists')`
        失败,而现象是安装目录里只剩一个 `.xpkg.lua`、没有 payload。
        问两次 `os.isdir` / `os.isfile` 代替。
        """
        code = lua_code()
        assert "os.exists(" not in code, \
            "os.exists 在 hook runtime 不可用, 用 os.isdir/os.isfile"

    @pytest.mark.static
    def test_no_deps_needed(self):
        """linux 是 musl target 且 Rust 静态链接，不需要任何 libc 依赖"""
        code = lua_code()
        assert not re.search(r'^\s*deps\s*=', code, re.M), \
            "codex 是 static-pie 的自包含二进制, 不应声明 deps"

    @pytest.mark.static
    def test_cn_mirror_present(self):
        """CN 加速镜像必须覆盖 latest 指向的版本的三个平台"""
        code = lua_code()
        assert "gitcode.com/xlings-res/codex" in code
        refs = set(re.findall(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"', code))
        assert len(refs) == 1, f"三平台 latest.ref 不一致: {refs}"
        latest = refs.pop()
        mirrored = re.findall(
            r'\["%s"\]\s*=\s*_(?:linux|macosx|windows)\([^)]*,\s*true\)' % re.escape(latest),
            code)
        assert len(mirrored) == 3, \
            f"latest={latest} 应在三个平台都开启 CN 镜像, 实际 {len(mirrored)}"

    @pytest.mark.static
    def test_every_version_has_six_checksums(self):
        """每个版本 × 每个平台 × 每个架构都要有 sha256"""
        code = lua_code()
        versions = set(re.findall(r'\["(\d+\.\d+\.\d+)"\]\s*=\s*_(?:linux|macosx|windows)\(', code))
        assert versions, "没有解析到版本条目"
        shas = re.findall(r'"[0-9a-f]{64}"', code)
        assert len(shas) == len(versions) * 6, \
            f"{len(versions)} 个版本应有 {len(versions) * 6} 个 sha256, 实际 {len(shas)}"


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG, timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_codex_version(self):
        assert_command_output("codex --version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_codex(self):
        assert_xvm_registered("codex")
