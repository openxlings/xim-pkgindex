import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

# Private when it is made (§C3): the edition declares its policy; subos new
# selects and locks it before anything enters. No owner-side script.
@pytest.mark.static
def test_the_workspace_declares_its_policy_and_its_tools(tmp_path):
    target = tmp_path / "ws"
    result = run_recipe("pkgs/l/luban-agent-workspace.lua", target, "2026.10.10.1")
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    assert manifest["from"] == "subos:luban-core@2026.10.10.1"
    assert manifest["policy"] == "xim:agent-private@2026.10.10.1"
    assert any(p.startswith("xim:claude@") for p in manifest["packages"])
    motd = (target / "usr/share/factory/etc/motd").read_text()
    assert "Not hidden on a shared kernel" in motd

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds("pkgs/l/luban-agent-workspace.lua")
