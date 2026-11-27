"""Tests for the coursier package.

The payload is coursier's self-contained JVM launcher, one jar for every host,
and the launchers this recipe writes. The assertions cover the pins and the
launchers as install() renders them. The installed resolver fetches a Maven
Central jar and a Google Maven AAR graph on Linux, macOS and Windows in
.github/workflows/jvm-build-tools.yml.
"""
import os
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)
from tests.lib.platform_utils import skip_if_not

PKG = "coursier"
PKG_FILE = "pkgs/c/coursier.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def code(meta):
    return "\n".join(l for l in meta.raw_content.splitlines()
                     if not l.lstrip().startswith("--"))


def _template(source: str, name: str) -> str:
    m = re.search(name + r' = \[==\[\n(.*?)\]==\]', source, re.S)
    assert m, f"{name} was not found"
    return m.group(1)


def _lua_format(template: str, *values: str) -> str:
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
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.static
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.static
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.static
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.static
    def test_one_jar_for_every_platform(self, code):
        """The native launchers do not cover linux aarch64 or windows aarch64;
        the jar covers every host, so every platform names the same file --
        on Linux listed for both architectures, as a file with no machine code
        is (the install sweep installed it on both)."""
        urls = re.findall(r'GLOBAL = "([^"]+)"', code)
        digests = re.findall(r'sha256 = "([0-9a-f]{64})"', code)
        assert re.search(r'sha256 = \{ x86_64 = "([0-9a-f]{64})", aarch64 = "\1" \}', code)
        digests += re.findall(r'sha256 = \{ x86_64 = "([0-9a-f]{64})"', code)
        mirrors = re.findall(r'CN = "([^"]+)"', code)
        assert mirrors == ["https://gitcode.com/xlings-res/coursier/releases/download/2.1.24/coursier.jar"] * 3, mirrors
        assert len(urls) == 3 and len(set(urls)) == 1, urls
        assert len(digests) == 3 and len(set(digests)) == 1, digests
        assert urls[0] == "https://github.com/coursier/coursier/releases/download/v2.1.24/coursier.jar"
        assert digests[0] == "8c724dc204534353ea8263ba0af624979658f7ab62395f35b04f03ce5714f330"

    @pytest.mark.static
    def test_the_jdk_is_pinned_to_its_exact_store_key(self, code):
        deps = re.findall(r'deps = \{ runtime = \{ "([^"]+)" \} \}', code)
        assert deps == ["xim:jdk-temurin@25.0.4+7"] * 3, deps

    @pytest.mark.static
    def test_both_program_names_are_registered(self, meta, code):
        assert meta.programs == ["cs", "coursier"]
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert 'filename = name .. ".bat"' in config
        assert "type = \"group\"" not in config, \
            "a group named `coursier` collides with the `coursier` program's node"

    @pytest.mark.static
    def test_the_posix_launcher_is_valid_shell_and_execs_java(self, meta, tmp_path):
        import subprocess
        text = _lua_format(_template(meta.raw_content, "local POSIX_LAUNCHER"),
                           "/opt/jdk", "/opt/coursier/coursier.jar")
        p = tmp_path / "cs"
        p.write_text(text, encoding="utf-8")
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        assert 'JAVA_HOME="/opt/jdk"' in text
        assert text.rstrip().endswith('exec "$JAVA_HOME/bin/java" -jar "/opt/coursier/coursier.jar" "$@"')

    @pytest.mark.static
    @skip_if_not('linux')
    def test_the_posix_launcher_refuses_without_a_jdk(self, meta, tmp_path):
        import stat
        import subprocess
        store = tmp_path / "xpkgs"
        bindir = store / "xim-x-coursier" / "2.1.24" / "bin"
        bindir.mkdir(parents=True)
        text = _lua_format(_template(meta.raw_content, "local POSIX_LAUNCHER"),
                           str(tmp_path / "missing-jdk"), str(bindir.parent / "coursier.jar"))
        p = bindir / "cs"
        p.write_text(text, encoding="utf-8")
        p.chmod(p.stat().st_mode | stat.S_IEXEC)
        r = subprocess.run([str(p), "version"], capture_output=True, text=True, timeout=30)
        assert r.returncode == 2, r.stdout + r.stderr
        assert "Declare xim:jdk-temurin as a dependency" in r.stderr
        assert str(store) in r.stderr

    @pytest.mark.static
    def test_the_windows_launcher_prefers_its_own_jdk(self, meta):
        text = _lua_format(_template(meta.raw_content, "local WINDOWS_LAUNCHER"),
                           "C:\\jdk", "C:\\x\\coursier.jar", "C:\\jdk")
        lines = text.splitlines()
        own = lines.index('set "COURSIER_JAVA=C:\\jdk\\bin\\java.exe"')
        fallback = lines.index('set "COURSIER_JAVA=%JAVA_HOME%\\bin\\java.exe"')
        assert own < lines.index('if exist "%COURSIER_JAVA%" goto run') < fallback
        assert '"%COURSIER_JAVA%" %COURSIER_JAVA_OPTS% -jar "C:\\x\\coursier.jar" %*' in text

    @pytest.mark.static
    def test_only_the_declared_jdk_is_given_native_access(self, meta):
        """JDK 25 warns on stderr whenever coursier's Windows JNI helper loads
        (measured on windows-2022: four WARNING lines before `2.1.24`), and a
        JDK older than 22 refuses the flag that silences it, so the launcher
        passes it to the declared JDK and clears it on the JAVA_HOME path."""
        text = _lua_format(_template(meta.raw_content, "local WINDOWS_LAUNCHER"),
                           "C:\\jdk", "C:\\x\\coursier.jar", "C:\\jdk")
        lines = text.splitlines()
        given = lines.index('set "COURSIER_JAVA_OPTS=--enable-native-access=ALL-UNNAMED"')
        cleared = lines.index('set "COURSIER_JAVA_OPTS="')
        assert given < lines.index('if exist "%COURSIER_JAVA%" goto run')
        assert lines.index('set "COURSIER_JAVA=%JAVA_HOME%\\bin\\java.exe"') < cleared < lines.index(":run")
        assert not any("%" in l for l in lines if l.startswith("rem ")), \
            "a percent sign in a rem line is expanded by cmd"
        assert "exit /b %ERRORLEVEL%" in text
        assert "(" not in "".join(l for l in lines if l.startswith("if "))


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_installed_launcher_is_executable(self):
        from tests.lib.platform_utils import xpkgs_dir
        import glob
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-coursier", "*", "bin", "cs")))
        assert hits, "no installed bin/cs found"
        assert os.access(hits[-1], os.X_OK), f"{hits[-1]} is not executable"
