"""Tests for the bundletool package.

The payload is one jar for every host and a launcher this recipe writes. The
assertions cover the pins (one url and one sha256 across platforms, the JDK at
its exact store key) and the launchers as they are rendered by install(). The
installed program is run on Linux, macOS and Windows by
.github/workflows/bundletool.yml, and through an mcpp consumer by
.github/workflows/consumer-through-index-override.yml.
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

PKG = "bundletool"
PKG_FILE = "pkgs/b/bundletool.lua"


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
    def test_one_jar_for_every_platform(self, code):
        """The jar has no per-host variant: every platform section names the
        same url and the same digest."""
        urls = re.findall(r'GLOBAL = "([^"]+)"', code)
        digests = re.findall(r'sha256 = "([0-9a-f]{64})"', code)
        assert len(urls) == 3 and len(set(urls)) == 1, urls
        assert len(digests) == 3 and len(set(digests)) == 1, digests
        assert urls[0].endswith("/1.18.3/bundletool-all-1.18.3.jar")

    @pytest.mark.static
    def test_the_jdk_is_pinned_to_its_exact_store_key(self, code):
        """A range can match jdk-temurin's alias key `25.0.4`, which resolves
        `pkginfo.dep_install_dir` to a directory that does not exist (recorded
        in pkgs/a/android-build-tools.lua)."""
        deps = re.findall(r'deps = \{ runtime = \{ "([^"]+)" \} \}', code)
        assert deps == ["xim:jdk-temurin@25.0.4+7"] * 3, deps

    @pytest.mark.static
    def test_the_program_is_registered_under_the_package_name(self, meta, code):
        assert meta.programs == ["bundletool"]
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert config.count("xvm.add(package.name") == 2  # one per host branch
        assert 'filename = "bundletool.bat"' in config

    @pytest.mark.static
    def test_the_posix_launcher_is_valid_shell_and_execs_java(self, meta, tmp_path):
        import subprocess
        text = _lua_format(_template(meta.raw_content, "local POSIX_LAUNCHER"),
                           "/opt/jdk", "/opt/bundletool/bundletool-all.jar")
        p = tmp_path / "bundletool"
        p.write_text(text, encoding="utf-8")
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        assert 'JAVA_HOME="/opt/jdk"' in text
        assert text.rstrip().endswith('exec "$JAVA_HOME/bin/java" -jar "/opt/bundletool/bundletool-all.jar" "$@"')

    @pytest.mark.static
    @skip_if_not('linux')
    def test_the_posix_launcher_refuses_without_a_jdk(self, meta, tmp_path):
        """With the baked JDK absent and no xim-x-jdk-* in the store, the
        launcher names the dependency and exits 2 instead of failing inside
        an exec."""
        import stat
        import subprocess
        store = tmp_path / "xpkgs"
        bindir = store / "xim-x-bundletool" / "1.18.3" / "bin"
        bindir.mkdir(parents=True)
        text = _lua_format(_template(meta.raw_content, "local POSIX_LAUNCHER"),
                           str(tmp_path / "missing-jdk"), str(bindir.parent / "bundletool-all.jar"))
        p = bindir / "bundletool"
        p.write_text(text, encoding="utf-8")
        p.chmod(p.stat().st_mode | stat.S_IEXEC)
        r = subprocess.run([str(p), "version"], capture_output=True, text=True, timeout=30)
        assert r.returncode == 2, r.stdout + r.stderr
        assert "Declare xim:jdk-temurin as a dependency" in r.stderr
        assert str(store) in r.stderr, "the refusal does not name the store it searched"

    @pytest.mark.static
    def test_the_windows_launcher_prefers_its_own_jdk(self, meta):
        """The baked JDK is tried first and JAVA_HOME only when it is absent:
        on windows-2022 an xvm `envs` JAVA_HOME was joined to the runner's own
        with `;`, and a launcher that read the variable first found nothing."""
        text = _lua_format(_template(meta.raw_content, "local WINDOWS_LAUNCHER"),
                           "C:\\jdk", "C:\\x\\bundletool-all.jar", "C:\\jdk")
        lines = text.splitlines()
        own = lines.index('set "BUNDLETOOL_JAVA=C:\\jdk\\bin\\java.exe"')
        fallback = lines.index('set "BUNDLETOOL_JAVA=%JAVA_HOME%\\bin\\java.exe"')
        assert own < lines.index('if exist "%BUNDLETOOL_JAVA%" goto run') < fallback
        assert '"%BUNDLETOOL_JAVA%" -jar "C:\\x\\bundletool-all.jar" %*' in text
        assert "exit /b %ERRORLEVEL%" in text
        assert "exit /b 2" in text
        assert "(" not in "".join(l for l in lines if l.startswith("if ")), \
            "a parenthesised block breaks on a path that contains parentheses"

    @pytest.mark.static
    def test_the_windows_registration_passes_no_environment(self, code):
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert "envs" not in config


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)
