"""The new native Windows launcher and old cmd packages keep their own entry."""
from pathlib import Path
import shutil
import subprocess

import pytest

ROOT = Path(__file__).resolve().parent.parent
LUA = shutil.which("lua5.4") or shutil.which("lua")


@pytest.mark.static
@pytest.mark.skipif(LUA is None, reason="requires plain Lua")
@pytest.mark.parametrize("host,form", [("windows", "exe"), ("windows", "cmd"), ("linux", "exe")])
def test_package_launcher(host, form):
    result = subprocess.run([LUA, str(ROOT / "tests/lua/mcpp_ide_launcher_harness.lua"),
                             str(ROOT / "pkgs/m/mcpp-ide.lua"), host, form],
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert "launcher OK" in result.stdout
