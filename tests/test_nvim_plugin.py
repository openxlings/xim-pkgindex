"""nvim_plugin: one implementation of "a Neovim plugin as a package".

Two kinds of test, as for hostlib:

* an INVARIANT, in pure Python, that always runs -- no recipe spells Neovim's
  site pack itself. The site dir per host, the `pack/xim/start/<name>` copy,
  the version probe and the provisioning live in libs/nvim_plugin.lua, and a
  Neovim plugin package imports it (`xim.pkgindex.nvim_plugin`): a second copy
  of that code is a second place for the same fact to go stale.

* a BEHAVIOUR check of libs/nvim_plugin.lua itself, run in a plain-Lua sandbox
  with the host, the environment, the `nvim` on PATH and pkgmanager.install
  forged. Skipped rather than failed when no `lua5.4` is on the runner: a
  missing interpreter is not a defect in the index.
"""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

pytestmark = pytest.mark.static

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "nvim_plugin_harness.lua"
LIB = REPO / "libs" / "nvim_plugin.lua"

# How code spells Neovim's site pack: the Windows data dir's name, and the
# path parts under the site dir.
SITE_PACK_TOKENS = ('"nvim-data"', '"pack", "xim"', '"site", "pack"')


def _recipes():
    return sorted(REPO.glob("pkgs/*/*.lua"))


def test_nvim_plugin_exists():
    assert LIB.is_file(), "libs/nvim_plugin.lua is the shared Neovim plugin handling"


@pytest.mark.parametrize("recipe", _recipes(), ids=lambda p: p.name)
def test_no_recipe_spells_the_site_pack(recipe):
    rel = recipe.relative_to(REPO).as_posix()
    text = recipe.read_text(encoding="utf-8", errors="replace")
    code = "\n".join(
        line for line in text.splitlines() if not line.lstrip().startswith("--")
    )
    hits = sorted(tok for tok in SITE_PACK_TOKENS if tok in code)
    assert not hits, (
        f"{rel} spells Neovim's site pack itself ({hits}). Use "
        'import("xim.pkgindex.nvim_plugin") and nvim_plugin.copy_to_pack / '
        "remove_from_pack, which hold the site dir of every host."
    )


@pytest.mark.skipif(
    shutil.which("lua5.4") is None and shutil.which("lua") is None,
    reason="no lua interpreter on this machine",
)
def test_nvim_plugin_behaviour_on_forged_hosts(tmp_path):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    env = dict(os.environ)
    env["FAKE_ROOT"] = str(tmp_path)
    env["NVIM_PLUGIN"] = str(LIB)
    proc = subprocess.run(
        [lua, str(HARNESS)], capture_output=True, text=True, env=env, cwd=tmp_path
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "PASS:" in proc.stdout, proc.stdout
