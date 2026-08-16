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
