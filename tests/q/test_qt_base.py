"""测试 qt-base 包 (qtbase + qttools + QtQml, xim:qt 的 widgets/console 子集)"""
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

PKG = "qt-base"
PKG_FILE = "pkgs/q/qt-base.lua"

EXPECTED_COUNT = {
    "windows-x86_64": 7,   # qtbase qttools qttranslations d3dcompiler_47 opengl32sw qtqml vcruntime
    "windows-aarch64": 4,  # qtbase qttools qttranslations qtqml
    "linux-x86_64": 5,     # qtbase qttools qttranslations icu qtqml
    "linux-aarch64": 5,
    "macosx": 4,
}


def _table(pkg_file):
    src = open(os.path.join(project_root(), pkg_file), encoding="utf-8").read()
    start = src.index("local BASE = {")
    end = src.index("\nlocal function marker_path", start)
    return src[start:end]


def _entries(body, plat):
    m = re.search(rf'\["{plat}"\]\s*=\s*\{{(.*?)\n    \}},', body, re.DOTALL)
    assert m, f"BASE 里没有 {plat}"
    return re.findall(r'\{\s*module\s*=\s*"([^"]+)"(.*?sha256\s*=\s*"[0-9a-fA-F]{64}")\s*\}\s*,',
                      m.group(1), re.DOTALL)


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
        rest = dict(_entries(_table(PKG_FILE), "windows-x86_64"))["vcruntime"]
        assert 'from = "Contents/VC/Redist/MSVC/14.44.35112/x64/Microsoft.VC143.CRT"' in rest
        assert 'to = "bin"' in rest
        assert '"bin", "msvcp140.dll"' in open(os.path.join(project_root(), PKG_FILE), encoding="utf-8").read()

    @pytest.mark.static
    def test_declares_7zip_dependency(self, meta):
        for plat in ("windows", "linux", "macosx"):
            assert re.search(
                rf'{plat}\s*=\s*\{{\s*deps\s*=\s*\{{[^}}]*"xim:7zip"',
                meta.raw_content), f"{plat} 平台缺少 xim:7zip 依赖声明"

    @pytest.mark.static
    def test_table_has_every_platform_and_no_qtdeclarative(self):
        body = _table(PKG_FILE)
        for plat, n in EXPECTED_COUNT.items():
            entries = _entries(body, plat)
            mods = [m for m, _ in entries]
            assert len(entries) == n, f"{plat}: 期望 {n} 个条目, 实际 {mods}"
            assert "qtdeclarative" not in mods, f"{plat}: qt-base 不应含 qtdeclarative"
            assert "qtqml" in mods and "qtbase" in mods and "qttools" in mods, mods

    @pytest.mark.static
    def test_qt_entries_are_xim_qt_pins(self):
        """每个 Qt 仓库条目与 pkgs/q/qt.lua 的同名条目逐字相同 (同一个 path 与 sha256)。"""
        ours, theirs = _table(PKG_FILE), _table("pkgs/q/qt.lua")
        for plat in EXPECTED_COUNT:
            full = {m: rest for m, rest in _entries(theirs, plat)}
            for mod, rest in _entries(ours, plat):
                if mod == "qtqml":
                    continue
                assert mod in full, f"{plat}: {mod} 不在 xim:qt 里"
                assert rest.strip() == full[mod].strip(), f"{plat}: {mod} 与 xim:qt 的 pin 不同"

    @pytest.mark.static
    def test_qtqml_has_both_mirrors_and_a_digest(self):
        body = _table(PKG_FILE)
        for plat in EXPECTED_COUNT:
            rest = dict(_entries(body, plat))["qtqml"]
            assert "https://github.com/xlings-res/qt-base/releases/download/6.11.1/" in rest, plat
            assert "https://gitcode.com/xlings-res/qt-base/releases/download/6.11.1/" in rest, plat
            assert re.search(r'sha256\s*=\s*"[0-9a-f]{64}"', rest), plat


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
        # ~59 MB on linux-x86_64 (qtbase + qttools + icu + QtQml).
        assert_install_succeeds(PKG, timeout=420)


class TestVerify:
    @staticmethod
    def _installed_pkgdir() -> str:
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-qt-base", "*")))
            if hits:
                return hits[-1]
        pytest.fail(f"no qt-base payload found under {xpkgs_dir()}")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_moc(self):
        d = self._installed_pkgdir()
        r = subprocess.run([os.path.join(d, "libexec", "moc"), "--version"],
                            capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, f"moc --version failed: {r.stderr}"
        assert "6.11.1" in r.stdout, r.stdout

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_lupdate_loads_qtqml(self):
        """lupdate 链接 libQt6Qml.so.6: 能启动就说明 QtQml 已就位。"""
        d = self._installed_pkgdir()
        r = subprocess.run([os.path.join(d, "bin", "lupdate"), "-version"],
                            capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, f"lupdate -version failed: {r.stderr}"
        assert "6.11.1" in r.stdout + r.stderr, r.stdout + r.stderr

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_lrelease(self):
        d = self._installed_pkgdir()
        r = subprocess.run([os.path.join(d, "bin", "lrelease"), "-version"],
                            capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, f"lrelease -version failed: {r.stderr}"
