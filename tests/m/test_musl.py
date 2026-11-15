"""测试 musl 包"""
import json
import os
import platform
import re
import shutil
import subprocess
from pathlib import Path

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home
from tests.lib.xlings_client import XlingsClient

PKG = "musl"
PKG_FILE = "pkgs/m/musl.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


def lua_code(path=PKG_FILE):
    """去掉 `--` 行注释后的配方正文

    配方注释里会引用 musl-gcc、glibc 等名字来解释边界，直接扫全文会把说明
    本身当成违规。
    """
    content = open(path, encoding='utf-8').read()
    return re.sub(r'--[^\n]*', '', content)


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
    def test_declares_loader_and_abi(self):
        """必须导出 loader 和 abi

        loader 是 elfpatch 的 provider 谓词；abi 是同一个 subos 里同时装了
        glibc 和 musl 时的区分标签 —— glibc.lua 的注释就是这么写的。
        """
        code = lua_code()
        # Per architecture: the loader musl names for the machine it is on.
        assert 'local MUSL_LOADER = "ld-musl-" .. recipe_arch .. ".so.1"' in code
        assert 'loader = "lib/" .. MUSL_LOADER' in code
        assert 'abi    = "linux-" .. recipe_arch .. "-musl"' in code

    @pytest.mark.static
    def test_every_version_has_sha256(self):
        """libc payload 不允许无校验安装

        XLINGS_RES 条目不带 checksum，所以这个包用显式 url + sha256。
        """
        code = lua_code()
        assert "XLINGS_RES" not in code, "libc payload 必须带 sha256, 不能用 XLINGS_RES"
        versions = re.findall(r'\["(\d+\.\d+\.\d+)"\]\s*=\s*\{', code)
        assert versions, "没有解析到版本条目"
        # A version is one url + sha256, or one per architecture.
        per_arch = len(re.findall(r'\b(?:x86_64|aarch64)\s*=\s*\{', code))
        shas = len(re.findall(r'sha256\s*=\s*"[0-9a-f]{64}"', code))
        assert shas >= len(versions) and shas == len(re.findall(r'GLOBAL\s*=', code)), \
            f"{len(versions)} 个版本 ({per_arch} 个按架构), sha256 数量不匹配"

    @pytest.mark.static
    def test_cn_mirror_for_every_version(self):
        """每个版本都要有 CN 加速"""
        code = lua_code()
        assert len(re.findall(r'GLOBAL\s*=', code)) == len(re.findall(r'CN\s*=', code))
        assert "gitcode.com/xlings-res/musl" in code

    @pytest.mark.static
    def test_does_not_claim_musl_gcc(self):
        """musl-gcc 这个 program 名归 musl-gcc.lua

        同一个 (name, version) 被两个包注册会被直接拒绝，所以 payload 用
        `--disable-gcc-wrapper` 构建，这里锁住它不会被登记。
        """
        code = lua_code()
        assert not re.search(r'xvm\.add\(\s*"musl-gcc"', code)
        assert not re.search(r'programs\s*=\s*\{[^}]*musl-gcc', code)

    @pytest.mark.static
    def test_libs_register_under_flavor_tagged_version(self):
        """登记进 lib/ 的 loader 挂在带 musl 标识的版本号上

        `<version>-musl` 与 jdk-temurin 的 `<version>-temurin`、
        musl-gcc 的 `16.1.0-musl` 是同一个 idiom。
        """
        code = lua_code()
        assert re.search(r'local FLAVOR = "musl"', code)
        assert re.search(r'pkginfo\.version\(\)\s*\.\.\s*"-"\s*\.\.\s*FLAVOR', code)
        # 注册走 flavor_version()
        assert re.search(r'version\s*=\s*flavor_version\(\)', code)

    @pytest.mark.static
    def test_uninstall_uses_the_namespaced_stored_key(self):
        """卸载必须用带命名空间前缀的版本键

        xvm.add 会自己补索引命名空间(`local:1.2.5-musl`),xvm.remove 不会。
        用裸键从次级命名空间卸载匹配不到任何东西,结果是根节点删了、11 个
        lib 节点全留下:

            crt1.o = {"active": "glibc-2.39",
                      "installed": ["glibc-2.39", "local:1.2.5-musl"]}

        CI 抓不到,因为 posix-test.sh 的卸载后检查只看 bin/ 里残留的 shim,
        而 lib 节点不产生 shim。
        """
        code = lua_code()
        assert re.search(r'function __stored_version\(\)', code), \
            "缺少命名空间感知的版本键 helper"
        assert re.search(r'ns\s*~=\s*"xim"', code), \
            "__stored_version 必须只在非主命名空间加前缀"
        assert re.search(r'xvm\.remove\(lib,\s*v\)', code)
        assert re.search(r'local v = __stored_version\(\)', code), \
            "uninstall 必须用 __stored_version(),不能用裸 flavor_version()"

    @pytest.mark.static
    def test_binding_root_is_a_group(self):
        """musl 没有可执行文件,绑定根必须是 type = "group"

        留成默认的 program 类型会生成一个永远失败的 shim
        (subos/*/bin/musl -> bin/xlings),就是 openxlings/xlings#452 里
        self doctor 报的 orphan。
        """
        code = lua_code()
        assert re.search(r'xvm\.add\(\s*"musl"\s*,\s*\{\s*type\s*=\s*"group"\s*\}\s*\)', code)

    @pytest.mark.static
    def test_install_fails_loudly_without_loader(self):
        """没有 loader 就不能报安装成功

        glibc.lua 踩过：os.mv 失败、install() 照样 return true，结果是一个
        没有 loader 的 libc 包被记为安装成功，而所有被 elfpatch 指过来的
        consumer 都指向一个不存在的文件。
        """
        code = lua_code()
        assert 'ld-musl-x86_64.so.1' in code and 'ld-musl-aarch64.so.1' in code
        assert re.search(r'raise\(', code), "install() 必须在 payload 不完整时 raise"

    @pytest.mark.static
    def test_headers_not_scattered_into_shared_usr_include(self):
        """musl 头文件不能和另一个 libc 的混在同一个 usr/include

        两者的 stdio.h / features.h 内容不同，后落地的那个会静默赢下整个
        subos 的编译。
        """
        code = lua_code()
        assert '"usr/include/musl"' in code
        assert not re.search(r'declare_headers\([^)]*"usr/include"\s*,', code)


