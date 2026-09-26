"""测试 qt 包"""
import re
import glob
import os
import subprocess
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, project_root, xpkgs_dir

PKG = "qt"
PKG_FILE = "pkgs/q/qt.lua"

EXPECTED_BASE_COUNT = {
    "windows-x86_64": 7,
    "windows-aarch64": 5,
    "linux-x86_64": 7,
    "linux-aarch64": 7,
    "macosx": 5,
}


def _base_table():
    path = PKG_FILE
    if not os.path.isabs(path):
        path = os.path.join(project_root(), path)
    src = open(path, encoding="utf-8").read()
    start = src.index("local BASE = {")
    end = src.index("\nlocal function marker_path", start)
    return src[start:end]


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
    def test_linux_declares_its_runtime_closure(self, meta):
        """Qt 的 Linux 库按 SONAME 依赖 glib、libdbus、xcb 等，由依赖声明提供并写入 RUNPATH。"""
        m = re.search(r'linux\s*=\s*\{\s*deps\s*=\s*\{(.*?)\n            \}', meta.raw_content, re.DOTALL)
        assert m, "linux 平台没有 deps 列表"
        for dep in ("xim:glibc", "xim:glib", "xim:zstd", "xim:zlib", "xim:dbus", "xim:fontconfig",
                    "xim:freetype", "xim:libX11", "xim:libxkbcommon", "xim:libglvnd",
                    "xim:libxcb", "xim:xcb-util-wm", "xim:gcc-runtime", "xim:wayland",
                    "xim:krb5", "xim:brotli"):
            assert f'"{dep}"' in m.group(1), f"linux deps 缺少 {dep}"
        assert re.search(r'exports\s*=\s*\{\s*runtime\s*=\s*\{\s*libdirs\s*=\s*\{\s*"lib"', meta.raw_content)
        assert "qtsdk.mark_runtime(marker_path())" in meta.raw_content
        # plugins no provider serves are removed, so D2 holds under the xlings loader
        assert "qtsdk.prune(install_dir, PRUNE_LINUX)" in meta.raw_content
        assert '"plugins/platformthemes/libqgtk3.so"' in meta.raw_content
        assert "qtsdk.runtime_current(marker)" in meta.raw_content

    @pytest.mark.static
    def test_windows_x64_carries_the_vc_runtime(self):
        """Qt 的 MSVC DLL 依赖 VC++ 运行时; windows-x86_64 把可再分发的 DLL 放入 bin/。"""
        m = re.search(r'\["windows-x86_64"\]\s*=\s*\{(.*?)\n    \},', _base_table(), re.DOTALL)
        assert m, "BASE 里没有 windows-x86_64"
        rest = m.group(1)[m.group(1).index('module = "vcruntime"'):]
        assert 'from = "Contents/VC/Redist/MSVC/14.44.35112/x64/Microsoft.VC143.CRT"' in rest
        assert 'to = "bin"' in rest
        assert '"bin", "msvcp140.dll"' in open(os.path.join(project_root(), PKG_FILE), encoding="utf-8").read()

    @pytest.mark.static
    def test_declares_7zip_dependency(self, meta):
        """每个 archive 都是 .7z, 没有 xim:7zip 依赖就没法解压。"""
        for plat in ("windows", "linux", "macosx"):
            assert re.search(
                rf'{plat}\s*=\s*\{{\s*deps\s*=\s*\{{[^}}]*"xim:7zip"',
                meta.raw_content), f"{plat} 平台缺少 xim:7zip 依赖声明"

    @pytest.mark.static
    def test_base_table_has_every_platform_and_field(self):
        """BASE 表覆盖 5 个 platform key, 每条记录都有 module/name/path/sha256,
        且每个 sha256 恰好是 64 位十六进制 -- 缺一个字段, install() 就会用
        nil 拼出一个坏 URL 或者跳过校验。
        """
        body = _base_table()
        for plat, expect_n in EXPECTED_BASE_COUNT.items():
            m = re.search(rf'\["{plat}"\]\s*=\s*\{{(.*?)\n    \}},', body, re.DOTALL)
            assert m, f"BASE 里没有 {plat}"
            block = m.group(1)
            entries = re.findall(
                r'\{\s*module\s*=\s*"([^"]+)"\s*,\s*name\s*=\s*"([^"]+)"\s*,'
                r'\s*path\s*=\s*"([^"]+)"\s*,\s*sha256\s*=\s*"([0-9a-fA-F]{64})"\s*\}',
                block)
            assert len(entries) == expect_n, (
                f"{plat}: 期望 {expect_n} 个 archive 条目, 实际解析到 {len(entries)}"
            )

    @pytest.mark.static
    def test_flat_module_subdir_matches_base_modules(self):
        """FLAT_MODULE_SUBDIR 里列出的每个 module 名字都必须真的出现在 BASE
        的某个平台里 -- 否则这张表在保护一个不存在的条目, 掩盖了真正需要
        特殊落盘目录的条目反而没被覆盖。
        """
        # 这张表在 libs/qtsdk.lua (qt / qt-base / qt-addons 共用)。
        path = os.path.join(project_root(), "libs/qtsdk.lua")
        src = open(path, encoding="utf-8").read()
        m = re.search(r'local FLAT_MODULE_SUBDIR = \{(.*?)\n\}', src, re.DOTALL)
        assert m, "没找到 FLAT_MODULE_SUBDIR"
        flat_modules = re.findall(r'(\w+)\s*=\s*"(?:lib|bin)"', m.group(1))
        assert flat_modules, "FLAT_MODULE_SUBDIR 是空的"
        body = _base_table()
        for mod in flat_modules:
            assert re.search(rf'module\s*=\s*"{mod}"', body), (
                f"FLAT_MODULE_SUBDIR 里的 '{mod}' 在 BASE 表里找不到对应条目"
            )


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
        # ~190 MB download (qtbase + qtsvg + qtdeclarative + qttools +
        # qttranslations + qtwayland + icu on linux-x86_64) -- real network,
        # matches this index's existing convention for prebuilt-toolchain
        # packages (msvc, windows-sdk, cmake all do the same in CI).
        assert_install_succeeds(PKG, timeout=420)


class TestVerify:
    @staticmethod
    def _installed_pkgdir() -> str:
        """Read the store directly, matching test_android_ndk.py's own
        helper: no xvm program shim is registered for this package
        (umbrella "group" root, like 7zip.lua's own binding root) -- so
        there is no `qmake` on PATH to invoke bare. A namespace can be
        `local` (this recipe, before merge) or `xim` (after); both are
        tried, newest version wins.
        """
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-qt", "*")))
            if hits:
                return hits[-1]
        pytest.fail(f"no qt payload found under {xpkgs_dir()}")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_qmake(self):
        d = self._installed_pkgdir()
        r = subprocess.run([os.path.join(d, "bin", "qmake"), "--version"],
                            capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, f"qmake --version failed: {r.stderr}"
        assert "Qt version 6.11.1" in r.stdout, r.stdout

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_moc(self):
        # MEASURED: moc lives under libexec/, not bin/, in this Qt6 layout
        # (the QT_HOST_PATH split) -- see installed()'s own comment.
        d = self._installed_pkgdir()
        r = subprocess.run([os.path.join(d, "libexec", "moc"), "--version"],
                            capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, f"moc --version failed: {r.stderr}"
        assert "6.11.1" in r.stdout, r.stdout
