"""测试 musl 包"""
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
        assert 'loader = "lib/ld-musl-x86_64.so.1"' in code
        assert 'abi    = "linux-x86_64-musl"' in code

    @pytest.mark.static
    def test_every_version_has_sha256(self):
        """libc payload 不允许无校验安装

        XLINGS_RES 条目不带 checksum，所以这个包用显式 url + sha256。
        """
        code = lua_code()
        assert "XLINGS_RES" not in code, "libc payload 必须带 sha256, 不能用 XLINGS_RES"
        versions = re.findall(r'\["(\d+\.\d+\.\d+)"\]\s*=\s*\{', code)
        assert versions, "没有解析到版本条目"
        assert len(re.findall(r'sha256\s*=\s*"[0-9a-f]{64}"', code)) == len(versions), \
            f"{len(versions)} 个版本, sha256 数量不匹配"

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
    def test_shared_libc_names_are_listed_separately(self):
        """和 glibc 撞名的部分必须单独列出

        这 11 个名字是对着 glibc.lua 的 glibc_libs 和 payload 里真实的
        lib/ 算出来的交集,不是眼估的。单独成表是为了让"哪些名字危险"
        在配方里是显式的。
        """
        code = lua_code()
        m = re.search(r'local SHARED_LIBS = \{(.*?)\}', code, re.S)
        assert m, "缺少 SHARED_LIBS 列表"
        shared = set(re.findall(r'"([^"]+)"', m.group(1)))
        assert shared == {
            "Scrt1.o", "crt1.o", "crti.o", "crtn.o",
            "libc.a", "libc.so", "libdl.a", "libm.a",
            "libpthread.a", "librt.a", "libutil.a",
        }, f"SHARED_LIBS 和实测的 glibc 交集不一致: {sorted(shared)}"

    @pytest.mark.static
    def test_libs_register_under_flavor_tagged_version(self):
        """撞名的 lib 必须挂在带 musl 标识的版本号上

        用平版本号注册会让每个名字变成双 owner:

            crt1.o = {"active": "glibc-2.39",
                      "installed": ["glibc-2.39", "musl-1.2.5"]}

        一次 xvm use 选到 musl 那侧,该 subos 里所有 glibc C 链接就静默挂掉。
        用 `<version>-musl` 与 jdk-temurin 的 `<version>-temurin`、
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
        assert "ld-musl-x86_64.so.1" in code
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


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)
