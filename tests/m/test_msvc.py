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
    def test_unpacking_pins_the_system_bsdtar_and_a_relative_archive_name(self):
        """解包必须钉死 System32 的 bsdtar,并且归档参数是相对文件名。

        **`.vsix` 是 zip,而 GNU tar 根本不读 zip。** Windows 自带的
        System32\\tar.exe 是 bsdtar(libarchive),读得了;Git for Windows
        带的是 GNU tar,读不了:

            tar: This does not look like a tar archive

        同一个 GitHub 镜像上两次运行证明了这点:index 自己的 windows-test
        解析到 bsdtar、通过;mcpp 的 e2e 解析到 GNU tar、失败。
        **同一份 recipe、同一个镜像、不同的 PATH** —— 所以不能让 PATH 来选。

        两个参数、两种风险,分别钉:

        * **exe 必须是绝对路径**,否则又回到 PATH 来选;
        * **归档参数必须是相对文件名**,因为 GNU tar 会把开头的 `C:` 当主机名
          (`tar: Cannot connect to C: resolve failed`)—— bsdtar 无所谓,
          GNU tar 致命,而 `--force-local` 是修好一个弄坏另一个。

        只钉 exe 今天就够用;保留相对文件名是为了让这条调用**无论最后是哪个
        tar 在跑都正确**。
        """
        import re
        # 注释里就写着那些坏例子(留着是为了说明原因), 所以只扫真正的代码行 ——
        # 第一版没扫掉注释, 于是它抓到的是自己的说明文字。
        code = "\n".join(
            line for line in open(PKG_FILE, encoding='utf-8').read().splitlines()
            if not line.lstrip().startswith("--"))

        assert 'System32' in code and 'tar.exe' in code, \
            "解包必须显式用 System32\\tar.exe(bsdtar),不能让 PATH 选到 GNU tar"
        assert not re.search(r"['\"]tar\s+-xf", code), \
            "不能调用裸 `tar` —— PATH 上的可能是读不了 zip 的 GNU tar"

        calls = re.findall(r"-xf\s+\"([^\"]*)\"", code)
        assert calls, "没有找到 -xf 调用"
        for arg in calls:
            assert not re.match(r'^[A-Za-z]:', arg), f"归档参数带了盘符: {arg}"
            assert arg == "%s", f"归档参数应当是单个相对文件名: {arg}"
        # 相对文件名只有在 cwd 就是 work 时才成立, 两者必须同时在。
        assert 'os.cd(work)' in code, "解包必须先 cd 进 work,才能用相对文件名"
        assert 'os.cd(idir)' in code, "解包完必须把 cwd 移出 work(用 idir,不用没有先例的 os.curdir)"

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
