"""测试 wix 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
)

PKG = "wix"
PKG_FILE = "pkgs/w/wix.lua"


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
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.static
    def test_no_bashrc_modification(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.static
    def test_no_direct_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.static
    def test_uses_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.static
    def test_windows_only(self, meta):
        """WiX 是 Windows 的打包工具, 声明其他平台会让解析在别处才失败。"""
        assert set(meta.platforms.keys()) <= {"windows"}, meta.platforms.keys()
        assert 'archs = {"x86_64"}' in meta.raw_content

    @pytest.mark.static
    def test_every_payload_is_pinned(self):
        """三个 payload 各自一个 sha256。

        这个包自己下载一组 payload, 框架的单 url 校验覆盖不到它们 ——
        少一个 sha256 就是少一次校验, 而这些字节会变成链接进安装器的 .lib。
        """
        source = open(PKG_FILE, encoding="utf-8").read()
        digests = [line for line in source.splitlines() if "sha256 =" in line]
        assert len(digests) == 3, f"期望 3 个 payload 摘要, 实得 {len(digests)}"
        for line in digests:
            hexpart = line.split('"')[1]
            assert len(hexpart) == 64 and all(c in "0123456789abcdef" for c in hexpart), line

    @pytest.mark.static
    def test_declares_the_downloader(self, meta):
        """payload 是自己 curl 下来的, 下载器本身不能留给宿主。"""
        assert "xim:curl" in meta.raw_content

    @pytest.mark.static
    def test_declares_the_extractor(self, meta):
        """解压器同理 —— 这一条是被一次真实失败换来的。

        install() 原来用宿主的 `tar`。它在 mcpp 从源码构建 huxerui 时失败,
        而同一个钩子里 `curl` 是好的 —— payload 已经下载并校验通过, 否则
        根本走不到解压那步。声明过的依赖够得着, 宿主工具够不着。
        """
        assert "xim:7zip" in meta.raw_content

        # 只看代码, 不看注释 —— 上面那段注释引用了当初的失败原文, 里面
        # 就有 `tar -xf`, 而那是史料不是调用。
        code = "\n".join(
            line for line in meta.raw_content.splitlines()
            if not line.lstrip().startswith("--")
        )
        assert "tar -xf" not in code, "解压器不能退回宿主的 tar"

    @pytest.mark.static
    def test_每个_payload_都有落地锚点(self):
        """解压出空目录也是"目录存在"; 每个 payload 要有一个必须存在的文件。"""
        source = open(PKG_FILE, encoding="utf-8").read()
        assert source.count("anchor =") == 3, "每个 payload 都要有 anchor"
        assert "wix.exe" in source and "balutil.lib" in source and "dutil.lib" in source
