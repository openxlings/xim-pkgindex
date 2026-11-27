"""测试 qt-addons 包"""
import re
import os
import glob
import subprocess
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.recipe_deps import declared_deps
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
    def test_declares_qt_and_7zip_dependency(self, meta):
        """每个模块都要链接 qtbase (runtime); 每个 archive 都是 .7z, 但 7-Zip 只在
        install() 里用 (build, docs/10-adding-a-package.md, Dependencies)。"""
        deps = declared_deps(PKG_FILE)
        for plat in ("windows", "linux", "macosx"):
            assert "xim:qt@6.11.1" in deps[plat]["runtime"], f"{plat} 缺 xim:qt@6.11.1 依赖"
            assert "xim:7zip" in deps[plat]["build"], f"{plat} 缺 xim:7zip build 依赖"
            assert "xim:7zip" not in deps[plat]["runtime"], f"{plat} 把 xim:7zip 声明成了 runtime 依赖"

    @pytest.mark.static
    def test_linux_declares_the_loader_so_its_tools_run(self, meta):
        """Linux: xim:glibc 让 xlings 在 install() 之后改写每个可执行文件的解释器和每个 ELF 的
        RUNPATH(libxpkg elfpatch, loader-provider 谓词)。不声明它, bin/qsb 等工具带着系统的
        loader 和 RUNPATH=$ORIGIN/../lib 启动, 找不到 xim:qt 的 Qt 库, 回落到发行版自己的
        libQt6Core 或报 GLIBC_2.43 not found。"""
        deps = declared_deps(PKG_FILE)
        assert "xim:glibc" in deps["linux"]["runtime"], "linux 缺 xim:glibc (没有它不会 elfpatch)"
        assert "xim:qt@6.11.1" in deps["linux"]["runtime"]
        # elfpatch 写入的 RPATH 只含这里直接声明的包, 不含 xim:qt 的传递依赖: 本包的 ELF
        # 直接用到的库必须在这里再声明 (qsb 缺 libxkbcommon.so.0 就是这个原因)
        for dep in ("xim:gcc-runtime", "xim:libglvnd", "xim:libxkbcommon", "xim:libX11",
                    "xim:libXext", "xim:libXrandr", "xim:libdrm", "xim:wayland", "xim:zlib", "xim:glib"):
            assert dep in deps["linux"]["runtime"], f"linux 缺 {dep}"
        # 这个闭包只有 Linux 需要: Windows/macOS 不声明 loader
        for plat in ("windows", "macosx"):
            assert "xim:glibc" not in deps[plat]["runtime"], f"{plat} 不该声明 xim:glibc"

    @pytest.mark.static
    def test_linux_runtime_closure_is_versioned_and_marked(self, meta):
        """revision 1 替换没有 elfpatch 的 revision 0 载荷; 只有 Linux 写/查 runtime 标记, 这样
        Windows/macOS 已装的 128-160 MB 载荷不会被判为过期而重下。"""
        raw = meta.raw_content
        m = re.search(r'linux\s*=\s*\{.*?\n        \},', raw, re.DOTALL)
        assert m, "找不到 linux 块"
        block = m.group(0)
        assert re.search(r'\["6\.11\.1"\]\s*=\s*\{\s*revision\s*=\s*1\s*\}', block), "linux 的 6.11.1 未声明 revision = 1"
        assert re.search(r'exports\s*=\s*\{\s*runtime\s*=\s*\{\s*libdirs\s*=\s*\{\s*"lib"', block)
        for plat in ("windows", "macosx"):
            mm = re.search(rf'{plat}\s*=\s*\{{.*?\n        \}},', raw, re.DOTALL)
            assert mm and "revision" not in mm.group(0), f"{plat} 不该变 revision"
        assert 'pkginfo.platform() == "linux" then qtsdk.mark_runtime(marker_path())' in raw
        assert 'pkginfo.platform() == "linux" and not qtsdk.runtime_current(marker)' in raw

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

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_qsb_runs(self):
        """qsb 链接 libQt6ShaderTools(本包)、libQt6Gui/Core(xim:qt)、libxkbcommon、libGL:
        能启动就说明解释器和 RUNPATH 都被 elfpatch 改到了生态的闭包。"""
        d = self._installed_pkgdir()
        r = subprocess.run([os.path.join(d, "bin", "qsb"), "--version"],
                            capture_output=True, text=True, timeout=30)
        assert r.returncode == 0, f"qsb --version failed: {r.stderr}"
        assert "6.11.1" in r.stdout + r.stderr, r.stdout + r.stderr

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_qsb_compiles_a_shader(self, tmp_path):
        """不只是启动: 真的把一个 GLSL 片段着色器编成 .qsb (qsb 的实际工作)。"""
        d = self._installed_pkgdir()
        src = tmp_path / "t.frag"
        src.write_text(
            "#version 440\n"
            "layout(location = 0) in vec2 qt_TexCoord0;\n"
            "layout(location = 0) out vec4 fragColor;\n"
            "layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; };\n"
            "void main() { fragColor = vec4(qt_TexCoord0, 0.0, 1.0) * qt_Opacity; }\n")
        out = tmp_path / "t.frag.qsb"
        r = subprocess.run([os.path.join(d, "bin", "qsb"), "--qt6", "-o", str(out), str(src)],
                            capture_output=True, text=True, timeout=60)
        assert r.returncode == 0, f"qsb failed: {r.stderr}"
        assert out.is_file() and out.stat().st_size > 0, "qsb 没有写出 .qsb"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_executables_are_patched_to_the_ecosystem_loader(self):
        """bin/ 下的可执行文件的解释器是生态的 loader(.../abi/linux-*-glibc/ld-linux-*), 不是系统的
        /lib64/ld-linux-*; RUNPATH/RPATH 含 xim:qt 的 lib。"""
        d = self._installed_pkgdir()
        exe = os.path.join(d, "bin", "qsb")
        prog = subprocess.run(["readelf", "-l", exe], capture_output=True, text=True).stdout
        m = re.search(r"Requesting program interpreter: (\S+?)\]", prog)
        assert m, f"没有解释器: {prog[:300]}"
        assert not m.group(1).startswith("/lib64/"), f"解释器仍是系统的: {m.group(1)}"
        dyn = subprocess.run(["readelf", "-d", exe], capture_output=True, text=True).stdout
        assert "xim-x-qt" in dyn, f"RUNPATH/RPATH 没有 xim:qt 的 lib: {dyn}"
