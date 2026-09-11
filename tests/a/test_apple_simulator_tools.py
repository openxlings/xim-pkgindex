"""Tests for the apple-simulator-tools package.

The program it ships is a SESSION -- choose a device, boot it, wait, spawn,
return the program's status -- which is why it is a package rather than a
manifest line. These tests assert the properties of that session that can be
checked without a simulator, because the recipe declares `macosx` only and
most runners are not that.
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

PKG = "apple-simulator-tools"
PKG_FILE = "pkgs/a/apple-simulator-tools.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    from tests.lib.platform_utils import project_root
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


@pytest.fixture(scope='module')
def script_code(script):
    """The program with its comments removed.

    SCOPED TO WHAT THE PROGRAM DOES, NOT TO THE CHARACTERS IN THE FILE. An
    assertion that `simctl spawn booted` does not appear matched the COMMENT
    explaining why that spelling is not used -- the same shape
    test_android_system_image.py records twice, and the reason it keeps
    recurring is that the explanation and the mistake use the same words.
    Assertions about refusal TEXT use `script`, because that text lives in the
    program's own strings; assertions about BEHAVIOUR use this.
    """
    return "\n".join(l for l in script.splitlines()
                      if not l.lstrip().startswith("#"))


@pytest.fixture(scope='module')
def script(source_text):
    """The shell program this recipe ships, extracted from its own text.

    Read from the recipe rather than from an installation: the assertions below
    are about what the program DOES, and that is a property of the source on
    every host.
    """
    m = re.search(r'\[==\[(.*?)\]==\]', source_text, re.S)
    assert m, "the embedded simctl-run script was not found"
    return m.group(1)


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
        """The simulator runtime is a proprietary component of its own OS.

        There is nothing to package and nothing to mirror, so this recipe
        declares `macosx` and no url -- and a url appearing here later would
        mean someone had started redistributing a piece of Xcode.
        """
        code = re.sub(r'--.*', '', source_text)
        assert 'macosx' in code
        for other in ('linux', 'windows'):
            assert not re.search(r'\b' + other + r'\s*=\s*\{', code), (
                f"a {other} table appeared; this program drives a runtime that "
                f"exists only on macOS"
            )
        assert 'url' not in code, "there is no upstream release to pin"

    @pytest.mark.static
    def test_the_script_is_valid_shell(self, script, tmp_path):
        """The failure this recipe is most likely to have is a syntax error in
        a heredoc, which no static check of the Lua would see.

        `bash -n` reads the program and does not run it. The install hook makes
        the same check against the file it wrote, so the claim holds for what
        is installed and not only for what is in this repository.
        """
        import subprocess
        p = tmp_path / "simctl-run"
        p.write_text(script, encoding="utf-8")
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr

    @pytest.mark.static
    def test_the_programs_exit_status_is_returned(self, script, script_code):
        """A RUNNER THAT REPORTED ITS OWN SUCCESS WOULD MAKE EVERY TEST PASS.

        `mcpp test` reads the status of the runner, so the spawned program's
        status is the one thing this script must not replace with its own. That
        is also why `set -e` is not used for the spawn: it would turn a
        non-zero program into a script that exits before reporting it.
        """
        assert re.search(r'xcrun simctl spawn .*\n\s*exit \$\?', script_code), (
            "the spawn's exit status is not returned verbatim"
        )
        assert 'set -e\n' not in script_code and 'set -euo' not in script_code, (
            "`set -e` would stop the script on a non-zero program instead of "
            "reporting its status"
        )

    @pytest.mark.static
    def test_it_does_not_use_the_booted_shorthand(self, script_code):
        """`simctl spawn booted` fails with no useful message when nothing is
        booted, and arriving at a booted device is this program's whole job.

        So the device is selected, its state is read, and it is booted and
        waited for when it is not. A `booted` shorthand appearing here would
        mean that work had been dropped.
        """
        assert not re.search(r'spawn\s+booted', script_code)
        assert 'simctl boot' in script_code, "nothing boots a device"
        assert 'bootstatus' in script_code, \
            "nothing waits for the boot to finish"

    @pytest.mark.static
    def test_it_reads_json_rather_than_the_human_table(self, script_code):
        """`simctl list devices` prints a table whose headings and indentation
        are not an interface.

        This index has a record of a recipe broken by a tool's output format
        changing under it, so the device walk goes through `-j`.
        """
        assert ('devices available -j' in script_code
                or 'devices -j' in script_code)
        assert re.search(r'simctl list devices(?! .*-j)[^-]*\|',
                         script_code) is None, (
            "a device list is parsed without -j"
        )

    @pytest.mark.static
    def test_every_refusal_names_what_is_missing(self, script):
        """A runner that fails silently is indistinguishable from a program
        that produced no output, and `mcpp run` prints what the runner printed.

        Each refusal therefore says which thing is absent -- xcrun, a device,
        or a boot that did not finish -- and says it on stderr.
        """
        for wanted in ('no xcrun', 'no available iOS simulator device',
                       'did not finish booting'):
            assert wanted in script, f"no refusal names: {wanted}"
        assert script.count('>&2') >= 5, "refusals are not on stderr"


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
                xpkgs_dir(), f"{ns}-x-apple-simulator-tools", "*", "simctl-run")))
        assert hits, "no installed simctl-run found"
        assert os.access(hits[-1], os.X_OK), f"{hits[-1]} is not executable"
