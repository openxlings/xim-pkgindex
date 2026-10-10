import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import assert_required_fields, assert_valid_type, assert_valid_spec, assert_xim_add_succeeds

PKG_FILE = "pkgs/a/agent-private.lua"

@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(PKG_FILE)
    assert_required_fields(meta)
    assert_valid_type(meta)
    assert_valid_spec(meta)

@pytest.mark.static
@pytest.mark.isolation
def test_effective_policy(tmp_path):
    target = tmp_path / "payload"
    result = run_recipe(PKG_FILE, target)
    assert result.returncode == 0, result.stderr
    policy = json.loads((target / "policy.json").read_text())
    assert policy["extends"] == "private"
    iso = policy["isolation"]
    assert iso["net"] == "proxy" and "proxy" not in iso, "the proxy is the instance's, never the package's"
    assert iso["identity"] == {}, "a zone unchosen: the proxy's exit"
    assert iso["env_pass"] == iso["grants"] == iso["grants_allowed"] == []
    assert iso["no_degrade"] and iso["disable_userns"]
    assert all(iso["needs"][k] == "must" for k in ("fs", "pid", "net", "identity", "terminal"))
    assert policy["permissions"] == {"fetch": "ask", "index_update": "ask"}
    assert policy["min_client"] == "2026.10.10.3", "the client whose probe knows a setuid bwrap cannot forbid nested user namespaces"

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds(PKG_FILE)
