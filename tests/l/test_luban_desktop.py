"""The desktop editions (xlings: Luban OS desktop part 2 §3): luban-desktop
(xdesk classic) and luban-desktop-xdesk (xdesk canvas) -- one environment
that is ready to use, its defaults, and what each architecture gets.
"""
import json
import re
from pathlib import Path

import pytest

from tests.lib.luban_recipe import run_recipe

ROOT = Path(__file__).resolve().parents[2]
CLASSIC = ROOT / "pkgs/luban/luban-desktop.lua"
CANVAS = ROOT / "pkgs/luban/luban-desktop-xdesk.lua"
VERSION = "2026.10.13.1"

# What a desktop is ready with: the tools people reach for.
ENVIRONMENT = {"labwc-desktop", "node", "python", "uv", "bun", "ripgrep", "fd", "fzf", "jq", "tmux", "htop",
               "claude", "codex", "pi", "opencode"}


def made(recipe, tmp_path, arch="x86_64"):
    target = tmp_path / f"{recipe.stem}-{arch}"
    result = run_recipe(recipe, target, version=VERSION, env={"LUBAN_TEST_ARCH": arch})
    assert result.returncode == 0, result.stderr + result.stdout
    manifest = json.loads((target / ".xlings.json").read_text())
    settings = json.loads((target / "usr/share/luban/settings.json").read_text())
    return target, manifest, settings


def names(manifest):
    return {p.split(":", 1)[1].split("@", 1)[0] for p in manifest["packages"]}


@pytest.mark.static
@pytest.mark.parametrize("recipe,session", [(CLASSIC, "xdesk-classic"), (CANVAS, "xdesk-canvas")])
def test_a_desktop_is_ready_to_use_and_starts_its_session(recipe, session, tmp_path):
    target, manifest, settings = made(recipe, tmp_path)
    assert ENVIRONMENT <= names(manifest), ENVIRONMENT - names(manifest)
    assert {"xdesk", "dsh"} <= names(manifest)
    assert manifest["from"].startswith("subos:luban-core@")
    assert manifest["min_client"] == VERSION
    assert settings == {"mode": "machine", "desktop": session}
    # Defaults: git, and registries near the person when xlings uses its CN mirror.
    git = (target / "usr/share/factory/etc/gitconfig").read_text()
    assert "defaultBranch = main" in git
    registries = (target / "usr/share/factory/etc/profile.d/luban-registries.sh").read_text()
    assert "NPM_CONFIG_REGISTRY" in registries and "PIP_INDEX_URL" in registries
    assert ":=" in registries, "a registry the person set wins"
    assert "token" not in registries.lower() and "key" not in registries.lower(), "no credentials are baked in"


@pytest.mark.static
def test_aarch64_gets_the_environment_and_labwc_until_xdesk_is_released_there(tmp_path):
    _, manifest, settings = made(CLASSIC, tmp_path, arch="aarch64")
    assert ENVIRONMENT <= names(manifest)
    assert not {"xdesk", "dsh"} & names(manifest), "x86_64-only members are not named for aarch64"
    assert settings["desktop"] == "labwc-desktop"
    # The canvas edition says it is not built there (the quick start reads archs).
    assert re.search(r'archs = \{"x86_64"\}', CANVAS.read_text())


@pytest.mark.static
@pytest.mark.parametrize("recipe", [CLASSIC, CANVAS])
def test_every_pinned_member_is_in_the_index_at_that_version(recipe, tmp_path):
    for arch in ("x86_64", "aarch64") if recipe == CLASSIC else ("x86_64",):
        _, manifest, _ = made(recipe, tmp_path, arch=arch)
        for ref in manifest["packages"]:
            ns, _, rest = ref.partition(":")
            name, _, version = rest.partition("@")
            # The recipe of its namespace (luban:xdesk and xim:xdesk are two).
            files = [f for f in ROOT.glob(f"pkgs/*/{name}.lua")
                     if (re.search(r'^\s*namespace\s*=\s*"([^"]+)"', f.read_text(), re.M) or [None, "xim"])[1] == ns]
            assert files, f"{ref}: no recipe"
            if version:
                assert f'["{version}"]' in files[0].read_text(), f"{ref}: {files[0].name} has no {version}"
