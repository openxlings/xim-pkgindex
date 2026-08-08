"""测试 ncurses 包 — 规则 D 已知缺口 (libtinfo/libncurses) 的提供者"""
import glob
import json
import os
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xlings_home, xpkgs_dir

PKG = "ncurses"
PKG_FILE = "pkgs/n/ncurses.lua"


def _code(content: str) -> str:
    """去掉 lua 行注释, 静态断言只看真实声明"""
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
    def test_resource_has_both_mirrors(self, meta):
        code = _code(meta.raw_content)
        assert re.search(
            r'GLOBAL\s*=\s*"https://github\.com/xlings-res/ncurses/[^"]+"', code)
        assert re.search(
            r'CN\s*=\s*"https://gitcode\.com/xlings-res/ncurses/[^"]+"', code)
        assert len(re.findall(r'sha256 = "[0-9a-f]{64}"', code)) == 1

    @pytest.mark.static
    def test_declares_glibc_dep(self, meta):
        """闭包提供者自己也要有闭包: libtinfo 的唯一外部 NEEDED 是 libc.so.6"""
        assert '"xim:glibc"' in _code(meta.raw_content)

    @pytest.mark.static
    def test_registers_the_gap_sonames(self, meta):
        """这个包存在的理由: xmake/llvm 链 NEEDED 的两个 soname 必须被注册"""
        code = _code(meta.raw_content)
        for name in ("libtinfo.so.6", "libncurses.so.6"):
            assert f'"{name}"' in code, f"缺 {name} 的 lib 节点"

    @pytest.mark.static
    def test_non_widec_build(self, meta):
        """消费者的 NEEDED 是非宽字符名 (libncurses.so.6, 不是 libncursesw);
        widec 载荷谁也满足不了 (注释里解释这件事可以提 w 名, 声明里不行)"""
        assert "ncursesw" not in _code(meta.raw_content)

    @pytest.mark.static
    def test_lib_only_no_programs(self, meta):
        """bin/ 工具 (tic/tput/clear/reset...) 是宿主日常命令, 不注册 shim:
        闭包缺口只关乎 .so; 且实测载荷 bin/ 带构建机绝对 PT_INTERP (见 recipe)"""
        code = _code(meta.raw_content)
        assert "programs" not in code, "lib-only 包不应有 programs 字段"
        for tool in ("tic", "tput", "clear", "reset"):
            assert not re.search(rf'xvm[.:]\s*add\s*\(\s*"{tool}"', code), \
                f"不应注册宿主同名工具 {tool}"

    @pytest.mark.static
    def test_placeholder_is_group(self, meta):
        """包名占位节点必须是 group — 裸 add 会铸出一个只会失败的孤儿 shim"""
        assert 'type = "group"' in _code(meta.raw_content)

    @pytest.mark.static
    def test_seals_payload(self, meta):
        assert "selfcontain.seal" in _code(meta.raw_content)


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
        # 显式 local:, 不用裸名也不用 xim: —— 三个口径里唯一在「发布前后」
        # 都成立的一个:
        #   * 裸名 "ncurses" 在 scode:ncurses (from-source 子索引) 并存时
        #     歧义, 一旦 local: 注册过更是必歧义;
        #   * xim:ncurses 在索引发布前不存在, 而新名字无法被 overlay 进
        #     编译好的 catalog (解析 miss 还会触发自动 refresh 盖掉 overlay);
        # 跑本测试前先 `xlings config --add-xpkg pkgs/n/ncurses.lua`
        # (closure-lifecycle job 就是这么做的)。
        assert_install_succeeds(f"local:{PKG}")


# ── L4 helpers — 都直接读盘/跑载荷, 不经 shim ───────────────────────────
#
# 断言对象是「装出来的东西」: 载荷、xvm 落盘注册、以及关键的 —— 我们的
# loader 能否解析 libtinfo。最后这条是本包的存在理由 (规则 D): 形态 X 下
# 没有宿主 ld.so cache 兜底, mcpp#392 就是这个 soname 在形态 X 找不到
# 提供者的崩法。

def _payload_dir() -> str:
    for ns in ("xim", "local"):
        hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-ncurses", "*")))
        if hits:
            return hits[-1]
    pytest.fail(f"store 里没有 ncurses 载荷 ({xpkgs_dir()})")


