"""测试 jdk8-temurin 包"""
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

PKG = "jdk8-temurin"
PKG_FILE = "pkgs/j/jdk8-temurin.lua"

PLATFORMS = ("linux", "windows")
# One resource per (platform, arch): linux x2, windows x1 (macosx omitted: no arm64 build).
RESOURCE_COUNT = 3


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
    def test_version_aliases(self, meta):
        """每个平台都要声明 latest、8.0.512 与 8u512b09 -> 8.0.512+9 别名"""
        code = _code(meta.raw_content)
        for alias in ("latest", "8.0.512", "8u512b09"):
            matches = re.findall(
                rf'\["{re.escape(alias)}"\]\s*=\s*\{{\s*ref\s*=\s*"8\.0\.512\+9"\s*\}}',
                code,
            )
            assert len(matches) == len(PLATFORMS), (
                f"{alias} -> 8.0.512+9 别名应覆盖 {PLATFORMS}, 实际 {len(matches)} 个"
            )

    @pytest.mark.static
    def test_resources_and_sha256(self, meta):
        """每个声明的资源都要有经过校验的 GitHub release URL、sha256 以及当前可用的 TUNA CN 镜像"""
        code = _code(meta.raw_content)
        gh_urls = re.findall(
            r'https://github\.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/[^"]+',
            code,
        )
        cn_urls = re.findall(
            r'CN = "https://mirrors\.tuna\.tsinghua\.edu\.cn/Adoptium/8/jdk/[^"]*8u512b09[^"]*"',
            code,
        )
        shas = re.findall(r'sha256 = "[0-9a-f]{64}"', code)
        assert len(gh_urls) == RESOURCE_COUNT, f"GitHub 源数量: {len(gh_urls)}"
        assert len(cn_urls) == 2, f"TUNA CN 镜像数量(linux.aarch64/windows.x86_64): {len(cn_urls)}"
        assert len(shas) == RESOURCE_COUNT, f"sha256 数量: {len(shas)}"

    @pytest.mark.static
    def test_no_jshell_in_jdk8(self, meta):
        """JDK 8 早于 JDK 9 引入的 jshell, programs 与 hooks 不得包含 jshell"""
        assert "jshell" not in meta.programs, "JDK 8 不包含 jshell"
        assert "jshell" not in _code(meta.raw_content), "JDK 8 配方代码不应引用 jshell"

    @pytest.mark.static
    def test_no_macosx_platform(self, meta):
        """Adoptium 不提供 Temurin 8 macosx aarch64 构建, 且 macos-latest CI 运行在 arm64, 故不声明 xpm.macosx"""
        assert "macosx" not in meta.platforms, "macosx 应省略 (无 Apple Silicon 构建)"
        assert not re.search(r'\bmacosx\s*=', _code(meta.raw_content)), \
            "xpm 不应声明 macosx 段"

    @pytest.mark.static
    def test_jdk8_dir_layout(self, meta):
        """JDK 8 归档顶层目录为 jdk8u<upd>-b<bld>"""
        code = _code(meta.raw_content)
        assert "jdk%su%s-b%02d" in code, "必须把 8.0.512+9 映射为 jdk8u512-b09 目录名"

    @pytest.mark.static
    def test_shared_names_are_flavor_scoped(self, meta):
        """java/javac/jar/javadoc 是所有 JDK 发行版共享的名字, 必须带 flavor 版本"""
        code = _code(meta.raw_content)
        assert re.search(r'FLAVOR\s*=\s*"temurin"', code), "FLAVOR 必须为 temurin"
        assert re.search(r'version\s*=\s*flavor_version\(\)', code), \
            "共享程序名必须用 flavor_version() 注册"
        assert re.search(r'pkginfo\.version\(\)\s*\.\.\s*"-"\s*\.\.\s*FLAVOR', code), \
            "flavor_version 必须是 <version>-<flavor>"
        assert 'binding = "jdk8-temurin@" .. pkginfo.version()' in code or (
            'local binding = "jdk8-temurin@" .. pkginfo.version()' in code
        ), "binding root 必须是 jdk8-temurin@<version>"
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
        # java prints its version banner on stderr.
        assert_command_output("java -version 2>&1", contains="1.8.0_512")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_javac_version(self):
        assert_command_output("javac -version 2>&1", contains="1.8.0_512")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_points_at_xpkg(self):
        """java.home 必须落在本包的安装目录里 (macOS 上即 Contents/Home 那一层)"""
        assert_command_output(
            "java -XshowSettings:properties -version 2>&1",
            regex=r"java\.home = .*jdk8-temurin",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_env_reaches_jvm(self):
        """config 注册的 JAVA_HOME 必须真的进到 java/javac 进程的环境里 (JDK 8 无 jshell)"""
        assert_command_output(
            'd=$(mktemp -d) && trap "rm -rf \\"$d\\"" EXIT && '
            'printf \'public class EnvCheck { public static void main(String[] a) { System.out.println("JH=[" + System.getenv("JAVA_HOME") + "]"); } }\\n\' > "$d/EnvCheck.java" && '
            'javac "$d/EnvCheck.java" && java -cp "$d" EnvCheck 2>&1',
            regex=r"JH=\[.*jdk8-temurin.*\]",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_java(self):
        assert_xvm_registered("java")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_javac(self):
        assert_xvm_registered("javac")
