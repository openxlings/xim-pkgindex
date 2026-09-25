"""测试 qt-addons 包"""
import re
import os
import glob
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

PKG = "qt-addons"
PKG_FILE = "pkgs/q/qt-addons.lua"

EXPECTED_ADDON_COUNT = {
    "windows-x86_64": 34,
    "windows-aarch64": 34,
    "linux-x86_64": 34,
    "linux-aarch64": 34,
    "macosx": 33,
}


def _addons_table():
    path = PKG_FILE
    if not os.path.isabs(path):
        path = os.path.join(project_root(), path)
    src = open(path, encoding="utf-8").read()
    start = src.index("local ADDONS = {")
    end = src.index("\nlocal function winpath", start)
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
    def test_declares_qt_and_7zip_dependency(self, meta):
        """每个模块都要链接 qtbase; 每个 archive 都是 .7z。"""
        for plat in ("windows", "linux", "macosx"):
            block = re.search(
                rf'{plat}\s*=\s*\{{\s*deps\s*=\s*\{{([^}}]*)\}}', meta.raw_content)
            assert block, f"{plat} 平台没有 deps 声明"
            assert '"xim:7zip"' in block.group(1), f"{plat} 缺 xim:7zip 依赖"
            assert '"xim:qt@6.11.1"' in block.group(1), f"{plat} 缺 xim:qt@6.11.1 依赖"

    @pytest.mark.static
    def test_addons_table_has_every_platform_and_field(self):
        """ADDONS 表覆盖 5 个 platform key, 每条记录都有 module/name/path/sha256。

        数目按平台不同 (windows/linux 34, macosx 33 -- 没有 qtactiveqt,
        一个 Windows ActiveX 桥接模块) -- 这是真实差异, 不是遗漏。
        """
        body = _addons_table()
        for plat, expect_n in EXPECTED_ADDON_COUNT.items():
            m = re.search(rf'\["{plat}"\]\s*=\s*\{{(.*?)\n    \}},', body, re.DOTALL)
            assert m, f"ADDONS 里没有 {plat}"
            block = m.group(1)
            entries = re.findall(
                r'\{\s*module\s*=\s*"([^"]+)"\s*,\s*name\s*=\s*"([^"]+)"\s*,'
                r'\s*path\s*=\s*"([^"]+)"\s*,\s*sha256\s*=\s*"([0-9a-fA-F]{64})"\s*\}',
                block)
            assert len(entries) == expect_n, (
                f"{plat}: 期望 {expect_n} 个 archive 条目, 实际解析到 {len(entries)}"
            )

    @pytest.mark.static
    def test_no_duplicate_modules_per_platform(self):
        """同一 platform 下 module 名不能重复 -- 重复意味着两个不同 archive
        被算成了同一个模块, marker 和 sentinel 检查都会跟着算错。
        """
        body = _addons_table()
        for plat in EXPECTED_ADDON_COUNT:
            m = re.search(rf'\["{plat}"\]\s*=\s*\{{(.*?)\n    \}},', body, re.DOTALL)
            mods = re.findall(r'module\s*=\s*"([^"]+)"', m.group(1))
            assert len(mods) == len(set(mods)), f"{plat}: 出现重复 module: {mods}"


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
        # ~128 MB, 34 archives -- pulls in xim:qt (its own ~190 MB) as a
        # dependency first if not already installed.
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @staticmethod
    def _installed_pkgdir() -> str:
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-qt-addons", "*")))
            if hits:
                return hits[-1]
        pytest.fail(f"no qt-addons payload found under {xpkgs_dir()}")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_qtcharts_lib_present(self):
        d = self._installed_pkgdir()
        assert os.path.isfile(os.path.join(d, "lib", "libQt6Charts.so.6")), (
            "libQt6Charts.so.6 not found -- qtcharts module missing or "
            "extracted to the wrong place"
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_qt3d_lib_present(self):
        d = self._installed_pkgdir()
        assert os.path.isfile(os.path.join(d, "lib", "libQt63DCore.so.6")), (
            "libQt63DCore.so.6 not found -- qt3d module missing or "
            "extracted to the wrong place"
        )
