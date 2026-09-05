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
        # 上游 tag 是 `v7.1.0`,包里写 `7.1.0`。自建的 Windows 版本也用这个号,
        # 因为它就是那份源码 —— 版本说的是「你拿到的是哪一版上游」。
        assert "7.1.0" in vers


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
    def test_sets_rpath_on_both_bin_and_lib(self, meta):
        """载荷里有五个程序出厂时既无 DT_RPATH 也无 DT_RUNPATH,装好之后找不到
        自己目录里的 libsycl.so.9。只给 bin/ 加路径还不够:UR loader 按绝对
        路径 dlopen 各个 adapter,于是它们被找到了,然后每一个都倒在
        `libumf.so.1` 上 —— 那个库就在本载荷的 lib/ 里。"""
        code = _code(meta.raw_content)
        assert re.search(r'elfpatch\.set_rpath\(.*"bin".*\$ORIGIN/\.\./lib', code), \
            "bin/ must get $ORIGIN/../lib"
        assert re.search(r'elfpatch\.set_rpath\(.*"lib".*"\$ORIGIN"', code), \
            "lib/ must get $ORIGIN"

    @pytest.mark.static
    def test_does_not_seal_the_payload(self, meta):
        """`selfcontain.seal` 连 interpreter 一起换,载荷就跑在生态的私有
        loader 上,而它背后没有宿主回落。这个载荷没有闭包 —— 它的 UR adapter
        还要 libcuda.so.1 / libnvidia-ml.so.1 / libcupti.so.12 / libOpenCL.so.1
        / libz.so.1,本索引只提供其中一部分。封过一次,CI 的闭包检查点名了
        没有提供者的那四个,而且封过之后一个平台都枚举不出来。"""
        code = _code(meta.raw_content)
        assert "selfcontain" not in code, \
            "dpcpp must not be sealed: it has no closure and would lose its host fallback"

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
        """缺陷本身,按用户会做的动作陈述:这五个程序各自会以某个状态退出,
        但绝不该在 main 之前死在 loader 里 ——「error while loading shared
        libraries」就是那种死法。判据落在 stderr 上而不是退出码上,因为
        `--help` 合法地以非零退出。"""
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
    def test_the_interpreter_is_untouched(self):
        """这一条是「没做什么」的判据。换 interpreter 会把载荷挪到私有 loader
        上,而它背后没有宿主回落 —— 那正是 CI 的闭包检查拒掉的形态。"""
        r = subprocess.run(["readelf", "-p", ".interp",
                            os.path.join(_payload_dir(), "bin", "sycl-ls")],
                           capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, r.stderr[:200]
        assert "/lib64/ld-linux" in r.stdout or "/lib/ld-" in r.stdout, \
            f"sycl-ls no longer uses the host loader:\n{r.stdout[:300]}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_adapters_can_reach_the_payloads_own_libraries(self):
        """把 bin/ 那一半和 lib/ 那一半分开的判据。UR 的 adapter 是被 dlopen
        的,它们自己的 DT_NEEDED 只按自己的搜索路径解析。"""
        lib = os.path.join(_payload_dir(), "lib")
        checked = 0
        for name in sorted(os.listdir(lib)):
            if "libur_adapter" not in name or not name.endswith(".0"):
                continue
            p = os.path.join(lib, name)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            r = subprocess.run(["readelf", "-d", p], capture_output=True,
                               text=True, timeout=15)
            if r.returncode != 0:
                continue
            checked += 1
            assert "$ORIGIN" in r.stdout, f"lib/{name} names no $ORIGIN in its search path"
        assert checked > 0, "no Unified Runtime adapter found to check"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_clang_still_reports_its_version(self):
        """对照。加搜索路径会重写 bin/ 里每一个程序,包括本来就正确的那些。"""
        r = subprocess.run([os.path.join(_payload_dir(), "bin", "clang++"), "--version"],
                           capture_output=True, text=True, timeout=60)
        assert r.returncode == 0, r.stderr[:300]
        assert "DPC++" in r.stdout or "clang version" in r.stdout

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_sycl_ls_reports_rather_than_fails_to_start(self):
        """`sycl-ls` 要能产出一份报告,而不是一条 loader 错误,并且不能有任何
        adapter 倒在本载荷自己的库上。列出哪些设备是这台机器的答案而不是这个
        包的 —— 没有 GPU 的 runner 合法地一个都没有。"""
        r = subprocess.run([os.path.join(_payload_dir(), "bin", "sycl-ls"), "--verbose"],
                           capture_output=True, text=True, timeout=120)
        assert "error while loading shared libraries" not in r.stderr, \
            f"sycl-ls cannot start: {r.stderr.strip()[:200]}"
        both = r.stdout + r.stderr
        for own in ("libsycl.so", "libumf.so", "libur_loader.so"):
            assert f"{own}.1: cannot open" not in both and f"{own}.9: cannot open" not in both, \
                f"an adapter could not find {own}, which is in this payload"
