"""测试 jdk-corretto 包"""
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

PKG = "jdk-corretto"
PKG_FILE = "pkgs/j/jdk-corretto.lua"

PLATFORMS = ("linux", "macosx", "windows")
# 2 个版本 (25 / 21 LTS) x 每平台的架构数: linux 2 + macosx 2 + windows 1 = 5
RESOURCE_COUNT = 10
VERSIONS = {"25.0.4.7.1": "25.0.4", "21.0.12.8.1": "21.0.12"}


def _code(content: str) -> str:
    """去掉 lua 行注释, 让下面的静态断言只看真实声明 (注释里也写了这些字面量)"""
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
        """Corretto 版本是五段式, `java --version` 只显示前三段, 两种拼法都要能装"""
        code = _code(meta.raw_content)
        for full, plain in VERSIONS.items():
            aliases = re.findall(
                rf'\["{re.escape(plain)}"\]\s*=\s*\{{\s*ref\s*=\s*"{re.escape(full)}"\s*\}}',
                code,
            )
            assert len(aliases) == len(PLATFORMS), \
                f"{plain} -> {full} 别名应覆盖 {PLATFORMS}, 实际 {len(aliases)} 个"

    @pytest.mark.static
    def test_every_resource_has_cn_mirror(self, meta):
        """每个资源都要有 GLOBAL(upstream) + CN(gitcode) 两个源, 且 sha256 齐全"""
        code = _code(meta.raw_content)
        global_urls = re.findall(r'GLOBAL = "https://corretto\.aws/[^"]+"', code)
        cn_urls = re.findall(
            r'CN = "https://gitcode\.com/xlings-res/jdk-corretto/[^"]+"', code)
        shas = re.findall(r'sha256 = "[0-9a-f]{64}"', code)
        assert len(global_urls) == RESOURCE_COUNT, f"GLOBAL 源数量: {len(global_urls)}"
        assert len(cn_urls) == RESOURCE_COUNT, f"CN 源数量: {len(cn_urls)}"
        assert len(shas) == RESOURCE_COUNT, f"sha256 数量: {len(shas)}"

    @pytest.mark.static
    def test_payload_layout_per_platform(self, meta):
        """三个平台的解包目录名各不相同, 缺任何一支都会装成空目录"""
        code = _code(meta.raw_content)
        assert '"amazon-corretto-" .. (feature or version) .. ".jdk"' in code, \
            "macOS 是 .jdk bundle, 目录名只带 feature 版本"
        assert re.search(r'"Contents"\s*,\s*"Home"', code), \
            "macOS payload 必须取内层 Contents/Home"
        assert '"jdk" .. java_version .. "_" .. build' in code, \
            "windows 目录名是 jdk<java version>_<build>"
        assert "archive_stem()" in code, \
            "linux 目录名带 arch, 只能从归档名推导 (hook 里没有 os.arch)"

    @pytest.mark.static
    def test_shared_names_are_flavor_scoped(self, meta):
        """java/javac 等是所有 JDK 发行版共享的名字, 必须带 flavor 版本

        用裸的数字版本注册的话, 另一个 JDK 发行版想注册同名同版本会被 xvm 直接
        拒绝 (another package already owns this exact name and version), 整个
        config 批次失败 —— 等于两个发行版互斥。
        """
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
        # The Corretto 25 tarball is ~220MB; the default 180s can be tight on a
        # cold cache.
        assert_install_succeeds(PKG, timeout=420)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_version(self):
        # java prints its version banner on stderr. Assert the vendor string too:
        # "25" alone would also match a pre-existing system JDK.
        assert_command_output("java -version 2>&1", contains="Corretto-25.0.4")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_javac_version(self):
        assert_command_output("javac -version", contains="25.0.4")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_points_at_xpkg(self):
        assert_command_output(
            "java -XshowSettings:properties -version 2>&1",
            regex=r"java\.home = .*jdk-corretto",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_env_reaches_jvm(self):
        """config 注册的 JAVA_HOME 必须真的进到 java 进程的环境里 (maven/gradle 靠它)"""
        assert_command_output(
            '''echo 'System.out.println("JH=[" + System.getenv("JAVA_HOME") + "]");' '''
            '''| jshell -s - 2>&1''',
            regex=r"JH=\[.*jdk-corretto.*\]",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_java(self):
        assert_xvm_registered("java")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_javac(self):
        assert_xvm_registered("javac")
