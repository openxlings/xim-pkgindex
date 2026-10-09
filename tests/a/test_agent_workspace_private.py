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

@pytest.mark.static
@pytest.mark.isolation
@pytest.mark.parametrize("proxy", ["", "http://127.0.0.1:7897", "socks5h://user:secret@localhost:1080", "socks5h://localhost:1080;touch /tmp/injected"])
def test_invalid_proxy_never_changes_policy(tmp_path, proxy):
    target = tmp_path / "payload"
    (target / "subos/agent/rootfs/etc").mkdir(parents=True)
    result = run_recipe(PKG_FILE, target, env={"AGENT_PRIVATE_PROXY": proxy, "XLINGS_SUBOS_MODE": ""})
    assert result.returncode != 0
    assert not (target / "commands.txt").exists()

@pytest.mark.static
@pytest.mark.isolation
def test_idempotent_and_preserves_credentials(tmp_path):
    target = tmp_path / "payload"
    (target / "subos/agent/rootfs/etc").mkdir(parents=True)
    home = target / "subos/agent/rootfs/root"
    (home / ".claude").mkdir(parents=True)
    settings = home / ".claude/settings.json"
    settings.write_text('{"existing":true}')
    secret = home / ".claude/credentials.json"
    secret.write_text("private-secret")
    for _ in range(2):
        result = run_recipe(PKG_FILE, target, env={"AGENT_PRIVATE_PROXY": "socks5h://127.0.0.1:1080", "XLINGS_SUBOS_MODE": ""})
        assert result.returncode == 0, result.stderr
    assert settings.read_text() == '{"existing":true}'
    assert secret.read_text() == "private-secret"
    assert (home / "workspace").stat().st_mode & 0o777 == 0o700
    assert settings.stat().st_mode & 0o777 == 0o600
    assert "--sandbox 'xim:agent-private@0.1.0'" in (target / "commands.txt").read_text()

@pytest.mark.static
@pytest.mark.isolation
def test_failed_policy_does_not_create_workspace(tmp_path):
    target = tmp_path / "payload"
    (target / "subos/agent/rootfs/etc").mkdir(parents=True)
    result = run_recipe(PKG_FILE, target, env={"AGENT_PRIVATE_PROXY": "socks5h://localhost:1080", "XLINGS_SUBOS_MODE": ""}, fail_policy=True)
    assert result.returncode != 0
    assert not (target / "subos/agent/rootfs/root").exists()

@pytest.mark.static
@pytest.mark.isolation
def test_sandbox_cannot_apply_policy(tmp_path):
    target = tmp_path / "payload"
    result = run_recipe(PKG_FILE, target, env={"XLINGS_SUBOS_MODE": "sandbox"})
    assert result.returncode != 0 and "owner side" in result.stderr
    assert not (target / "commands.txt").exists()

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds(PKG_FILE)
