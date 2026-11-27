"""Tests for the kotlin package.

The payload is JetBrains' compiler archive, one file for every host, and the
launchers this recipe writes around upstream's scripts. The assertions cover
the pins (one url and one sha256 across platforms, the JDK at its exact store
key) and the launchers as install() renders them. The installed compiler
compiles and runs a program on Linux, macOS and Windows in
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
    assert_xim_add_succeeds, assert_install_succeeds, assert_uninstall_succeeds,
)
from tests.lib.platform_utils import skip_if_not

PKG = "kotlin"
PKG_FILE = "pkgs/k/kotlin.lua"


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
    def test_one_archive_for_every_platform(self, code):
        """The compiler is JVM bytecode: every platform section names the same
        archive and the digest JetBrains publishes beside it, listed for each
        architecture it serves (the same bytes for both, design 2026-11-27 §5.3)."""
        urls = re.findall(r'GLOBAL = "([^"]+)"', code)
        listed = re.findall(r'sha256 = \{ x86_64 = "([0-9a-f]{64})", aarch64 = "([0-9a-f]{64})" \}', code)
        assert all(x86 == arm for x86, arm in listed), listed
        digests = [x86 for x86, _ in listed]
        mirrors = re.findall(r'CN = "([^"]+)"', code)
        assert mirrors == ["https://gitcode.com/xlings-res/kotlin/releases/download/2.4.20/kotlin-compiler-2.4.20.zip"] * 3, mirrors
        assert len(urls) == 3 and len(set(urls)) == 1, urls
        assert len(digests) == 3 and len(set(digests)) == 1, digests
        assert urls[0] == ("https://github.com/JetBrains/kotlin/releases/download/"
                           "v2.4.20/kotlin-compiler-2.4.20.zip")
        assert digests[0] == "59e9ca74c7904ef2c122b12114937673ccce68de820a663f0ed66ccf8799e0b7"

    @pytest.mark.static
    def test_the_jdk_is_pinned_to_its_exact_store_key(self, code):
        """The key bundletool.lua and mcpp:plugins' dist-apk declare, so a
        consumer that has that JDK installs no second one; a range could match
        the alias key `25.0.4`, which resolves to a directory that does not
        exist (recorded in pkgs/a/android-build-tools.lua)."""
        deps = re.findall(r'deps = \{ runtime = \{ "([^"]+)" \} \}', code)
        assert deps == ["xim:jdk-temurin@25.0.4+7"] * 3, deps

    @pytest.mark.static
    def test_both_programs_are_registered(self, meta, code):
        assert meta.programs == ["kotlinc", "kotlin"]
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert 'filename = name .. ".bat"' in config
        assert "type = \"group\"" not in config, \
            "a group named `kotlin` collides with the `kotlin` program's node"

    @pytest.mark.static
    def test_the_stdlib_is_part_of_a_complete_tree(self, code):
        """A consumer links compiled classes against `kotlinc/lib/kotlin-stdlib.jar`;
        install() refuses a tree that lacks it rather than registering a
        compiler whose stdlib is not where the layout says."""
        assert 'path.join(root, "lib", "kotlin-stdlib.jar")' in code
        assert 'path.join(dir, "kotlinc")' in code
        assert "path.absolute" not in code, "path.absolute is not bound in the xpkg sandbox"

    @pytest.mark.static
    def test_the_posix_launcher_is_valid_shell_and_execs_upstream(self, meta, tmp_path):
        import subprocess
        text = _lua_format(_template(meta.raw_content, "local POSIX_LAUNCHER"),
                           "/opt/jdk", "/opt/kotlin/kotlinc/bin/kotlinc")
        p = tmp_path / "kotlinc"
        p.write_text(text, encoding="utf-8")
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        assert 'JAVA_HOME="/opt/jdk"' in text
        assert text.rstrip().endswith('exec "/opt/kotlin/kotlinc/bin/kotlinc" "$@"')

    @pytest.mark.static
    @skip_if_not('linux')
    def test_the_posix_launcher_refuses_without_a_jdk(self, meta, tmp_path):
        import stat
        import subprocess
        store = tmp_path / "xpkgs"
        bindir = store / "xim-x-kotlin" / "2.4.20" / "bin"
        bindir.mkdir(parents=True)
        text = _lua_format(_template(meta.raw_content, "local POSIX_LAUNCHER"),
                           str(tmp_path / "missing-jdk"), str(bindir.parent / "kotlinc" / "bin" / "kotlinc"))
        p = bindir / "kotlinc"
        p.write_text(text, encoding="utf-8")
        p.chmod(p.stat().st_mode | stat.S_IEXEC)
        r = subprocess.run([str(p), "-version"], capture_output=True, text=True, timeout=30)
        assert r.returncode == 2, r.stdout + r.stderr
        assert "Declare xim:jdk-temurin as a dependency" in r.stderr
        assert str(store) in r.stderr, "the refusal does not name the store it searched"

    @pytest.mark.static
    def test_the_windows_launcher_prefers_its_own_jdk(self, meta):
        text = _lua_format(_template(meta.raw_content, "local WINDOWS_LAUNCHER"),
                           "C:\\jdk", "C:\\x\\kotlinc\\bin\\kotlinc.bat", "C:\\jdk")
        lines = text.splitlines()
        own = lines.index('set "KOTLIN_JDK=C:\\jdk"')
        fallback = lines.index('set "KOTLIN_JDK=%JAVA_HOME%"')
        assert own < lines.index('if exist "%KOTLIN_JDK%\\bin\\java.exe" goto run') < fallback
        assert 'call "C:\\x\\kotlinc\\bin\\kotlinc.bat" %*' in text
        assert "exit /b %ERRORLEVEL%" in text
        assert "exit /b 2" in text
        assert "(" not in "".join(l for l in lines if l.startswith("if ")), \
            "a parenthesised block breaks on a path that contains parentheses"


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


# The install job installs the planned packages and removes each one again
# before these tests run (posix-test.sh); the verify test reads the payload, so
# the package is installed here first and removed after it -- pytest runs the
# classes of a module in the order they are written.
class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_installed_compiler_is_executable(self):
        from tests.lib.platform_utils import xpkgs_dir
        import glob
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-kotlin", "*", "bin", "kotlinc")))
        assert hits, "no installed bin/kotlinc found"
        assert os.access(hits[-1], os.X_OK), f"{hits[-1]} is not executable"


class TestRemoval:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_uninstall(self):
        assert_uninstall_succeeds(PKG)
