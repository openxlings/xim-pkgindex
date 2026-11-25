"""测试 jdk11-temurin 包"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "jdk11-temurin"
PKG_FILE = "pkgs/j/jdk11-temurin.lua"

PLATFORMS = ("linux", "macosx", "windows")
# One resource per (platform, arch): linux x2, macosx x2, windows x1.
RESOURCE_COUNT = 5


def _code(content: str) -> str:
    """去掉 lua 行注释, 让下面的静态断言只看真实声明"""
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


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
    def test_plain_version_alias(self, meta):
        """`java -version` 首行只显示 11.0.33, 所以每个平台都要有 11.0.33 -> 11.0.33+10 别名"""
        aliases = re.findall(
            r'\["11\.0\.33"\]\s*=\s*\{\s*ref\s*=\s*"11\.0\.33\+10"\s*\}',
            _code(meta.raw_content),
        )
        assert len(aliases) == len(PLATFORMS), \
            f"11.0.33 别名应覆盖 {PLATFORMS}, 实际 {len(aliases)} 个"

    @pytest.mark.static
    def test_every_resource_has_url_and_sha256(self, meta):
        """5 个目标的 upstream URL 与 sha256 必须齐全"""
        content = _code(meta.raw_content)
        urls = re.findall(
            r'url = "https://github\.com/adoptium/temurin11-binaries/releases/download/jdk-11\.0\.33%2B10/OpenJDK11U-jdk_[^"]+"',
            content,
        )
        shas = re.findall(r'sha256 = "[0-9a-f]{64}"', content)
        assert len(urls) == RESOURCE_COUNT, f"upstream URL 数量: {len(urls)}"
        assert len(shas) == RESOURCE_COUNT, f"sha256 数量: {len(shas)}"

    @pytest.mark.static
    def test_autoupdate_configured(self, meta):
        """extensions.autoupdate 应声明 temurin11-binaries 上游及 GLOBAL required"""
        content = _code(meta.raw_content)
        assert 'source = "https://github.com/adoptium/temurin11-binaries/releases"' in content
        assert 'tag = "jdk-${version}"' in content
        assert "required = true" in content

    @pytest.mark.static
    def test_macos_bundle_layout(self, meta):
        """macOS 是 .jdk bundle: bin 在 Contents/Home 下, 不能按 linux 布局搬运"""
        content = _code(meta.raw_content)
        assert re.search(r'os\.host\(\)\s*==\s*"macosx"', content), \
            "install 必须区分 macosx 布局"
        assert re.search(r'"Contents"\s*,\s*"Home"', content), \
            "macOS payload 必须是 jdk-<ver>/Contents/Home"

    @pytest.mark.static
    def test_shared_names_are_flavor_scoped(self, meta):
        """java/javac 等是所有 JDK 发行版共享的名字, 必须带 flavor 版本"""
        code = _code(meta.raw_content)
        assert re.search(r'version\s*=\s*flavor_version\(\)', code), \
            "共享程序名必须用 flavor_version() 注册"
        assert re.search(r'pkginfo\.version\(\)\s*\.\.\s*"-"\s*\.\.\s*FLAVOR', code), \
            "flavor_version 必须是 <version>-<flavor>"
        assert 'type = "group"' in code, \
            "binding root 应为 group 节点, 否则会留下永远失败的孤儿 shim"

    @pytest.mark.static
    def test_java_home_registered(self, meta):
        """JDK 只注册 shim 不给 JAVA_HOME 的话, maven/gradle 之类工具找不到它"""
        assert "JAVA_HOME" in _code(meta.raw_content), "config 应通过 xvm envs 提供 JAVA_HOME"


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


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG, timeout=420)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_version(self):
        assert_command_output("java -version 2>&1", contains="11.0.33+10")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_javac_version(self):
        assert_command_output("javac -version", contains="11.0.33")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_points_at_xpkg(self):
        """java.home 必须落在本包的安装目录里 (macOS 上即 Contents/Home 那一层)"""
        assert_command_output(
            "java -XshowSettings:properties -version 2>&1",
            regex=r"java\.home = .*jdk11-temurin",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_env_reaches_jvm(self):
        """config 注册的 JAVA_HOME 必须真的进到 java 进程的环境里 (maven/gradle 靠它)"""
        assert_command_output(
            '''echo 'System.out.println("JH=[" + System.getenv("JAVA_HOME") + "]");' '''
            '''| jshell -s - 2>&1''',
            regex=r"JH=\[.*jdk11-temurin.*\]",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_java(self):
        assert_xvm_registered("java")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_javac(self):
        assert_xvm_registered("javac")
