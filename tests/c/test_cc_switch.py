"""测试 cc-switch 包"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not

PKG = "cc-switch"
PKG_FILE = "pkgs/c/cc-switch.lua"


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
    def test_all_platforms_declared(self, meta):
        for plat in ("linux", "windows", "macosx"):
            assert meta.platforms.get(plat), f"xpm 缺少 {plat} 平台"


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
    def test_per_arch_assets(self):
        """声明了 aarch64 就必须解析到 arm64 资源

        旧版每个平台只有一个 url，ARM 主机会拿到 x86_64 的 AppImage。
        """
        content = open(PKG_FILE, encoding='utf-8').read()
        assert "Linux-arm64.AppImage" in content
        assert "Windows-arm64-Portable.zip" in content
        # macOS 是 universal bundle，两个架构共用同一个 asset
        assert "macOS.zip" in content

    @pytest.mark.static
    def test_cn_mirror_present(self):
        """CN 加速镜像必须覆盖 latest 指向的版本的三个平台"""
        content = open(PKG_FILE, encoding='utf-8').read()
        assert "gitcode.com/xlings-res/cc-switch" in content
        refs = set(re.findall(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"', content))
        assert len(refs) == 1, f"三平台 latest.ref 不一致: {refs}"
        latest = refs.pop()
        mirrored = re.findall(
            r'\["%s"\]\s*=\s*_(?:linux|macosx|windows)\([^)]*,\s*true\)' % re.escape(latest),
            content)
        assert len(mirrored) == 3, \
            f"latest={latest} 应在三个平台都开启 CN 镜像, 实际 {len(mirrored)}"

    @pytest.mark.static
    def test_single_executable_layout(self):
        """三平台都落到单个可执行文件 — linux AppImage / windows exe / macOS bundle 内的 Mach-O"""
        content = open(PKG_FILE, encoding='utf-8').read()
        assert 'path.join(pkginfo.install_dir(), "cc-switch.exe")' in content
        assert 'path.join(pkginfo.install_dir(), "cc-switch")' in content
        assert "symlink = true" in content


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)