REPO = Path(__file__).resolve().parent.parent.parent
HARNESS = REPO / "tests" / "lua" / "musl_config_harness.lua"
LOADER = {"x86_64": "ld-musl-x86_64.so.1", "aarch64": "ld-musl-aarch64.so.1"}

# The published payload's lib/ (1.2.5 and 1.2.6), besides the loader link.
PAYLOAD_LIB = [
    "Scrt1.o", "crt1.o", "crti.o", "crtn.o", "rcrt1.o",
    "libc.a", "libc.so", "libcrypt.a", "libdl.a", "libm.a", "libpthread.a",
    "libresolv.a", "librt.a", "libutil.a", "libxnet.a",
]


def _lua():
    return shutil.which("lua5.4") or shutil.which("lua")


def glibc_names():
    """The names glibc.lua registers into the subos's lib/: its list and its loaders."""
    code = lua_code("pkgs/g/glibc.lua")
    m = re.search(r'local glibc_libs = \{(.*?)\n\}', code, re.S)
    assert m, "glibc.lua 没有 glibc_libs 列表"
    return set(re.findall(r'"([^"]+)"', m.group(1))) | {"ld-linux-x86-64.so.2", "ld-linux-aarch64.so.1"}


def run_hook(tmp_path, arch, mode, store="xim-x-musl", registered=()):
    payload = tmp_path / store / "1.2.5"
    (payload / "lib").mkdir(parents=True)
    (payload / "include").mkdir()
    for name in PAYLOAD_LIB:
        (payload / "lib" / name).write_bytes(b"")
    (payload / "lib" / LOADER[arch]).symlink_to("libc.so")
    result = subprocess.run([_lua(), str(HARNESS), str(REPO / PKG_FILE), arch, mode, str(payload),
                             ",".join(registered)], capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    return [line.split() for line in result.stdout.splitlines()]


needs_lua = pytest.mark.skipif(_lua() is None, reason="no lua interpreter")


class TestRegistrations:
    """What config() asks of xlings, run on a payload fixture through
    tests/lua/musl_config_harness.lua.

    The subos's lib/ is glibc's: installing musl, which activates its group,
    once made `cc` link musl's crt1.o and libc.so (`undefined reference to
    '__isoc23_strtol'`). musl puts its loader there and nothing else; its link
    files go to usr/lib/musl and its headers to usr/include/musl.
    """

    @needs_lua
    @pytest.mark.static
    @pytest.mark.parametrize("arch", ["x86_64", "aarch64"])
    def test_only_the_loader_goes_into_lib(self, tmp_path, arch):
        ops = run_hook(tmp_path, arch, "config")
        libs = {op[1] for op in ops if op[0] == "add" and op[2] == "lib"}
        assert libs == {LOADER[arch]}
        assert libs.isdisjoint(glibc_names())
        assert {op[1] for op in ops if op[0] == "add"} == {LOADER[arch], "musl"}

    @needs_lua
    @pytest.mark.static
    def test_link_files_and_headers_have_their_own_directories(self, tmp_path):
        ops = run_hook(tmp_path, "x86_64", "config")
        files = {(op[1], op[2], op[3]) for op in ops if op[0] == "files"}
        assert files == {("lib", "usr/lib/musl", "musl@1.2.5"),
                         ("include", "usr/include/musl", "musl@1.2.5")}

    @needs_lua
    @pytest.mark.static
    def test_a_fresh_scope_removes_nothing(self, tmp_path):
        """A client refuses to remove a version it does not know
        (`xvm-remove-version-unknown`), and fails the install."""
        assert [op for op in run_hook(tmp_path, "x86_64", "config") if op[0] == "remove"] == []

    @needs_lua
    @pytest.mark.static
    @pytest.mark.parametrize("store,key", [("xim-x-musl", "1.2.5-musl"),
                                           ("local-x-musl", "local:1.2.5-musl")])
    def test_reconfigure_takes_lib_back_from_revision_1(self, tmp_path, store, key):
        """A scope configured at revision 1 holds the link files in lib/; the
        revision-2 config() removes every one of them, under the key it was
        stored with."""
        old = PAYLOAD_LIB
        ops = run_hook(tmp_path, "x86_64", "config", store, [f"{n}@{key}" for n in old])
        removed = {(op[1], op[2]) for op in ops if op[0] == "remove"}
        assert removed == {(n, key) for n in old}
        assert {op[1] for op in ops if op[0] == "add" and op[2] == "lib"} == {"ld-musl-x86_64.so.1"}

    @pytest.mark.static
    def test_revision_moves_with_the_registrations(self, meta):
        """config() changed, so every version entry's revision did too."""
        code = lua_code()
        revisions = [int(r) for r in re.findall(r'revision\s*=\s*(\d+)', code)]
        assert revisions and min(revisions) >= 2


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


def _subos_dir():
    base = Path(xlings_home()) / "subos"
    for name in (os.environ.get("XLINGS_TEST_SUBOS"), "current", "default"):
        if name and (base / name).is_dir():
            return base / name
    pytest.fail(f"no subos under {base}")


HELLO = r"""
#include <stdio.h>
#include <stdlib.h>
int main(int c, char** v) { printf("%ld\n", strtol(c > 1 ? v[1] : "42", 0, 10)); return 0; }
"""


class TestCoexistsWithGlibc:
    """glibc's gcc and musl in one home, musl's group activated last: `cc`
    still links against glibc, and musl's files are where a musl build reads
    them."""

    @pytest.fixture(scope="class")
    def subos(self):
        ok, out = XlingsClient.install("xim:gcc", timeout=1800)
        assert ok, f"gcc 安装失败: {out[-400:]}"
        ok, out = XlingsClient.install(under_test(PKG), timeout=600)
        assert ok, f"musl 安装失败: {out[-400:]}"
        subos = _subos_dir()
        workspace = json.loads((subos / ".xlings.json").read_text())["workspace"]
        version = workspace["musl"]["active"]
        # What `xlings install musl` does after glibc is there, explicitly.
        code = subprocess.call(["bash", "-l", "-c", f"xlings use musl {version}"],
                               stdin=subprocess.DEVNULL)
        assert code == 0, f"xlings use musl {version} failed"
        return subos

    @staticmethod
    def _run(subos, tmp_path, *args):
        env = {**os.environ, "PATH": f"{subos / 'bin'}{os.pathsep}{os.environ.get('PATH', '')}"}
        return subprocess.run(list(args), cwd=tmp_path, env=env, capture_output=True, text=True, timeout=120)

    @staticmethod
    def _payload_of(link):
        return Path(os.path.realpath(link)).as_posix()

    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_cc_links_against_glibc(self, subos, tmp_path):
        for name in ("crt1.o", "Scrt1.o", "crti.o", "libc.so"):
            assert "-x-glibc/" in self._payload_of(subos / "lib" / name), \
                f"lib/{name} -> {self._payload_of(subos / 'lib' / name)}"
        (tmp_path / "h.c").write_text(HELLO)
        r = self._run(subos, tmp_path, "cc", "h.c", "-o", "h")
        assert r.returncode == 0, r.stdout + r.stderr
        r = self._run(subos, tmp_path, "./h", "7")
        assert r.returncode == 0 and r.stdout.strip() == "7", r.stdout + r.stderr

    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_musl_files_are_in_their_own_directories(self, subos):
        loader = subos / "lib" / LOADER[platform.machine()]
        assert "-x-musl/" in self._payload_of(loader), f"{loader} -> {self._payload_of(loader)}"
        for name in ("crt1.o", "Scrt1.o", "crti.o", "crtn.o", "libc.so", "libc.a"):
            target = self._payload_of(subos / "usr" / "lib" / "musl" / name)
            assert "-x-musl/" in target and os.path.isfile(target), f"usr/lib/musl/{name} -> {target}"
        assert os.path.isfile(subos / "usr" / "include" / "musl" / "stdio.h")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_a_musl_build_reads_them(self, subos, tmp_path):
        """Static and dynamic, from usr/lib/musl and usr/include/musl, the
        dynamic one run by the loader in lib/."""
        lib, inc = subos / "usr" / "lib" / "musl", subos / "usr" / "include" / "musl"
        loader = subos / "lib" / LOADER[platform.machine()]
        (tmp_path / "h.c").write_text(HELLO)
        common = ["-nostdinc", "-isystem", str(inc), "-nostdlib"]
        builds = {
            "h_static": ["cc", "-static", *common, f"{lib}/crt1.o", f"{lib}/crti.o", "h.c",
                         f"{lib}/libc.a", "-lgcc", f"{lib}/crtn.o", "-o", "h_static"],
            "h_dynamic": ["cc", *common, f"{lib}/Scrt1.o", f"{lib}/crti.o", "h.c", f"-L{lib}", "-lc",
                          "-lgcc", f"{lib}/crtn.o", f"-Wl,--dynamic-linker={loader}", "-o", "h_dynamic"],
        }
        for exe, cmd in builds.items():
            r = self._run(subos, tmp_path, *cmd)
            assert r.returncode == 0, f"{exe}: " + r.stdout + r.stderr
            r = self._run(subos, tmp_path, f"./{exe}", "9")
            assert r.returncode == 0 and r.stdout.strip() == "9", f"{exe}: " + r.stdout + r.stderr
