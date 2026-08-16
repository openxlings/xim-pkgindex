"""测试 msvc 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg, payload_entries
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)

PKG = "msvc"
PKG_FILE = "pkgs/m/msvc.lua"


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
    def test_every_payload_is_pinned(self):
        """每个 payload 恰好一个 sha256, 至少一个地址。

        这个包自己下载一组 payload, 框架的单 url 校验覆盖不到它们 ——
        少一个 sha256 就是少一次校验, 而这些字节会变成编译器。

        镜像让地址变成一个列表, 但 sha256 仍然是**一个**: 从哪个地址取到
        都按同一个摘要校验, 所以"多来源"不会变成"多份可信来源"。
        """
        entries = payload_entries(PKG_FILE)
        assert entries, "没有解析到任何 payload"
        for e in entries:
            assert e["sha256"], f"{e['name']} 没有 sha256"
            assert e["urls"], f"{e['name']} 没有任何下载地址"

    @pytest.mark.static
    def test_both_crt_models_are_shipped(self):
        """每个 toolset 必须同时带静态和动态 CRT 的 payload。

        这条来自一个真实缺陷: payload 集里只有 `.CRT.x64.Desktop.base`
        (静态: libcmt / libcpmt / libvcruntime), 而**默认**的 /MD 构建需要
        `msvcprt.lib` —— 它在 `.CRT.x64.Store.base` 里。名字带 Store,
        实际把桌面用的动态导入库放进 lib/x64。

        当时 cl.exe、头文件、std.ixx 全在, `installed()` 说 yes,
        index 的 windows-test 全绿 —— 而任何默认构建都会在链接期挂掉。
        判据取 use_ansi.h 自己的选择:

            #if defined(_DLL) && !defined(_STATIC_CPPLIB)
            #define _LIB_STEM "msvcprt"     // /MD
            #else
            #define _LIB_STEM "libcpmt"     // /MT
        """
        names = [e["name"] for e in payload_entries(PKG_FILE)]
        for toolset, tag in (("14.44", "14.44"), ("14.52", "14.52")):
            of_toolset = [n for n in names if f".{tag}." in n or f"VC.{tag}" in n]
            assert any("Desktop.base" in n for n in of_toolset), \
                f"{toolset} 缺静态 CRT payload (.CRT.x64.Desktop.base): {of_toolset}"
            assert any("Store.base" in n for n in of_toolset), \
                f"{toolset} 缺动态 CRT payload (.CRT.x64.Store.base): {of_toolset}"

    @pytest.mark.static
    def test_installed_checks_what_a_build_needs(self):
        """installed() 必须验到两种 CRT 模型的导入库。

        它原本只查 cl.exe 和 std.ixx —— 这正是上面那个缺陷能一路绿着
        走到用户面前的原因。一个"装好了"的判据如果比"能用"弱, 那它报的
        就不是安装成功, 而是解压成功。
        """
        src = open(PKG_FILE, encoding='utf-8').read()
        for lib in ("libcpmt.lib", "msvcprt.lib"):
            assert lib in src, f"installed() 没有检查 {lib}"

    @pytest.mark.static
    def test_mirror_never_replaces_the_official_address(self):
        """有镜像的条目必须仍然保留官方地址。

        镜像是**第二个**地址, 不是替代品。只留镜像会把一个可以回退的
        依赖换成一个不能回退的依赖 —— 而且换掉的正是唯一的权威来源。
        """
        for e in payload_entries(PKG_FILE):
            official = [u for u in e["urls"]
                        if "download.visualstudio.microsoft.com" in u]
            assert official, f"{e['name']} 丢掉了官方地址: {e['urls']}"
            if len(e["urls"]) > 1:
                assert e["urls"][-1] == official[-1], \
                    f"{e['name']} 的官方地址应当是最后的回退"


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
