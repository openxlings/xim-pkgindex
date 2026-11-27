"""shell_profile: one way for a package to put shell integration into xlings' own profiles.

A behaviour check of libs/shell_profile.lua in a plain-Lua sandbox
(tests/lua/shell_profile_harness.lua), plus a syntax check of the generated
snippets in every real shell that happens to be installed (sh, bash, zsh, fish,
pwsh). Skipped rather than failed when a tool is missing: that is not a defect
in the index.
"""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

pytestmark = pytest.mark.static

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "shell_profile_harness.lua"
LIB = REPO / "libs" / "shell_profile.lua"
LUA = shutil.which("lua5.4") or shutil.which("lua")


def _run_harness(dump=None):
    env = dict(os.environ)
    env["SHELL_PROFILE_LIB"] = str(LIB)
    if dump:
        env["SNIPPET_DIR"] = str(dump)
    return subprocess.run([LUA, str(HARNESS)], capture_output=True, text=True, env=env)


def test_shell_profile_exists():
    assert LIB.is_file(), "libs/shell_profile.lua is the shared shell-profile module"


def test_code_never_names_the_users_own_shell_config():
    # Only code counts: the comments explain why none of these is touched.
    code = "\n".join(l for l in LIB.read_text(encoding="utf-8").splitlines()
                     if not l.lstrip().startswith("--"))
    for forbidden in ("append_to_shell_profile", "append_bashrc", ".bashrc",
                      "bash_profile", "config.fish", "zshrc"):
        assert forbidden not in code, f"user shell config referenced: {forbidden}"


@pytest.mark.skipif(LUA is None, reason="no lua interpreter on this machine")
def test_behaviour_in_a_forged_home():
    proc = _run_harness()
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "PASS:" in proc.stdout, proc.stdout + proc.stderr


@pytest.mark.skipif(LUA is None, reason="no lua interpreter on this machine")
@pytest.mark.parametrize("shell,args,kind", [
    ("sh", ["-n"], "sh"),
    ("dash", ["-n"], "sh"),
    ("bash", ["-n"], "sh"),
    ("zsh", ["-n"], "sh"),
    ("fish", ["--no-execute"], "fish"),
])
def test_generated_snippets_parse(shell, args, kind):
    exe = shutil.which(shell)
    if exe is None:
        pytest.skip(f"{shell} is not installed")
    with tempfile.TemporaryDirectory() as tmp:
        assert _run_harness(dump=tmp).returncode == 0
        snippet = Path(tmp) / f"snippet.{kind}"
        proc = subprocess.run([exe, *args, str(snippet)], capture_output=True, text=True)
        assert proc.returncode == 0, f"{shell} cannot parse the block:\n{snippet.read_text()}\n{proc.stderr}"


@pytest.mark.skipif(LUA is None, reason="no lua interpreter on this machine")
def test_generated_powershell_snippet_parses():
    exe = shutil.which("pwsh")
    if exe is None:
        pytest.skip("pwsh is not installed")
    with tempfile.TemporaryDirectory() as tmp:
        assert _run_harness(dump=tmp).returncode == 0
        snippet = Path(tmp) / "snippet.ps1"
        cmd = ("$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile("
               f"'{snippet}',[ref]$null,[ref]$e); if ($e.Count) {{ $e | Out-String; exit 1 }}")
        proc = subprocess.run([exe, "-NoProfile", "-Command", cmd], capture_output=True, text=True)
        assert proc.returncode == 0, proc.stdout + proc.stderr
