"""Official csvlens binaries: installation, CSV schema validation and selection."""
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import time

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG_FILE = "pkgs/c/csvlens.lua"
VERSION = "0.15.1"


def _xlings(*args):
    # Native subprocesses also work on Windows; bash -l may instead select WSL.
    exe = Path(xlings_home()) / "bin" / ("xlings.exe" if os.name == "nt" else "xlings")
    command = str(exe) if exe.is_file() else shutil.which("xlings")
    assert command, "xlings executable not found"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=300)
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout + result.stderr


def _shim():
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
    if not (base / subos).is_dir():
        subos = "default"
    shim = base / subos / "bin" / ("csvlens.exe" if os.name == "nt" else "csvlens")
    assert shim.is_file(), f"Missing real csvlens shim: {shim}"
    return shim


def _csvlens(*args):
    return subprocess.run([str(_shim()), *map(str, args)], stdin=subprocess.DEVNULL,
                          capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=15)


@pytest.mark.static
class TestStatic:
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert meta.spec == "2"
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)
        assert meta.programs == ["csvlens"]
        assert set(meta.platforms) == {"linux", "macosx", "windows"}


@pytest.mark.isolation
class TestIsolation:
    @pytest.mark.parametrize("check", [assert_no_exec_xvm, assert_no_bashrc_modification,
                                      assert_no_direct_path_modification,
                                      assert_no_direct_pkg_manager, assert_uses_new_api])
    def test_isolation(self, check):
        check(PKG_FILE)


@pytest.mark.index
def test_register_recipe():
    _xlings("config", "--add-xpkg", str(Path(PKG_FILE).resolve()))


@pytest.mark.lifecycle
def test_install():
    _xlings("install", under_test("csvlens", os.environ.get("XLINGS_TEST_VERSION", VERSION)), "-y")
    assert _shim().is_file()


@pytest.mark.verify
class TestVerify:
    def test_version(self):
        result = _csvlens("--version")
        assert result.returncode == 0, result.stdout + result.stderr
        assert result.stdout.strip() == "csvlens " + os.environ.get("XLINGS_TEST_VERSION", VERSION)

    def test_help(self):
        result = _csvlens("--help")
        assert result.returncode == 0, result.stdout + result.stderr
        assert all(flag in result.stdout for flag in ("--filter", "--columns", "--echo-column"))

    def test_csv_header_validation_without_terminal(self, tmp_path):
        # App::new validates the actual parsed CSV header before entering raw
        # mode. This exercises supported noninteractive behavior on Windows too.
        csv = tmp_path / "schema.csv"
        csv.write_text("Display;Secret\nvisible;selected-value\n", encoding="utf-8")
        result = _csvlens(csv, "--delimiter", ";", "--echo-column", "AbsentField")
        assert result.returncode != 0
        assert result.stdout.strip() == "Column name not found: AbsentField", result.stdout + result.stderr

    @pytest.mark.skipif(os.name == "nt", reason="POSIX PTY API unavailable on native Windows; native install/version/schema checks remain enabled")
    @pytest.mark.parametrize("key,expected", [(b"\r", "SELECTED_CELL_731\n"), (b"q", "")])
    def test_filtered_selection_and_normal_quit(self, tmp_path, key, expected):
        import errno
        import fcntl
        import pty
        import struct
        import termios

        csv = tmp_path / "selection.csv"
        csv.write_text("Choice,ResultToken,HiddenHeader\n"
                       "DROP_ROW,WRONG_CELL_124,hidden-a\n"
                       "KEEP_ROW,SELECTED_CELL_731,hidden-b\n"
                       "OTHER_ROW,WRONG_CELL_826,hidden-c\n", encoding="utf-8")
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 120, 0, 0))

        def controlling_terminal():
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        proc = None
        rendered = bytearray()
        try:
            proc = subprocess.Popen(
                [str(_shim()), str(csv), "--filter", "^KEEP_ROW$", "--columns", "^(Choice|ResultToken)$",
                 "--echo-column", "ResultToken"],
                stdin=slave, stderr=slave, stdout=subprocess.PIPE,
                env={**os.environ, "TERM": "xterm-256color"},
                start_new_session=True, preexec_fn=controlling_terminal,
            )
            os.close(slave)
            slave = None
            deadline = time.monotonic() + 15
            screen = ""
            while time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], 0.1)
                if ready:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as error:
                        if error.errno == errno.EIO:
                            break
                        raise
                    if not chunk:
                        break
                    rendered.extend(chunk)
                    screen = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", rendered.decode("utf-8", errors="replace"))
                    if all(token in screen for token in ("Choice", "KEEP_ROW", "ResultToken", "SELECTED_CELL_731")):
                        break
                if proc.poll() is not None:
                    break
            # Evidence is real TUI output from the installed shim, not just
            # generic escape sequences or a process that survived startup.
            assert "Choice" in screen and "KEEP_ROW" in screen, screen
            assert "ResultToken" in screen and "SELECTED_CELL_731" in screen, screen
            for excluded in ("DROP_ROW", "OTHER_ROW", "HiddenHeader", "WRONG_CELL_124", "WRONG_CELL_826"):
                assert excluded not in screen, screen
            os.write(master, key)
            stdout, _ = proc.communicate(timeout=10)
            assert proc.returncode == 0, screen
            # The non-first column in the filtered row must be selected,
            # not the first original row, first column, or unfiltered value.
            assert stdout.decode("utf-8").replace("\r\n", "\n") == expected
        finally:
            if proc is not None and proc.poll() is None:
                proc.kill()
                proc.communicate(timeout=5)
            os.close(master)
            if slave is not None:
                os.close(slave)
