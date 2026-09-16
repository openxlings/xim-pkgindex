"""Tests for the gradle package.

The payload is Gradle's own distribution archive, one file for every host, and
the launcher this recipe writes around upstream's script. The assertions cover
the pins (one url pair and one sha256 across platforms, the JDK at its exact
store key) and the launcher as install() renders it. Installing and running it
is covered by the lifecycle and verify marks.
"""
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds, assert_command_output,
)
from tests.lib.platform_utils import skip_if_not

PKG = "gradle"
PKG_FILE = "pkgs/g/gradle.lua"

VERSION = "9.7.1"
ARCHIVE = f"gradle-{VERSION}-bin.zip"
SHA256 = "acd53f1edaf02f1a8ff99879f8a34b302661a057d9b063ae9e35b552f804d20a"


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
    def test_one_archive_for_every_platform(self, code):
        """Gradle is JVM bytecode: every platform section names the same archive
        and the digest Gradle publishes beside it."""
        urls = re.findall(r'GLOBAL = "([^"]+)"', code)
        mirrors = re.findall(r'CN = "([^"]+)"', code)
        digests = re.findall(r'sha256 = "([0-9a-f]{64})"', code)
        assert len(urls) == 3 and len(set(urls)) == 1, urls
        assert len(mirrors) == 3 and len(set(mirrors)) == 1, mirrors
        assert len(digests) == 3 and len(set(digests)) == 1, digests
        assert urls[0] == f"https://services.gradle.org/distributions/{ARCHIVE}"
        assert mirrors[0] == f"https://mirrors.cloud.tencent.com/gradle/{ARCHIVE}"
        assert digests[0] == SHA256

    @pytest.mark.static
    def test_the_jdk_is_pinned_to_its_exact_store_key(self, code):
        """The key kotlin.lua declares, so a consumer that already has that JDK
        installs no second one; a range could match an alias key that resolves
        to a directory which does not exist (pkgs/a/android-build-tools.lua)."""
        deps = re.findall(r'deps = \{ runtime = \{ "([^"]+)" \} \}', code)
        assert deps == ["xim:jdk-temurin@25.0.4+7"] * 3, deps

    @pytest.mark.static
    def test_the_versioned_tree_is_named_from_the_version(self, code):
        """The archive's top directory carries the version (`gradle-9.7.1/`), and
        it is NAMED from pkginfo.version() rather than reached by a glob.

        Measured, 2026-09-16: the first cut globbed, and the isolated install
        failed with "the archive's gradle-<version>/ tree was not found" while
        the tree sat in the hook's working directory -- `os.dirs` does not
        resolve a relative pattern against it, and `jdk-temurin.lua` /
        `kotlin.lua` both reach their payload by bare relative name for the
        same reason. The glob survives only as a fallback."""
        assert 'local root = "gradle-" .. pkginfo.version()' in code
        assert "if complete(named) then return named end" in code
        assert 'path.join(root, "bin", "gradle")' in code
        assert "path.absolute" not in code, "path.absolute is not bound in the xpkg sandbox"

    @pytest.mark.static
    def test_the_hook_cwd_is_searched_by_bare_name(self, code):
        """`find_tree(nil)` -- not `find_tree(".")`. The sibling recipes that
        work (`jdk-temurin.lua`'s `jdk-<version>`, `kotlin.lua`'s `kotlinc`)
        all name the payload without a `./` prefix."""
        assert "find_tree(nil) or find_tree(dir)" in code

    @pytest.mark.static
    def test_one_program_is_registered(self, meta, code):
        assert meta.programs == ["gradle"]
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert 'filename = "gradle.bat"' in config
        assert 'type = "group"' not in config

    @pytest.mark.static
    def test_the_posix_launcher_is_valid_shell_and_execs_upstream(self, meta, tmp_path):
        text = _lua_format(_template(meta.raw_content, "local POSIX_LAUNCHER"),
                           "/opt/jdk", "/opt/gradle/gradle/bin/gradle")
        script = tmp_path / "gradle"
        script.write_text(text)
        subprocess.run(["bash", "-n", str(script)], check=True)
        assert 'JAVA_HOME="/opt/jdk"' in text
        assert 'exec "/opt/gradle/gradle/bin/gradle" "$@"' in text

    @pytest.mark.static
    def test_the_windows_launcher_calls_upstreams_bat(self, meta):
        text = _lua_format(_template(meta.raw_content, "local WINDOWS_LAUNCHER"),
                           r"C:\jdk", r"C:\gradle\gradle\bin\gradle.bat", r"C:\jdk")
        assert r'set "GRADLE_JDK=C:\jdk"' in text
        assert r'call "C:\gradle\gradle\bin\gradle.bat" %*' in text
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
    def test_gradle_runs(self):
        assert_command_output("gradle --version", contains="Gradle")
