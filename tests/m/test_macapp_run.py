"""Tests for the macapp-run package.

The program runs a macOS application bundle's executable in the foreground.
What can be checked without macOS is what the program does with its operand:
the refusals it prints, the executable it computes, and that nothing stands
between the program and its caller. The bundle run itself is measured by
.github/workflows/apple-runners.yml on a macOS runner.
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

PKG = "macapp-run"
PKG_FILE = "pkgs/m/macapp-run.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    from tests.lib.platform_utils import project_root
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


@pytest.fixture(scope='module')
def script(source_text):
    m = re.search(r'__macapp_run_sh = \[==\[(.*?)\]==\]', source_text, re.S)
    assert m, "the embedded macapp-run script was not found"
    return m.group(1)


@pytest.fixture(scope='module')
def script_code(script):
    return "\n".join(l for l in script.splitlines()
                     if not l.lstrip().startswith("#"))


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
    def test_macosx_only_and_no_url(self, source_text):
        """An application bundle is a macOS structure; the program is this
        recipe's own text, so there is no release to pin."""
        code = re.sub(r'--.*', '', source_text)
        assert re.search(r'\bmacosx\s*=\s*\{', code)
        for other in ('linux', 'windows'):
            assert not re.search(r'\b' + other + r'\s*=\s*\{', code)
        assert 'url' not in code

    @pytest.mark.static
    def test_the_script_is_valid_shell(self, script, tmp_path):
        import subprocess
        p = tmp_path / "macapp-run"
        p.write_text(script, encoding="utf-8")
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr

    @pytest.mark.static
    def test_the_program_replaces_the_shell(self, script_code):
        """The last command is `exec` of the bundle's executable with every
        argument, so the program's streams, status and signals reach the
        caller with nothing in between -- the property `open -W` lacks."""
        lines = [l for l in script_code.splitlines() if l.strip()]
        assert lines[-1].strip() == 'exec "$program" "$@"'
        assert 'set -e\n' not in script_code and 'set -euo' not in script_code
        assert not re.search(r'\bopen\s+-W\b', script_code)

    @pytest.mark.static
    def test_the_executable_is_the_bundles_own(self, script_code):
        """`Contents/MacOS/<CFBundleExecutable>`, read from the bundle's
        Info.plist, under an absolute bundle path so the main bundle resolves
        whatever the caller's working directory is."""
        assert 'plist="$bundle/Contents/Info.plist"' in script_code
        assert "CFBundleExecutable" in script_code
        assert 'root=$(cd "$bundle" && pwd)' in script_code
        assert 'program="$root/Contents/MacOS/$exe"' in script_code

    @pytest.mark.static
    def test_every_refusal_names_what_is_missing_and_exits_2(self, script):
        for wanted in ("does not exist", "is not a directory",
                       "has no Contents/Info.plist", "names no CFBundleExecutable",
                       "has no Contents/MacOS/", "is not executable"):
            assert wanted in script, f"no refusal names: {wanted}"
        refusals = re.findall(r'echo "macapp-run: [^"]*" >&2\n\s*exit (\d+)', script)
        assert len(refusals) >= 6 and set(refusals) == {"2"}, refusals

    @pytest.mark.static
    def test_the_program_goes_in_bin_and_is_registered_once(self, source_text):
        """mcpp's runner lookup searches `<payload>/bin`. The package and the
        program share a name, so one registration serves both."""
        code = re.sub(r'--.*', '', source_text)
        assert re.search(r'bindir\s*=\s*path\.join\(dir,\s*"bin"\)', code)
        assert re.search(r'program\s*=\s*path\.join\(bindir,\s*"macapp-run"\)', code)
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert config.count("xvm.add(") == 1
        assert 'xvm.add(package.name, { bindir = path.join(pkginfo.install_dir(), "bin") })' in config


class TestRefusalsOnAnyHost:
    """The refusals that precede reading the property list run on any POSIX
    host: they are checks of the operand's shape."""

    @pytest.fixture
    def program(self, script, tmp_path):
        import stat
        p = tmp_path / "macapp-run"
        p.write_text(script.lstrip("\n"), encoding="utf-8")
        p.chmod(p.stat().st_mode | stat.S_IEXEC)
        return p

    def _run(self, program, *args):
        import subprocess
        return subprocess.run([str(program), *args], capture_output=True, text=True, timeout=30)

    @pytest.mark.static
    @skip_if_not('linux')
    def test_no_operand(self, program):
        r = self._run(program)
        assert r.returncode == 2 and "usage" in r.stderr

    @pytest.mark.static
    @skip_if_not('linux')
    def test_a_missing_bundle(self, program, tmp_path):
        r = self._run(program, str(tmp_path / "Absent.app"))
        assert r.returncode == 2 and "does not exist" in r.stderr

    @pytest.mark.static
    @skip_if_not('linux')
    def test_a_file_is_not_a_bundle(self, program, tmp_path):
        f = tmp_path / "file.app"
        f.write_text("", encoding="utf-8")
        r = self._run(program, str(f))
        assert r.returncode == 2 and "is not a directory" in r.stderr

    @pytest.mark.static
    @skip_if_not('linux')
    def test_a_bundle_without_info_plist(self, program, tmp_path):
        b = tmp_path / "NoPlist.app" / "Contents" / "MacOS"
        b.mkdir(parents=True)
        r = self._run(program, str(tmp_path / "NoPlist.app") + "/")
        assert r.returncode == 2 and "has no Contents/Info.plist" in r.stderr


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('macosx')
    def test_installed_program_is_executable(self):
        from tests.lib.platform_utils import xpkgs_dir
        import glob
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(os.path.join(
                xpkgs_dir(), f"{ns}-x-macapp-run", "*", "bin", "macapp-run")))
        assert hits, "no installed bin/macapp-run found"
        assert os.access(hits[-1], os.X_OK), f"{hits[-1]} is not executable"
