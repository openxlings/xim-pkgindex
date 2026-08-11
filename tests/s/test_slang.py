"""测试 slang 包"""
import re
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager, assert_platform_supported,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "slang"
PKG_FILE = "pkgs/s/slang.lua"
VERSION = "2026.14.1"

# 每个平台的资源 URL 都由 platform-scope `source` 模板展开。三平台各有一处
# 不规则，所以三个模板都要断言，而不是只测宿主平台那一个：
#   * release tag 带 v 前缀（v2026.14.1），文件名不带；
#   * xlings 把 macOS 拼作 macosx，上游拼作 macos；
#   * ${ext} 在 windows 上是 zip，其余是 tar.gz —— 与上游一致。
EXPECTED_SOURCES = {
    "linux":   "slang-${version}-linux-${arch}.${ext}",
    "macosx":  "slang-${version}-macos-${arch}.${ext}",
    "windows": "slang-${version}-windows-${arch}.${ext}",
}

EXPECTED_ARCHES = ("x86_64", "aarch64")


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def content(meta):
    return meta.raw_content


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
    @pytest.mark.parametrize("platform", sorted(EXPECTED_SOURCES))
    def test_platform_supported(self, meta, platform):
        assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_programs_declared(self, meta):
        # xvm 为这四个名字注册 shim；programs 与 config() 必须一致，
        # 否则装完会出现「注册了但不存在」或「存在但没 shim」。
        assert set(meta.programs) == {"slangc", "slangd", "slangi", "slang"}


class TestResources:
    @pytest.mark.static
    @pytest.mark.parametrize("platform", sorted(EXPECTED_SOURCES))
    def test_platform_source_template(self, content, platform):
        assert EXPECTED_SOURCES[platform] in content, (
            f"{platform} 的 source 模板缺失或不匹配: {EXPECTED_SOURCES[platform]}"
        )

    @pytest.mark.static
    def test_per_arch_sha256(self, content):
        # spec=2 要求每个架构都有校验和：缺一个就是 fail-closed 的安装失败，
        # 而不是静默装上另一个架构的二进制（正是 V2 要消灭的 V1 缺陷）。
        digests = re.findall(r'(x86_64|aarch64)\s*=\s*"([0-9a-f]{64})"', content)
        assert len(digests) == len(EXPECTED_SOURCES) * len(EXPECTED_ARCHES), (
            f"期望 {len(EXPECTED_SOURCES) * len(EXPECTED_ARCHES)} 个 per-arch 摘要，"
            f"实得 {len(digests)}"
        )
        for arch in EXPECTED_ARCHES:
            got = [d for a, d in digests if a == arch]
            assert len(got) == len(EXPECTED_SOURCES), f"{arch} 缺少某个平台的摘要"
            assert len(set(got)) == len(got), (
                f"{arch} 在不同平台上出现了重复摘要——多半是复制粘贴错误"
            )

    @pytest.mark.static
    def test_latest_ref(self, content):
        refs = re.findall(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"\s*\}', content)
        assert len(refs) == len(EXPECTED_SOURCES), "每个平台都要有 latest -> 具体版本"
        assert set(refs) == {VERSION}


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

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        # 上游 Linux 归档约 77 MiB，默认 180s 在慢网络上不够。
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_slangc(self):
        assert_command_output("slangc -v", regex=re.escape(VERSION))

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_slangc(self):
        assert_xvm_registered("slangc")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_slangd(self):
        assert_xvm_registered("slangd")
