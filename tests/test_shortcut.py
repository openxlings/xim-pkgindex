"""shortcut: one implementation of "a package's launcher entry on Windows".

Two kinds of test, as for nvim_plugin:

* an INVARIANT, in pure Python, that always runs -- no recipe spells a
  Windows shortcut itself. The Start Menu's location, the PowerShell quoting,
  the best-effort contract and the removal live in libs/shortcut.lua, and a
  package imports it (`xim.pkgindex.shortcut`): a second copy of that code is
  a second place for the same fact to go stale. Four recipes predate the
  module and are listed below; the list only ever shrinks.

* a BEHAVIOUR check of libs/shortcut.lua itself, run in a plain-Lua sandbox
  with the host, the environment and `system.exec` forged per case
  (tests/lua/shortcut_harness.lua). No PowerShell runs on this machine: what
  is checked is the command the module builds, the path it chooses, and what
  it answers. The real execution is the Windows install job of a recipe that
  uses the module (winscp).
"""
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

pytestmark = pytest.mark.static

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "shortcut_harness.lua"
LIB = REPO / "libs" / "shortcut.lua"
WINPATH = REPO / "libs" / "winpath.lua"

# The recipes that predate the module. Each is a migration waiting to happen;
# an entry for a recipe that no longer spells a shortcut (or no longer exists)
# would silently exempt whatever takes its path next.
LEGACY_SHORTCUT_RECIPES = {
    "pkgs/c/code.lua",            # its own .vbs template
    "pkgs/f/filezilla.lua",       # a byte-identical copy of winscp's
    "pkgs/h/hxlings.lua",         # a byte-identical copy of winscp's
    "pkgs/s/shortcut-tool.lua",   # the script package devcpp/git/vc6 call
}

SPELLS_A_SHORTCUT = re.compile(
    r"CreateShortcut"              # the WScript.Shell entry point, COM or VBS
    r"|WScript\.Shell",
    re.IGNORECASE,
)


def _code_lines(src: str):
    """The recipe's lines with Lua comments removed, as the CRT check does."""
    for line in src.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("--"):
            continue
        cut = line.find(" --")
        yield line if cut == -1 else line[:cut]


def _spells(path: Path):
    src = path.read_text(encoding="utf-8", errors="replace")
    for number, line in enumerate(_code_lines(src), start=1):
        if SPELLS_A_SHORTCUT.search(line):
            yield number


def test_no_recipe_spells_a_shortcut():
    bad = []
    for lua in sorted((REPO / "pkgs").rglob("*.lua")):
        rel = lua.relative_to(REPO).as_posix()
        if rel in LEGACY_SHORTCUT_RECIPES:
            continue
        for number in _spells(lua):
            bad.append(f"{rel}:{number}")
    assert not bad, (
        "a recipe writes a Windows shortcut itself; use "
        'import("xim.pkgindex.shortcut") and shortcut.create / shortcut.remove '
        "(docs/10-adding-a-package.md, The hooks):\n  " + "\n  ".join(bad))


def test_the_legacy_list_names_existing_recipes():
    missing = [r for r in LEGACY_SHORTCUT_RECIPES if not (REPO / r).is_file()]
    assert not missing, f"exempted recipes that do not exist: {missing}"
    still = [r for r in LEGACY_SHORTCUT_RECIPES if any(True for _ in _spells(REPO / r))]
    stale = sorted(set(LEGACY_SHORTCUT_RECIPES) - set(still))
    assert not stale, (
        f"recipes exempted but no longer spelling a shortcut (drop them): {stale}")


@pytest.mark.skipif(
    shutil.which("lua5.4") is None and shutil.which("lua") is None,
    reason="no lua interpreter on this machine",
)
def test_shortcut_behaviour_on_forged_hosts():
    lua = shutil.which("lua5.4") or shutil.which("lua")
    env = dict(os.environ)
    env["SHORTCUT_LIB"] = str(LIB)
    env["WINPATH_LIB"] = str(WINPATH)
    proc = subprocess.run([lua, str(HARNESS)], capture_output=True, text=True, env=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "PASS:" in proc.stdout, proc.stdout + proc.stderr
