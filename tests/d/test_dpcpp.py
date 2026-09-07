"""测试 dpcpp 包"""
import glob
import os
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "dpcpp"
PKG_FILE = "pkgs/d/dpcpp.lua"
# The five programs the upstream archive ships with no search path of their own.
UNSEARCHED = ("sycl-ls", "sycl-prof", "sycl-trace", "sycl-sanitize", "syclbin-dump")


def _code(content: str) -> str:
    """Strip lua line comments so static assertions see only real declarations."""
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_version_is_upstream(self, meta):
        """版本号逐字取自上游 release tag。

        版本号取自上游 tag,不用日期版本也不用本仓库自己的编号。
        """
        vers = [v for v in re.findall(r'\["(\d[^"]*)"\]\s*=', meta.raw_content)]
        assert vers, "no numeric version keys declared"
        # 上游 tag 是 `v7.1.0`,包里写 `7.1.0`。Linux 与 Windows 两份资产由
        # 同一个 tag 发布,所以两个平台块用同一个版本号是上游事实而不是约定。
        assert "7.1.0" in vers


class TestPlatforms:
    """两份上游资产,一个配方。判据的分母取自配方本身。"""

    @pytest.mark.static
    def test_every_declared_platform_has_a_source_and_a_hash(self, meta):
        """一个平台块加进来却没写 source 或 sha256,只会在那台机器上失败。
        分母是配方里声明的平台,不是这里维护的一张表 —— 见 shaderc 的同名
        教训:写死数字的断言只能发现数字变了。"""
        code = _code(meta.raw_content)
        xpm = code[code.index("xpm = {"):]
        blocks = re.findall(r'^\s{8}(linux|windows|macosx) = \{(.*?)^\s{8}\},',
                            xpm, re.M | re.S)
        assert blocks, "no platform block found under xpm"
        for plat, body in blocks:
            assert "source =" in body, f"the {plat} block declares no source"
            assert re.search(r'sha256 = \{', body), f"the {plat} block declares no sha256"
            assert f"sycl_{'linux' if plat == 'linux' else plat}" in body \
                or f"sycl_{plat}" in body, \
                f"the {plat} block does not name that platform's upstream asset"

    @pytest.mark.static
    def test_the_completeness_check_names_this_hosts_file_names(self, meta):
        """两份资产装的是同一套工具链,文件名不同:`clang++` / `clang++.exe`,
        `lib/libsycl.so` / `lib/sycl.lib`。按一种拼法写的检查在另一个平台上
        只会空转 —— 除非那些名字允许缺席,而它们不允许。"""
        code = _code(meta.raw_content)
        assert 'is_host("windows")' in code, \
            "the completeness check does not distinguish the two hosts"
        assert "clang++.exe" in code and "sycl.lib" in code, \
            "the Windows file names are never mentioned"
        assert "libsycl.so" in code, "the Linux file names were dropped"

    @pytest.mark.static
    def test_patchelf_is_reached_only_on_linux(self, meta):
        """patchelf 是 ELF 工具。无条件调用它会让 Windows 的安装在一次
        `os.exec` 上失败,而失败原因与这个包做的事无关。"""
        code = _code(meta.raw_content)
        assert re.search(r'if is_host\("linux"\) then patch_program_rpaths\(dir\) end', code), \
            "the rpath rewrite is not guarded by the host"
        linux_block = code[code.index("linux = {"):code.index("windows = {")]
        assert "xim:patchelf" in linux_block, "patchelf is no longer a linux build dep"
        windows_block = code[code.index("windows = {"):]
        assert "patchelf" not in windows_block.split("}")[0], \
            "the windows block must not depend on an ELF tool"


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


class TestSearchPaths:
    """配方的那一半;TestVerify 是测出来的那一半。"""

    @pytest.mark.static
    def test_forces_rpath_on_the_programs(self, meta):
        """载荷里有五个程序出厂时既无 DT_RPATH 也无 DT_RUNPATH,装好之后找不到
        自己目录里的 libsycl.so.9。要的是 DT_RPATH 而不是 DT_RUNPATH:后者只对
        对象自己的 DT_NEEDED 生效,而这个载荷的设备支持是一串 dlopen ——
        sycl-ls → libsycl → libur_loader → libur_adapter_* → libumf ——
        只有可传递的那个 tag 能到底。"""
        code = _code(meta.raw_content)
        assert "--force-rpath" in code, "the programs must get DT_RPATH, not DT_RUNPATH"
        assert "$ORIGIN/../lib" in code

    @pytest.mark.static
    def test_declares_patchelf_as_a_build_dep(self, meta):
        """godot.lua 与 libglvnd.lua 用同样的理由声明它:让安装顺序确定,
        而不是指望 patchelf 恰好已经在 shim PATH 上。"""
        code = _code(meta.raw_content)
        assert "xim:patchelf" in code

    @pytest.mark.static
    def test_does_not_touch_the_libraries(self, meta):
        """这一条是「没做什么」的判据,而它是被实测逼出来的。给载荷的库自己一条
        RUNPATH 也能让 sycl-ls 枚举出设备,但那会**关掉**加载它们的那个产物继承
        下来的 DT_RPATH:实测 libur_adapter_cuda.so.0 于是先找不到 libcuda.so.1、
        再找不到 libnvidia-ml.so.1 —— 那两个本来是产物自己的搜索路径在提供。
        每个消费者都得把这个载荷的整个外部闭包再 farm 一遍。"""
        code = _code(meta.raw_content)
        assert "selfcontain" not in code, \
            "dpcpp must not be sealed: seal also swaps the interpreter"
        # The patch loop names the five programs and nothing under lib/.
        assert 'path.join(dir, "bin", prog)' in code
        assert 'path.join(dir, "lib"' not in code, \
            "the payload's libraries must be left exactly as upstream shipped them"

    @pytest.mark.static
    def test_asserts_the_artifact_not_the_intent(self, meta):
        """patchelf 可能不在。跳过的重写和成功的重写从一次运行上看一模一样,
        直到有人在另一台机器上跑那个程序。"""
        code = _code(meta.raw_content)
        assert "readelf" in code and "(RPATH)" in code

    @pytest.mark.static
    def test_does_not_probe_the_host_for_the_driver(self, meta):
        """哨兵包是唯一有资格知道驱动在哪的包。这个配方一行探测都不写。"""
        code = _code(meta.raw_content)
        assert "ldconfig" not in code and "nvidia-smi" not in code


