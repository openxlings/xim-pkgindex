"""winpath: one implementation of "a path a Windows program accepts".

A behaviour check of libs/winpath.lua itself, run in a plain-Lua sandbox with
nothing forged -- the module is pure string work. Skipped rather than failed
when no lua5.4 is on the runner: a missing interpreter is not a defect in the
index.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

pytestmark = pytest.mark.static

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "winpath_harness.lua"
LIB = REPO / "libs" / "winpath.lua"


def test_winpath_exists():
    assert LIB.is_file(), "libs/winpath.lua is the shared native-path conversion"


@pytest.mark.skipif(
    shutil.which("lua5.4") is None and shutil.which("lua") is None,
    reason="no lua interpreter on this machine",
)
def test_winpath_behaviour():
    lua = shutil.which("lua5.4") or shutil.which("lua")
    env = dict(os.environ)
    env["WINPATH_LIB"] = str(LIB)
    proc = subprocess.run([lua, str(HARNESS)], capture_output=True, text=True, env=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "PASS:" in proc.stdout, proc.stdout + proc.stderr
