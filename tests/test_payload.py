"""payload: one implementation of "land the archive, then name what is missing".

A behaviour check of libs/payload.lua itself, run in a plain-Lua sandbox with
the host, the environment, the filesystem and `system.exec` forged per case
(tests/lua/payload_harness.lua). Skipped rather than failed when no lua5.4 is
on the runner: a missing interpreter is not a defect in the index.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

pytestmark = pytest.mark.static

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "payload_harness.lua"
LIB = REPO / "libs" / "payload.lua"
WINPATH = REPO / "libs" / "winpath.lua"


def test_payload_exists():
    assert LIB.is_file(), "libs/payload.lua is the shared archive-landing module"


@pytest.mark.skipif(
    shutil.which("lua5.4") is None and shutil.which("lua") is None,
    reason="no lua interpreter on this machine",
)
def test_payload_behaviour_on_forged_hosts():
    lua = shutil.which("lua5.4") or shutil.which("lua")
    env = dict(os.environ)
    env["PAYLOAD_LIB"] = str(LIB)
    env["WINPATH_LIB"] = str(WINPATH)
    proc = subprocess.run([lua, str(HARNESS)], capture_output=True, text=True, env=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "PASS:" in proc.stdout, proc.stdout + proc.stderr
