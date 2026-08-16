"""测试 windows-sdk 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg, payload_entries
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)

PKG = "windows-sdk"
PKG_FILE = "pkgs/w/windows-sdk.lua"


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
        少一个 sha256 就是少一次校验, 而这些字节会变成编译器的头文件。

        镜像让地址变成一个列表, 但 sha256 仍然是**一个**: 从哪个地址取到
        都按同一个摘要校验, 所以"多来源"不会变成"多份可信来源"。
        """
        entries = payload_entries(PKG_FILE)
        assert entries, "没有解析到任何 payload"
        for e in entries:
            assert e["sha256"], f"{e['name']} 没有 sha256"
            assert e["urls"], f"{e['name']} 没有任何下载地址"

    @pytest.mark.static
    def test_the_core_win32_import_libraries_are_shipped(self):
        """必须带「Store Apps Libs」—— 核心 Win32 导入库在里面。

        `Windows SDK Desktop Libs x64` 有 341 个 um 库,而
        `kernel32.lib` / `user32.lib` / `advapi32.lib` / `ole32.lib` /
        `oleaut32.lib` / `uuid.lib` **一个都不在里面** —— 它带的是长尾
        (sensorsapi、websocket、computestorage……)。这六个在名字写着
        "Store Apps" 的那个 MSI 里,和 msvc.lua 的 CRT.x64.Store.base
        是同一个命名陷阱,只是低一层。

        少了它,`int main(){}` 都链接不了:

            LINK : fatal error LNK1104: cannot open file 'kernel32.lib'
        """
        names = [e["name"] for e in payload_entries(PKG_FILE)]
        assert any("Store Apps Libs" in n and "Managed" not in n for n in names), \
            f"缺核心 Win32 导入库的 MSI(Store Apps Libs): {names}"

    @pytest.mark.static
    def test_every_header_and_tool_msi_named_store_apps_is_shipped(self):
        """um 头 / shared 头 / rc.exe / mt.exe —— 四样都在 "Store Apps" 里。

        名字写着 "Desktop" 的四个 MSI 一个都不提供它们:
        `Windows SDK Desktop Headers x64` 只有 **4 个文件**
        (WinHvEmulation.h / WinHvPlatform.h / WinHvPlatformDefs.h + 一个
        catalog),既没有 windows.h 也没有 winnt.h;
        `Windows SDK Desktop Tools x64` 的 99 个 bin 工具里没有 rc.exe,
        也没有 mt.exe。

        真正提供它们的是:

            um 头 (528 个: windows.h/winnt.h)  Store Apps Headers
            shared 头 (windef.h/sal.h/...)     Store Apps Headers OnecoreUap
            rc.exe / rcdll.dll / mt.exe        Store Apps Tools

        以上不是猜的 —— 是把每个 MSI 的 File/Component/Directory 表解出来、
        把每个文件的安装路径算出来核对的。少任一个:缺 um 头则
        `#include <windows.h>` 直接失败;缺 shared 头则 windows.h 自身
        编不过;缺 Tools 则 `programs = {"rc", "mt"}` 注册两个不存在的程序。
        """
        names = [e["name"] for e in payload_entries(PKG_FILE)]

        def has(frag):
            return any(frag in n for n in names)

        assert has("Store Apps Headers-"), f"缺 um 头 (Store Apps Headers): {names}"
        assert has("Store Apps Headers OnecoreUap"), f"缺 shared 头 (OnecoreUap): {names}"
        assert has("Store Apps Tools"), f"缺 rc.exe/mt.exe (Store Apps Tools): {names}"

    @pytest.mark.static
    def test_required_files_covers_every_payload_that_matters(self):
        """`required_files()` 每条对应一个 **只有它才提供** 的 MSI。

        这是覆盖,不是抽样:哪个 payload 没下下来/没解开/没合并,
        报错就点名哪一个。所以断言的文件必须能区分 MSI —— 例如
        `gdi32.lib` 只在 Desktop Libs x64(它和 Store Apps Libs 的
        365/116 两组库**完全不相交**),`windef.h` 只在 OnecoreUap。
        """
        src = open(PKG_FILE, encoding='utf-8').read()
        body = src[src.index("local function required_files"):src.index("function install()")]
        # 同样去掉注释行 —— 见下一个用例, 断言自己的说明文字是这套测试
        # 已经犯过一次的错。
        code = "\n".join(l for l in body.splitlines()
                         if not l.lstrip().startswith("--"))
        for f in ("corecrt.h", "winnt.h", "windef.h", "kernel32.lib",
                  "gdi32.lib", "rc.exe", "mt.exe"):
            assert f in code, f"required_files() 没覆盖 {f}"

    @pytest.mark.static
    def test_installed_asserts_files_not_directories(self):
        """`installed()` 必须查文件名, 不能只查目录。

        原来查的是 `Lib/<ver>/um/x64` 这个**目录**, 理由是 SDK 自己的文件名
        大小写不一致、写 `kernel32.lib` 是在猜。那个理由是错的 ——
        **Windows 文件系统大小写不敏感**, `os.isfile` 查 `kernel32.lib`
        照样匹配磁盘上的 `Kernel32.Lib`。没有需要规避的风险。

        而这次弱化正好放过了一个坏掉的 SDK:少了含 kernel32.lib 的那个 MSI,
        目录照样存在(另外 341 个 um 库落进去了), `installed()` 说 yes,
        windows-test 全绿, 而任何程序的链接都失败。
        """
        src = open(PKG_FILE, encoding='utf-8').read()
        # 从 required_files() 起 —— 名字清单在那里, installed() 只是遍历它。
        body = src[src.index("local function required_files"):src.index("function install()")]
        # 去掉注释行 —— 上面那段注释里就写着 kernel32.lib, 第一版因此在
        # 「检查被削弱回目录」的情况下照样通过, 抓到的是自己的说明文字。
        code = "\n".join(l for l in body.splitlines()
                         if not l.lstrip().startswith("--"))
        for f in ("corecrt.h", "kernel32.lib", "rc.exe"):
            assert f in code, f"installed() 没有按文件名检查 {f}"
        assert "os.isdir" not in code, \
            "installed() 不该用 os.isdir —— 目录存在不代表里面有链接需要的文件"

    @pytest.mark.static
    def test_mirror_never_replaces_the_official_address(self):
        """有镜像的条目必须仍然保留官方地址, 且官方地址在最后。

        镜像是**第二个**地址, 不是替代品。
        """
        for e in payload_entries(PKG_FILE):
            official = [u for u in e["urls"]
                        if "download.visualstudio.microsoft.com" in u]
            assert official, f"{e['name']} 丢掉了官方地址: {e['urls']}"
            if len(e["urls"]) > 1:
                assert e["urls"][-1] == official[-1], \
                    f"{e['name']} 的官方地址应当是最后的回退"

    @pytest.mark.static
    def test_local_file_name_comes_from_entry_name_not_the_url(self):
        """镜像上的资产名与 entry.name 不同 —— 必须由 entry.name 落盘。

        gitcode 拒绝 `.cab` 扩展名, 也拒绝名字里的空格, 所以镜像资产叫
        `<下划线名>` / `<name>.cab.bin`。install() 解压时按 entry.name 找
        文件(cab 必须与它的 MSI 同名同目录), 一旦改成从 URL 推导文件名,
        msiexec 就找不到 cabinet —— 而那会在解压阶段才炸。
        """
        src = open(PKG_FILE, encoding='utf-8').read()
        assert 'path.join(dir, entry.name)' in src, \
            "fetch_verified 必须用 entry.name 作为落盘文件名"
        for e in payload_entries(PKG_FILE):
            mirrored = [u for u in e["urls"] if "gitcode.com" in u]
            if mirrored and e["name"].endswith(".cab"):
                assert mirrored[0].endswith(".cab.bin"), \
                    f"{e['name']} 的镜像地址扩展名不对: {mirrored[0]}"


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
