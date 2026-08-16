"""测试 msvc 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg, payload_entries, toolset_payloads
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
        # 按 TOOLSETS 表分组, 不是扫全文件 —— 见 test_every_toolset_is_complete。
        groups = toolset_payloads(PKG_FILE)
        assert groups, "TOOLSETS 表里没有解析到 toolset"
        for toolset, names in groups.items():
            assert any("Desktop.base" in n for n in names), \
                f"{toolset} 缺静态 CRT payload (.CRT.x64.Desktop.base): {names}"
            assert any(".CRT.x64.Store.base" in n for n in names), \
                f"{toolset} 缺动态 CRT payload (.CRT.x64.Store.base): {names}"

    @pytest.mark.static
    def test_unpacking_pins_the_system_bsdtar(self):
        """解包必须钉死 System32 的 bsdtar,并且路径与引号都按 cmd 的规矩来。

        **`.vsix` 是 zip,而 GNU tar 根本不读 zip。** Windows 自带的
        System32\\tar.exe 是 bsdtar(libarchive),读得了;Git for Windows
        带的是 GNU tar,读不了:

            tar: This does not look like a tar archive

        同一个 GitHub 镜像上两次运行证明了这点:index 自己的 windows-test
        解析到 bsdtar、通过;mcpp 的 e2e 解析到 GNU tar、失败。
        **同一份 recipe、同一个镜像、不同的 PATH** —— 所以不能让 PATH 来选。

        钉死 exe 之后,**盘符那条风险就不存在了** —— 它是 GNU tar 独有的。
        所以路径全部用绝对的、全部过 `winpath()`,并且**不用 `os.cd`**;
        而 exe 本身**不能加引号**,否则 cmd /c 会把整行弄坏:

        * `path.join` 会混用分隔符,`"C:\\Windows/System32/tar.exe"` 执行不了;
        * `system.exec` **不继承** `os.cd` 设的 cwd。7zip.lua 那个
          「cd 之后用相对文件名」的形状用的是 `os.exec` —— 照抄形状而没有核对
          这一处差别的结果是:命令拼得完全正确,却找不到自己的归档文件。

        少一个可动的部件就少一处可以出错:没有 cwd 要改、没有 cwd 要还,
        也没有任何东西取决于最后是哪个 tar 在跑。
        """
        import re
        # 注释里就写着那些坏例子(留着是为了说明原因), 所以只扫真正的代码行 ——
        # 第一版没扫掉注释, 于是它抓到的是自己的说明文字。
        code = "\n".join(
            line for line in open(PKG_FILE, encoding='utf-8').read().splitlines()
            if not line.lstrip().startswith("--"))

        assert 'System32' in code and 'tar.exe' in code, \
            "解包必须显式用 System32\\tar.exe(bsdtar),不能让 PATH 选到 GNU tar"
        assert re.search(r"winpath\(path\.join\([^)]*SystemRoot", code), \
            "System32 的 exe 路径必须过 winpath(),否则分隔符是混的"
        assert not re.search(r"['\"]tar\s+-xf", code), \
            "不能调用裸 `tar` —— PATH 上的可能是读不了 zip 的 GNU tar"
        # exe 本身不能加引号:cmd /c 遇到「首个 token 带引号 + 后面还有带引号的
        # 参数」会把最外层那对剥掉, 然后报
        #   The filename, directory name, or volume label syntax is incorrect.
        # 证据很干净:裸 `tar` 时程序跑起来了并自己报错, 加引号时它根本没跑。
        assert "'%s -xf" in code, \
            "exe 不能加引号 —— cmd /c 会把整行弄坏(参数该加的还是要加)"

        # 归档与目标目录都必须过 winpath();相对路径依赖 cwd,而
        # system.exec 不继承 os.cd。
        assert 'winpath(path.join(work, e.name))' in code, \
            "归档参数必须是 winpath 过的绝对路径"
        assert 'winpath(stage)' in code, "-C 的目标必须是 winpath 过的绝对路径"
        assert 'os.cd(' not in code, \
            "解包不该改 cwd —— system.exec 不继承它,绝对路径本来就不需要"

    @pytest.mark.static
    def test_installed_checks_what_a_build_needs(self):
        """installed() 必须验到两种 CRT 模型的导入库。

        它原本只查 cl.exe 和 std.ixx —— 这正是上面那个缺陷能一路绿着
        走到用户面前的原因。一个"装好了"的判据如果比"能用"弱, 那它报的
        就不是安装成功, 而是解压成功。
        """
        src = open(PKG_FILE, encoding='utf-8').read()
        for f in ("libcpmt.lib", "msvcprt.lib", "clui.dll"):
            assert f in src, f"installed() 没有检查 {f}"

    @pytest.mark.static
    def test_compiler_resources_are_shipped(self):
        """每个 toolset 必须带 `.Res.base` —— 没有它 cl.exe 跑不起来。

        它装的是 `bin/Hostx64/x64/1033/clui.dll`(编译器的消息资源)。
        缺了之后**任何**一次调用都会在说出任何有用的话之前死掉:

            fatal error C1510: Cannot load language resource clui.dll

        包括每个消费者做的第一件事 —— 读 banner 来识别编译器。
        `.Res.base` 的名字听起来像是本地化裁剪,它不是可选的。
        """
        for toolset, names in toolset_payloads(PKG_FILE).items():
            assert any("Res.base" in n for n in names), \
                f"{toolset} 缺编译器资源 payload (.Tools.*.Res.base): {names}"

    @pytest.mark.static
    def test_every_toolset_is_complete_and_entries_live_in_TOOLSETS(self):
        """条目必须在 TOOLSETS 表**里面**, 而且每个 toolset 都要齐。

        这条来自一个真实事故: 补 clui.dll 的两个条目被插进了
        `package.xpm` 表 —— 静态测试全绿(它们扫的是整个文件, "文件里有"
        就算数), 而 recipe 运行时只取到 5 个 payload, Windows 上照旧失败。

        **"文件里有"和"表里有"是两个问题。** 位置错了的条目对 recipe 来说
        根本不存在, 所以判据必须按表来, 不能按文本。
        """
        groups = toolset_payloads(PKG_FILE)
        assert set(groups) == {"14.44.35207", "14.52.36629"}, \
            f"TOOLSETS 的 key 不对: {sorted(groups)}"
        for toolset, names in groups.items():
            assert len(names) == len(set(names)), f"{toolset} 有重复条目"
            for need in ("Tools.HostX64.TargetX64.base", "CRT.Headers.base",
                         "CRT.x64.Desktop.base", "CRT.Redist", 
                         "CRT.x64.Store.base", "Res.base"):
                assert any(need in n for n in names), \
                    f"{toolset} 缺 {need}: {names}"

    @pytest.mark.static
    def test_vctip_is_deleted_after_unpacking(self):
        """install() 必须删掉 vctip.exe —— 不然这个 toolset **卸不掉**。

        vctip.exe 是 cl.exe 拉起来的后台遥测上传进程,它比编译器活得久,
        并且从 payload 目录**里面**占着
        `Microsoft.VisualStudio.Telemetry.dll`。于是:

            error: remove failed: Access is denied.
                     stuck at: ...\\bin\\Hostx64\\x64\\Microsoft.VisualStudio.Telemetry.dll

        删它是安全的,依据是 cl.exe **自己的**字符串:

            Not launching VCTIP: Binary not found @ '%S'

        —— 二进制不在是它本来就处理的一条分支。没有环境变量可以关掉它
        (vctip 自己的 `-upload:optout` 写的是**机器级**状态,装个包不该动那个)。
        """
        src = open(PKG_FILE, encoding="utf-8").read()
        body = src[src.index("function install()"):]
        code = "\n".join(l for l in body.splitlines()
                          if not l.lstrip().startswith("--"))
        assert "vctip.exe" in code, "install() 没有删 vctip.exe —— toolset 会卸不掉"
        assert "os.tryrm" in code

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