def _payload_dir() -> str:
    for ns in ("xim", "local"):
        hits = sorted(d for d in glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-dpcpp", "*"))
                      if os.path.isdir(d))
        if hits:
            return hits[-1]
    pytest.fail(f"no dpcpp payload in the store ({xpkgs_dir()})")


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_every_program_can_start(self):
        """缺陷本身,按用户会做的动作陈述。判据落在 stderr 上而不是退出码上,
        因为 `--help` 合法地以非零退出。"""
        b = os.path.join(_payload_dir(), "bin")
        checked = 0
        for prog in UNSEARCHED:
            p = os.path.join(b, prog)
            if not os.path.isfile(p):
                continue
            r = subprocess.run([p, "--help"], capture_output=True, text=True, timeout=60)
            checked += 1
            assert "error while loading shared libraries" not in r.stderr, \
                f"bin/{prog} cannot start: {r.stderr.strip()[:200]}"
        assert checked > 0, "no dpcpp program found to check"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_programs_carry_rpath_not_runpath(self):
        b = os.path.join(_payload_dir(), "bin")
        checked = 0
        for prog in UNSEARCHED:
            p = os.path.join(b, prog)
            if not os.path.isfile(p):
                continue
            r = subprocess.run(["readelf", "-d", p], capture_output=True, text=True, timeout=15)
            checked += 1
            assert "(RPATH)" in r.stdout, f"bin/{prog} carries no DT_RPATH"
            assert "(RUNPATH)" not in r.stdout, \
                f"bin/{prog} carries a DT_RUNPATH, which a dlopen beneath it does not honour"
        assert checked > 0, "no dpcpp program found to check"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_libraries_were_left_alone(self):
        """`test_does_not_touch_the_libraries` 的实测那一半。一个带 RUNPATH 的
        payload 库会关掉加载它的产物继承下来的 RPATH。"""
        lib = os.path.join(_payload_dir(), "lib")
        checked = 0
        for name in sorted(os.listdir(lib)):
            if "libur_adapter" not in name:
                continue
            p = os.path.join(lib, name)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            r = subprocess.run(["readelf", "-d", p], capture_output=True, text=True, timeout=15)
            if r.returncode != 0:
                continue
            checked += 1
            assert "(RUNPATH)" not in r.stdout, \
                f"lib/{name} carries a RUNPATH; it would cut its loader off from its own farm"
        assert checked > 0, "no Unified Runtime adapter found to check"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_the_interpreter_is_untouched(self):
        """换 interpreter 会把载荷挪到私有 loader 上,而它背后没有宿主回落 ——
        那正是 CI 的闭包检查拒掉的形态。"""
        r = subprocess.run(["readelf", "-p", ".interp",
                            os.path.join(_payload_dir(), "bin", "sycl-ls")],
                           capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, r.stderr[:200]
        assert "/lib64/ld-linux" in r.stdout or "/lib/ld-" in r.stdout, \
            f"sycl-ls no longer uses the host loader:\n{r.stdout[:300]}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_clang_still_reports_its_version(self):
        """对照:`clang++` 不在被改写的五个之列,必须原样可用。"""
        r = subprocess.run([os.path.join(_payload_dir(), "bin", "clang++"), "--version"],
                           capture_output=True, text=True, timeout=60)
        assert r.returncode == 0, r.stderr[:300]
        assert "DPC++" in r.stdout or "clang version" in r.stdout

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_sycl_ls_reports_rather_than_fails_to_start(self):
        """列出哪些设备是这台机器的答案而不是这个包的 —— 没有 GPU 的 runner
        合法地一个都没有。判据落在这个包能造成的两种失败上:起不来,以及某个
        adapter 找不到本载荷自己的库。"""
        r = subprocess.run([os.path.join(_payload_dir(), "bin", "sycl-ls"), "--verbose"],
                           capture_output=True, text=True, timeout=120)
        assert "error while loading shared libraries" not in r.stderr, \
            f"sycl-ls cannot start: {r.stderr.strip()[:200]}"
        both = r.stdout + r.stderr
        for own in ("libsycl.so", "libumf.so", "libur_loader.so"):
            assert f"{own}.1: cannot open" not in both and f"{own}.9: cannot open" not in both, \
                f"an adapter could not find {own}, which is in this payload"
