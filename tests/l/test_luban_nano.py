import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

# The Luban model (§A4): nothing but what every root has -- no package, no
# libc, no init; every layer above the kernel is a choice of an edition.
@pytest.mark.static
def test_nano_chooses_nothing(tmp_path):
    target = tmp_path / "nano"
    result = run_recipe("pkgs/l/luban-nano.lua", target, "2026.10.10.1")
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    assert manifest["subos_kind"] == "rootfs"
    assert manifest["packages"] == []
    assert manifest["abi"]["libc"] == "none"
    assert "init" not in manifest["boot"]

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds("pkgs/l/luban-nano.lua")
