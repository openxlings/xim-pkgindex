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
        """Each of the four payloads carries its own sha256.

        This package downloads a set of payloads itself, which the framework's
        single-url check does not cover: a missing digest is a missing
        verification, and these bytes become .lib files linked into an
        installer and the extension `wix build` loads.
        """
        source = open(PKG_FILE, encoding="utf-8").read()
        digests = [line for line in source.splitlines() if "sha256 =" in line]
        assert len(digests) == 4, f"expected 4 payload digests, found {len(digests)}"
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
    def test_every_payload_has_anchors(self):
        """An archive that extracted to nothing still leaves a directory, so
        every payload names the files that must exist after extraction, and a
        payload with two purposes names one file per purpose."""
        source = open(PKG_FILE, encoding="utf-8").read()
        code = "\n".join(l for l in source.splitlines() if not l.lstrip().startswith("--"))
        assert code.count("anchors =") == 4, "every payload needs its anchors"
        for anchor in ("tools/net6.0/any/wix.exe",
                       "wixext5/WixToolset.BootstrapperApplications.wixext.dll",
                       "build/native/v14/x64/balutil.lib",
                       "runtimes/win-x64/native/mbanative.dll",
                       "build/native/v14/x64/dutil.lib"):
            assert f'"{anchor}"' in code, f"no anchor names {anchor}"

    @pytest.mark.static
    def test_installed_and_install_check_every_anchor(self):
        """installed() and install() iterate the anchor list; a check of the
        first anchor alone would pass a bootstrapper payload that lost
        mbanative.dll."""
        source = open(PKG_FILE, encoding="utf-8").read()
        for hook in ("function installed()", "function install()"):
            start = source.index(hook)
            end = source.index("\nend\n", start)
            assert "ipairs(entry.anchors)" in source[start:end], f"{hook} does not check every anchor"

    @pytest.mark.static
    def test_the_bootstrapper_extension_is_a_payload(self):
        """A bundle with WiX's stock installer UI needs
        WixToolset.BootstrapperApplications.wixext, at the tool's version."""
        source = open(PKG_FILE, encoding="utf-8").read()
        assert 'id = "wixtoolset.bootstrapperapplications.wixext"' in source
        assert 'into = "bal"' in source

    @pytest.mark.static
    def test_the_revision_is_latest_and_5_0_2_stays(self, meta):
        """5.0.2-1 adds the extension; an installation made under 5.0.2 keeps
        what it fetched, so a consumer that needs the extension pins the
        revision, and consumers pinned to 5.0.2 keep resolving."""
        code = "\n".join(l for l in meta.raw_content.splitlines()
                         if not l.lstrip().startswith("--"))
        assert '["latest"] = { ref = "5.0.2-1" }' in code
        assert '["5.0.2-1"] = { }' in code
        assert '["5.0.2"] = { }' in code

    @pytest.mark.static
    def test_the_recipe_states_the_link_the_native_archives_need(self, meta):
        """The archives are MSVC-built; the statement of what links them is
        part of the recipe, measured on windows-2022."""
        assert "MSVC-ABI" in meta.raw_content
        assert "import libraries" in meta.raw_content
