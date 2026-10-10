import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

# 0.1.0 is as it was published (the kernel in the root); the date versions
# leave the kernel to the machine and say which one it boots (Luban design §A6).
@pytest.mark.static
@pytest.mark.parametrize("version,kernel_in_root", [("0.1.0", True), ("2026.10.11.1", False)])
def test_tiny_userland_and_its_kernel(tmp_path, version, kernel_in_root):
    target = tmp_path / "tiny"
    result = run_recipe("pkgs/l/luban-tiny.lua", target, version)
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    assert manifest["subos_kind"] == "rootfs"
    assert any(p.startswith("xim:linux-kernel@") for p in manifest["packages"]) == kernel_in_root
    assert any(p.startswith("xim:glibc@") for p in manifest["packages"])
    if not kernel_in_root:
        # No architecture: every package is published for x86_64 and aarch64.
        assert manifest["abi"] == {"kernel": "linux", "libc": "gnu"}
        assert manifest["from"].startswith("subos:luban-nano@")
        assert manifest["boot"]["profile"].startswith("xim:luban-boot-generic@")
        assert manifest["boot"]["kernel"].startswith("xim:linux-kernel@"), "the hint an older client reads"
        assert manifest["boot"]["kernel_min"] == "5.10"
        assert manifest["min_client"] == "2026.10.11.1"
        inittab = (target / "usr/share/factory/etc/inittab").read_text()
        assert "::restart:/usr/bin/luban-init" in inittab and "xlings-init" not in inittab
    assert f"VERSION_ID={version}" in (target / "usr/share/factory/etc/os-release").read_text()

@pytest.mark.static
def test_an_unpublished_version_has_no_manifest(tmp_path):
    assert run_recipe("pkgs/l/luban-tiny.lua", tmp_path / "x", "0.2.0").returncode != 0

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds("pkgs/l/luban-tiny.lua")