def _our_loader() -> str:
    hits = sorted(glob.glob(os.path.join(
        xpkgs_dir(), "*-x-glibc", "*", "lib64", "ld-linux-x86-64.so.2")))
    if not hits:
        pytest.fail("store 里没有 glibc 载荷的 loader (deps 没装上?)")
    return hits[-1]


def _subos_workspace() -> dict:
    for name in ("current", "default"):
        p = os.path.join(xlings_home(), "subos", name, ".xlings.json")
        if os.path.isfile(p):
            with open(p, encoding="utf-8") as f:
                return json.load(f).get("workspace", {})
    pytest.fail("找不到 subos 的 .xlings.json")


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_payload_libs_present(self):
        lib = os.path.join(_payload_dir(), "lib")
        for name in ("libtinfo.so.6", "libncurses.so.6"):
            assert os.path.exists(os.path.join(lib, name)), f"载荷缺 {name}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_lib_nodes_registered(self):
        ws = _subos_workspace()
        for name in ("ncurses", "libtinfo.so.6", "libncurses.so.6"):
            assert name in ws and ws[name].get("active"), \
                f"xvm workspace 缺节点 {name} (有: {sorted(ws)[:20]})"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_runpath_has_no_host_paths(self):
        """RUNPATH 只许 $ORIGIN 或本 home 内的绝对路径。

        实测: 装好后 RUNPATH 是 elfpatch predicate 改写的 closure 形态
        (载荷 lib + glibc lib64 + subos farm, $ORIGIN 被换成载荷自身绝对
        libdir —— libxpkg 的文档化行为, 载荷从不搬家所以等价)。断言口径
        因此不是「必须 $ORIGIN」而是「没有一条指向 home 之外」。
        """
        lib = os.path.join(_payload_dir(), "lib", "libtinfo.so.6")
        r = subprocess.run(["readelf", "-d", os.path.realpath(lib)],
                           capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, r.stderr[:200]
        m = re.search(r"(?:RUNPATH|RPATH).*\[(.*)\]", r.stdout)
        assert m, f"libtinfo 没有 RUNPATH: {r.stdout[-300:]}"
        home = os.path.realpath(xlings_home())
        bad = [e for e in m.group(1).split(":")
               if e and e != "$ORIGIN"
               and not os.path.realpath(e).startswith(home)]
        assert not bad, f"RUNPATH 指向了 home 之外 (宿主/构建机路径): {bad}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_tinfo_resolves_under_our_loader(self):
        """规则 D 验收: 我们的 ld.so 能解析 libtinfo, 且 libc 解析进我们的
        glibc 载荷 —— 不靠宿主 cache (我们的 loader 根本没有可用 cache)。"""
        lib = os.path.join(_payload_dir(), "lib", "libtinfo.so.6")
        r = subprocess.run([_our_loader(), "--list", lib],
                           capture_output=True, text=True, timeout=15)
        out = r.stdout + r.stderr
        assert r.returncode == 0, f"loader --list 失败: {out[-300:]}"
        m = re.search(r"libc\.so\.6 => (\S+)", out)
        assert m, f"--list 没解析 libc.so.6: {out[:300]}"
        home = os.path.realpath(xlings_home())
        assert os.path.realpath(m.group(1)).startswith(home), \
            f"libc 解析到了 home 之外: {m.group(1)}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_tic_runs_from_payload(self):
        """载荷 bin/tic -V 可跑 (未注册 shim, 用绝对路径)。

        as-shipped 的 bin/ 带构建机 PT_INTERP; 装好能跑说明 elfpatch 把
        INTERP 改写到了本 home 的 glibc —— 这是工具面的形态 X 自包含验收。
        """
        tic = os.path.join(_payload_dir(), "bin", "tic")
        assert os.path.isfile(tic), "载荷里没有 bin/tic"
        r = subprocess.run([tic, "-V"], capture_output=True, text=True, timeout=15)
        assert r.returncode == 0, f"tic -V 失败 (INTERP 没被改写?): {r.stderr[:200]}"
        assert "ncurses 6.5" in r.stdout, f"版本串不对: {r.stdout[:100]}"
