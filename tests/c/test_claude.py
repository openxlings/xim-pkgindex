"""测试 claude-code 包"""
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

PKG = "claude"
PKG_FILE = "pkgs/c/claude.lua"


def lua_code(path=PKG_FILE):
    """去掉 `--` 行注释后的配方正文

    这个包的注释里会引用被禁止的写法（npm 包名、旧 deps 等）来解释为什么
    不再那么做；直接扫全文会把说明本身当成违规。
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
        """三平台都要声明 — 上游对每个平台都发原生二进制"""
        for plat in ("linux", "windows", "macosx"):
            assert meta.platforms.get(plat), f"xpm 缺少 {plat} 平台"

    @pytest.mark.static
    def test_native_binary_not_npm(self):
        """原生单可执行文件，不再经由 npm 安装"""
        code = lua_code()
        assert "downloads.claude.ai/claude-code-releases" in code
        assert "npm install" not in code
        assert "@anthropic-ai/claude-code" not in code
        # node/npm 曾是 xpm.<platform>.deps；原生二进制自带运行时
        assert '"node", "npm"' not in code

    @pytest.mark.static
    def test_no_runtime_deps_on_linux(self):
        """linux 不能声明 deps

        声明 xim:glibc 会让 xlings 的 predicate-driven elfpatch 找到 loader
        provider 并对二进制跑 patchelf。claude 是 Bun single-file
        executable，JS payload 追加在 ELF 之后，patchelf 重写节表会让
        payload 失联 —— `claude --version` 直接 SIGSEGV。
        """
        assert not re.search(r'^\s*deps\s*=', lua_code(), re.M), \
            "claude 不能声明 deps: elfpatch 会破坏 Bun 单文件可执行程序"

    @pytest.mark.static
    def test_cn_mirror_present(self):
        """CN 加速镜像必须覆盖 latest 指向的版本的每个平台/架构"""
        content = open(PKG_FILE, encoding='utf-8').read()
        assert "gitcode.com/xlings-res/claude" in content
        refs = set(re.findall(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"', content))
        assert len(refs) == 1, f"三平台 latest.ref 不一致: {refs}"
        latest = refs.pop()
        # 三平台 × 两架构 = 6 个 mirrored 资源，helper 的第 4 个实参
        mirrored = re.findall(
            r'\["%s"\]\s*=\s*_(?:linux|macosx|windows)\([^)]*,\s*true\)' % re.escape(latest),
            content)
        assert len(mirrored) == 3, \
            f"latest={latest} 应在三个平台都开启 CN 镜像, 实际 {len(mirrored)}"

    @pytest.mark.static
    def test_autoupdater_disabled(self):
        """版本由 xvm 管理，二进制自带的 updater 必须关掉"""
        content = open(PKG_FILE, encoding='utf-8').read()
        assert "DISABLE_AUTOUPDATER" in content

    @pytest.mark.static
    def test_claude_config_env(self):
        content = open(PKG_FILE, encoding='utf-8').read()
        assert "CLAUDE_CONFIG_DIR" in content


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG, timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_claude_version(self):
        assert_command_output("claude --version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_claude(self):
        assert_xvm_registered("claude")
