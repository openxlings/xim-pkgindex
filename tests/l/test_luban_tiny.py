import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

# 0.1.0 is as it was published (the kernel in the root); the date versions
# leave the kernel to the machine and say which one it boots (Luban design §A6).
@pytest.mark.static
@pytest.mark.parametrize("version,kernel_in_root", [("0.1.0", True), ("2026.10.10.1", False)])
def test_tiny_userland_and_its_kernel(tmp_path, version, kernel_in_root):
    target = tmp_path / "tiny"
    result = run_recipe("pkgs/l/luban-tiny.lua", target, version)
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    assert manifest["subos_kind"] == "rootfs"
    assert any(p.startswith("xim:linux-kernel@") for p in manifest["packages"]) == kernel_in_root
    assert any(p.startswith("xim:glibc@") for p in manifest["packages"])
    if not kernel_in_root:
        assert manifest["abi"] == "x86_64-linux-gnu"
        assert manifest["boot"]["kernel"].startswith("xim:linux-kernel@")
        assert manifest["boot"]["kernel_min"] == "5.10"
    assert f"VERSION_ID={version}" in (target / "usr/share/factory/etc/os-release").read_text()

@pytest.mark.static
def test_an_unpublished_version_has_no_manifest(tmp_path):
    assert run_recipe("pkgs/l/luban-tiny.lua", tmp_path / "x", "0.2.0").returncode != 0

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds("pkgs/l/luban-tiny.lua")
