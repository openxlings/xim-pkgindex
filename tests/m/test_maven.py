"""Tests for the maven package.

The payload is Apache Maven's official distribution archive, one file for every
host, and the launcher this recipe writes around upstream's script. The
assertions cover the pins (one url pair and one sha256 across platforms, the
JDK at its exact store key), `installed()` / `config()` registration, and the
launcher as install() renders it. Installing and running it is covered by the
lifecycle and verify marks.
"""
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_config_registers_package_name, assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds, assert_install_succeeds, assert_command_output,
)
from tests.lib.platform_utils import skip_if_not

PKG = "maven"
PKG_FILE = "pkgs/m/maven.lua"

VERSION = "3.9.16"
ARCHIVE = f"apache-maven-{VERSION}-bin.zip"
SHA256 = "5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def code(meta):
    """The recipe without its comments, so a test never matches prose."""
    return "\n".join(l for l in meta.raw_content.splitlines()
                     if not l.lstrip().startswith("--"))


def _template(source: str, name: str) -> str:
    m = re.search(name + r' = \[==\[\n(.*?)\]==\]', source, re.S)
    assert m, f"{name} was not found"
    return m.group(1)


def _lua_format(template: str, *values: str) -> str:
    """string.format for the two directives the launchers use: `%s` and `%%`."""
    out, it = [], iter(values)
    i = 0
    while i < len(template):
        if template.startswith("%%", i):
            out.append("%")
            i += 2
        elif template.startswith("%s", i):
            out.append(next(it))
            i += 2
        else:
            out.append(template[i])
            i += 1
    assert next(it, None) is None, "more values than %s directives"
    return "".join(out)


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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_one_archive_for_every_platform(self, code):
        """Maven is JVM bytecode: every platform section names the same archive
        and the digest derived from Apache's official .sha512 release sidecar."""
        urls = re.findall(r'GLOBAL = "([^"]+)"', code)
        mirrors = re.findall(r'CN = "([^"]+)"', code)
        digests = re.findall(r'sha256 = "([0-9a-f]{64})"', code)
        expected = {
            VERSION: SHA256,
        }
        assert len(urls) == len(mirrors) == len(digests) == 3 * len(expected)
        for version, digest in expected.items():
            archive = f"apache-maven-{version}-bin.zip"
            assert urls.count(f"https://archive.apache.org/dist/maven/maven-3/{version}/binaries/{archive}") == 3
            assert mirrors.count(f"https://mirrors.cloud.tencent.com/apache/maven/maven-3/{version}/binaries/{archive}") == 3
            assert digests.count(digest) == 3

    @pytest.mark.static
    def test_the_jdk_is_pinned_to_its_exact_store_key(self, code):
        """The exact store key gradle.lua/kotlin.lua declare, so a consumer that
        already has that JDK installs no second one."""
        deps = re.findall(r'deps = \{ runtime = \{ "([^"]+)" \} \}', code)
        assert deps == ["xim:jdk-temurin@25.0.4+7"] * 3, deps

    @pytest.mark.static
    def test_the_versioned_tree_is_named_from_the_version(self, code):
        """The archive's top directory carries the version (`apache-maven-3.9.16/`),
        and it is named from pkginfo.version() rather than reached by a glob."""
        assert 'local root = "apache-maven-" .. pkginfo.version()' in code
        assert "if complete(named) then return named end" in code
        assert 'path.join(root, "bin", "mvn")' in code
        assert 'path.join(root, "bin", "mvn.cmd")' in code
        assert "path.absolute" not in code, "path.absolute is not bound in the xpkg sandbox"

    @pytest.mark.static
    def test_the_hook_cwd_is_searched_by_bare_name(self, code):
        """`find_tree(nil)` -- not `find_tree(".")`."""
        assert "find_tree(nil) or find_tree(dir)" in code

    @pytest.mark.static
    def test_installed_checks_files_not_directories(self, meta, code):
        assert meta.has_installed
        body = code[code.index("function installed()"):code.index("function install()")]
        assert "os.isdir" not in body
        assert "os.isfile" in body

    @pytest.mark.static
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_program_and_package_group_registered(self, meta, code):
        assert meta.programs == ["mvn"]
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert 'filename = "mvn.bat"' in config
        assert 'xvm.add("maven", { type = "group" })' in config
        uninstall = code[code.index("function uninstall()"):]
        assert 'xvm.remove("mvn")' in uninstall
        assert 'xvm.remove("maven")' in uninstall

    @pytest.mark.static
    def test_the_posix_launcher_is_valid_shell_and_execs_upstream(self, meta, tmp_path):
        text = _lua_format(_template(meta.raw_content, "local POSIX_LAUNCHER"),
                           "/opt/jdk", "/opt/maven/maven/bin/mvn")
        script = tmp_path / "mvn"
        script.write_text(text)
        subprocess.run(["bash", "-n", str(script)], check=True)
        assert 'JAVA_HOME="/opt/jdk"' in text
        assert 'exec "/opt/maven/maven/bin/mvn" "$@"' in text

    @pytest.mark.static
    def test_the_windows_launcher_calls_upstreams_cmd(self, meta):
        text = _lua_format(_template(meta.raw_content, "local WINDOWS_LAUNCHER"),
                           r"C:\jdk", r"C:\maven\maven\bin\mvn.cmd", r"C:\jdk")
        assert r'set "MAVEN_JDK=C:\jdk"' in text
        assert r'call "C:\maven\maven\bin\mvn.cmd" %*' in text
        assert "(" not in text.split("\n")[3], "a parenthesised block would end at a path's parenthesis"


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
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_mvn_runs(self):
        assert_command_output("mvn --version", contains=f"Apache Maven {VERSION}")
