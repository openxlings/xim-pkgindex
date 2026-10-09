import os
from pathlib import Path
import subprocess
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import assert_required_fields, assert_valid_type, assert_xim_add_succeeds

PKG_FILE = "pkgs/a/agent-workspace-private.lua"

@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(PKG_FILE)
    assert_required_fields(meta)
    assert_valid_type(meta)
    assert meta.pkg_type == "config"

@pytest.fixture
def owner_entry(tmp_path):
    payload = tmp_path / "payload"
    result = run_recipe(PKG_FILE, payload)
    assert result.returncode == 0, result.stderr
    launcher = payload / "agent-workspace-private"
    syntax = subprocess.run(["sh", "-n", str(launcher)], capture_output=True, text=True)
    assert syntax.returncode == 0, syntax.stderr
    home = tmp_path / "home"
    (home / "subos/agent/rootfs/etc").mkdir(parents=True)
    bindir = tmp_path / "bin"
    bindir.mkdir()
    fake = bindir / "xlings"
    fake.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$XLINGS_HOME/commands.txt"
if [ "$2" = config ] && [ "${FAIL_POLICY:-}" = yes ]; then exit 125; fi
''')
    fake.chmod(0o755)
    env = {**os.environ, "XLINGS_HOME": str(home), "XLINGS_SUBOS_MODE": "",
           "PATH": str(bindir) + ":" + os.environ["PATH"]}
    return launcher, home, env

@pytest.mark.static
@pytest.mark.isolation
@pytest.mark.parametrize("proxy", ["", "http://localhost:7897", "socks5h://user:secret@localhost:1080", "socks5h://localhost:1080;touch /tmp/injected", "socks5h://localhost:0", "socks5h://localhost:65536"])
def test_invalid_proxy_never_changes_policy(owner_entry, proxy):
    launcher, home, env = owner_entry
    result = subprocess.run([str(launcher), "agent", proxy], env=env, capture_output=True)
    assert result.returncode != 0
    assert not (home / "commands.txt").exists()

@pytest.mark.static
@pytest.mark.isolation
def test_owner_locks_policy_before_initializing_inside_root(owner_entry):
    launcher, home, env = owner_entry
    for _ in range(2):
        result = subprocess.run([str(launcher), "agent", "socks5h://localhost:1080"], env=env, capture_output=True)
        assert result.returncode == 0, result.stderr
    calls = (home / "commands.txt").read_text()
    assert calls.count("subos config agent --sandbox xim:agent-private@0.1.0 --proxy socks5h://localhost:1080 --no-degrade") == 2
    assert "subos exec agent -- /bin/sh -c" in calls
    assert "path:%s/data/xpkgs/xim-x-gcc/16.1.0" in calls
    assert not (home / "subos/agent/rootfs/root").exists(), "owner must not write user data directly"

@pytest.mark.static
@pytest.mark.isolation
def test_failed_policy_never_enters_root(owner_entry):
    launcher, home, env = owner_entry
    result = subprocess.run([str(launcher), "agent", "socks5h://localhost:1080"], env={**env, "FAIL_POLICY": "yes"}, capture_output=True)
    assert result.returncode == 125
    assert "subos exec" not in (home / "commands.txt").read_text()

@pytest.mark.static
@pytest.mark.isolation
def test_sandbox_cannot_apply_policy(owner_entry):
    launcher, home, env = owner_entry
    result = subprocess.run([str(launcher), "agent", "socks5h://localhost:1080"], env={**env, "XLINGS_SUBOS_MODE": "sandbox"}, capture_output=True)
    assert result.returncode != 0 and b"owner side" in result.stderr
    assert not (home / "commands.txt").exists()

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds(PKG_FILE)
