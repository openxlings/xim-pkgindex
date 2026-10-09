import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

@pytest.mark.static
@pytest.mark.parametrize("version,kernel", [("0.1.0", True), ("0.2.0", False)])
def test_tiny_userland_and_historical_kernel(tmp_path, version, kernel):
    target = tmp_path / "tiny"
    result = run_recipe("pkgs/l/luban-tiny.lua", target, version)
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    assert manifest["subos_kind"] == "rootfs"
    assert any(p.startswith("xim:linux-kernel@") for p in manifest["packages"]) == kernel
    assert any(p.startswith("xim:glibc@") for p in manifest["packages"])
    assert version in (target / "usr/share/factory/etc/os-release").read_text()

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds("pkgs/l/luban-tiny.lua")
