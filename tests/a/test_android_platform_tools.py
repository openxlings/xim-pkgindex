"""Tests for the android-platform-tools package.

No test file existed for this package before adb-run was added (2026-09-12);
this one covers the pre-existing adb/fastboot registration briefly and the
new runner program in the depth its own design record section (4.2) and its
"host coverage" and "unmeasured" statements call for.
"""
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

PKG = "android-platform-tools"
PKG_FILE = "pkgs/a/android-platform-tools.lua"


def _code(content: str) -> str:
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def code(meta):
    return _code(meta.raw_content)


@pytest.fixture(scope='module')
def source_text():
    from tests.lib.platform_utils import project_root
    import os
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


@pytest.fixture(scope='module')
def script(source_text):
    """The adb-run program this recipe writes, extracted from its own text
    (same extraction shape test_apple_simulator_tools.py uses for
    simctl-run)."""
    m = re.search(r'__adb_run_sh = \[==\[(.*?)\]==\]', source_text, re.S)
    assert m, "the embedded adb-run script was not found"
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
    def test_adb_and_fastboot_still_registered(self, code):
        assert 'xvm.add("adb"' in code
        assert 'xvm.add("fastboot"' in code

    @pytest.mark.static
    def test_version_bumped_with_bare_pin_kept_for_compat(self, code):
        """adb-run is written by this recipe, not part of the downloaded
        archive, so a bare recipe edit under an unchanged version key would
        leave an already-installed revision without the fix -- hence the
        "-N" suffix, bumped again to "37.0.1-3" for the `am start -W`/pid-
        detection fix. Every earlier "-N" key, and the bare "37.0.1", must
        still resolve for anyone already pinned to it."""
        assert '"37.0.1-3"' in code
        assert '"37.0.1-2"' in code
        assert '"37.0.1"' in code
        assert re.search(r'ref\s*=\s*"37\.0\.1-3"', code)

    @pytest.mark.static
    def test_adb_run_registered_in_its_own_bin_subdir(self, code):
        assert re.search(r'xvm\.add\("adb-run",\s*\{\s*bindir\s*=\s*path\.join\(bindir,\s*"bin"\)', code)

    @pytest.mark.static
    def test_bash_n_at_install_guarded_for_windows(self, code):
        assert "bash -n" in code
        assert 'is_host("windows")' in code

    @pytest.mark.static
    def test_the_script_is_valid_shell(self, script, tmp_path):
        import subprocess
        p = tmp_path / "adb-run"
        p.write_text(script, encoding="utf-8")
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr

    @pytest.mark.static
    def test_device_selection_is_not_this_programs_job(self, script_code):
        """No `-s <serial>` is ever passed to adb; ANDROID_SERIAL or adb's
        own single-device default is the caller's configuration (design
        record rule 4, extended the way apple-simulator-tools.lua's own
        SIMCTL_RUN_UDID precedent extends it)."""
        assert not re.search(r'adb\s+-s\s', script_code)
        assert not re.search(r"adb\s+\\\"-s", script_code)

    @pytest.mark.static
    def test_apk_branch_installs_and_starts(self, script_code):
        assert "adb install -r" in script_code
        assert "am start -n" in script_code
        assert "log.redirect-stdio" in script_code

    @pytest.mark.static
    def test_apk_branch_does_not_use_am_start_wait(self, script_code):
        """MEASURED 2026-09-12: `-W` hangs indefinitely for an activity that
        finishes from `onCreate` (two independent invocations killed by hand
        after 691s and 354s) -- see the recipe's own header. `am start -W`
        must not appear anywhere in the apk branch."""
        assert "am start -W" not in script_code

    @pytest.mark.static
    def test_run_loop_ends_on_activity_finish_not_only_process_death(self, script_code):
        """MEASURED 2026-09-12: `finish()` ends the activity, not the
        process -- ActivityManager keeps it `cch-empty` indefinitely. The
        streaming loop must also end when the activity record disappears
        from `dumpsys activity activities`, not only when `pidof` goes
        empty, and the app must be force-stopped afterward so a clean
        finish does not leave a cached process for the next run to reuse."""
        assert "dumpsys activity activities" in script_code
        assert re.search(r'am force-stop', script_code)

    @pytest.mark.static
    def test_id_and_activity_have_two_sources(self, script_code):
        """aapt2 dump badging when reachable, otherwise the sidecar the
        design record names -- both paths must exist, and the sidecar path
        must read the exact keys the design record specifies."""
        assert "aapt2" in script_code and "dump badging" in script_code
        assert "mcpp-run.json" in script_code
        assert "unzip -p" in script_code
        assert '"package"' in script_code or "get(\"package\"" in script_code
        assert '"activity"' in script_code or "get(\"activity\"" in script_code

    @pytest.mark.static
    def test_pid_is_retried_not_assumed_immediate(self, script_code):
        assert "pidof" in script_code

    @pytest.mark.static
    def test_logcat_is_pid_filtered_and_streamed_to_stdout(self, script_code):
        assert re.search(r'adb logcat --pid=', script_code)

    @pytest.mark.static
    def test_exit_status_reflects_fatal_exception_or_tombstone(self, script_code):
        assert "FATAL EXCEPTION" in script_code
        # The script's own grep pattern spells this as the bracket class
        # "[Tt]ombstone" (case-insensitive without -i), so "ombstone" is the
        # substring common to both that source text and a plain word match.
        assert "ombstone" in script_code

    @pytest.mark.static
    def test_bare_executable_branch_pushes_and_parses_rc(self, script_code):
        assert "adb push" in script_code
        assert "/data/local/tmp/" in script_code
        assert "chmod 755" in script_code
        assert "__rc=" in script_code
        assert re.search(r'adb shell rm -f', script_code)

    @pytest.mark.static
    def test_every_refusal_names_what_is_missing(self, script):
        for wanted in ("does not exist", "no adb on PATH",
                       "could not determine the application id"):
            assert wanted in script, f"no refusal names: {wanted}"


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_installed_adb_run_is_executable(self):
        from tests.lib.platform_utils import xpkgs_dir
        import glob
        import os
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(f"{xpkgs_dir()}/{ns}-x-android-platform-tools/*/bin/adb-run"))
        if not hits:
            pytest.skip("android-platform-tools is not installed at a version carrying adb-run")
        assert os.access(hits[-1], os.X_OK)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_adb_run_bare_executable_round_trip(self, tmp_path):
        """Real end-to-end run against whatever adb currently sees. Skipped
        (not failed) when no device/emulator is attached -- this is exactly
        the case this session's own environment was in (`adb devices`
        printed no rows), so this test documents what remains unmeasured
        rather than asserting past it.

        The pushed operand is a `#!/system/bin/sh` SCRIPT, not a host ELF: a
        host binary (`/bin/echo`) is the wrong architecture for an Android
        device and would fail with an exec-format error on the device, not
        prove anything about adb-run itself."""
        import subprocess
        import glob
        import os
        import stat
        from tests.lib.platform_utils import xpkgs_dir

        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(f"{xpkgs_dir()}/{ns}-x-android-platform-tools/*/bin/adb-run"))
        if not hits:
            pytest.skip("adb-run is not installed")

        devices = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=15)
        lines = [l for l in devices.stdout.splitlines()[1:] if l.strip()]
        if not lines:
            pytest.skip("no device or emulator attached to adb")

        script_path = tmp_path / "adb-run-probe.sh"
        script_path.write_text("#!/system/bin/sh\necho hello-from-adb-run\n")
        script_path.chmod(script_path.stat().st_mode | stat.S_IEXEC)

        r = subprocess.run([hits[-1], str(script_path)],
                            capture_output=True, text=True, timeout=30)
        assert "hello-from-adb-run" in r.stdout
        assert r.returncode == 0
