"""The Luban editions of 2026.10.16.1 (xlings design 2026-10-16 L §10, §11;
mcpp design 2026-10-16 §9.5): terminfo in every root with a shell, a default
cursor theme on a desktop, mcpp borrowing the system's gcc, the not-found
hint, and each edition's own checks -- for a client that reads them."""
import json
import os
import subprocess

import pytest
from tests.lib.luban_recipe import run_recipe

V = "2026.10.16.1"
EDITIONS = ["tiny", "tiny-musl", "core", "agent-workspace", "desktop", "desktop-xdesk"]


def made(tmp_path, edition):
    target = tmp_path / edition
    result = run_recipe(f"pkgs/luban/luban-{edition}.lua", target, V)
    assert result.returncode == 0, result.stderr + result.stdout
    return target, json.loads((target / ".xlings.json").read_text())


@pytest.mark.static
@pytest.mark.parametrize("edition", EDITIONS)
def test_it_asks_for_the_client_that_reads_it(tmp_path, edition):
    _, manifest = made(tmp_path, edition)
    assert manifest["min_client"] == V


@pytest.mark.static
@pytest.mark.parametrize("edition", ["tiny", "tiny-musl"])
def test_the_terminals_are_described(tmp_path, edition):
    _, manifest = made(tmp_path, edition)
    assert "xim:terminfo@6.6.20261010" in manifest["packages"]


@pytest.mark.static
@pytest.mark.parametrize("edition", ["core", "agent-workspace", "desktop", "desktop-xdesk"])
def test_what_it_is_made_from_is_of_the_same_date(tmp_path, edition):
    _, manifest = made(tmp_path, edition)
    base = "tiny" if edition == "core" else "core"
    assert manifest["from"] == f"subos:luban-{base}@{V}"


@pytest.mark.static
@pytest.mark.parametrize("edition", ["desktop", "desktop-xdesk"])
def test_a_desktop_has_a_default_cursor_theme(tmp_path, edition):
    target, manifest = made(tmp_path, edition)
    assert "xim:adwaita-cursors@49.0" in manifest["packages"]
    checks = json.loads((target / f"usr/share/luban/checks.d/{edition}.json").read_text())["checks"]
    assert {c["id"] for c in checks} == {"desktop-applications", "desktop-cursors"}


@pytest.mark.static
def test_core_borrows_the_systems_gcc(tmp_path):
    target, _ = made(tmp_path, "core")
    config = (target / "usr/share/factory/etc/mcpp/config.toml").read_text()
    assert 'upstream = ["/xlings"]' in config and 'default = "gcc@16.1.0"' in config


@pytest.mark.static
@pytest.mark.parametrize("edition", ["tiny", "tiny-musl", "core", "desktop", "desktop-xdesk"])
def test_every_check_is_a_command_with_a_reason(tmp_path, edition):
    target, _ = made(tmp_path, edition)
    for c in json.loads((target / f"usr/share/luban/checks.d/{edition}.json").read_text())["checks"]:
        assert c["id"] and c["what"] and c["run"], c
        assert isinstance(c.get("critical", False), bool) and 0 < c.get("timeout", 120) <= 300


@pytest.mark.static
def test_a_command_not_found_says_what_it_may_be(tmp_path):
    target, _ = made(tmp_path, "core")
    helper = target / "usr/libexec/luban/command-not-found"
    assert os.access(helper, os.X_OK)
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for name in ("xlings", "git"):
        (bin_dir / name).write_text("#!/bin/sh\nexit 1\n")
        (bin_dir / name).chmod(0o755)
    run = subprocess.run(["/bin/sh", str(helper), "xlnigs"], capture_output=True, text=True,
                         env={"PATH": f"{bin_dir}:/usr/bin:/bin"})
    assert run.returncode == 127
    assert "xlnigs: command not found" in run.stderr and "did you mean: xlings" in run.stderr
    fish = (target / "usr/share/fish/vendor_functions.d/fish_command_not_found.fish").read_text()
    assert "/usr/libexec/luban/command-not-found" in fish
    bash = (target / "usr/share/factory/etc/profile.d/luban-command-not-found.sh").read_text()
    assert "command_not_found_handle" in bash
