import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

# A boot profile (Luban OS design part 2 §2.4): the kernel release and the
# command line an image boots with; its kernel and limine are its deps.
@pytest.mark.static
@pytest.mark.parametrize("name,release,console", [
    ("luban-boot-generic", "6.8.0-71-generic", "console=ttyS0"),
    ("luban-boot-virt", "6.12.112-virt", "console=ttyAMA0"),
])
def test_a_profile_says_how_an_image_boots(tmp_path, name, release, console):
    target = tmp_path / name
    result = run_recipe(f"pkgs/l/{name}.lua", target, "2026.10.11.1")
    assert result.returncode == 0, result.stderr
    boot = json.loads((target / "share/luban/boot.json").read_text())
    assert boot["release"] == release
    assert console in boot["cmdline"]
    text = open(f"pkgs/l/{name}.lua").read()
    kernel = "linux-kernel-virt@6.12.112" if "virt" in name else "linux-kernel@6.8.0-71"
    assert f"xim:{kernel}" in text and "xim:limine@12.9.3" in text

@pytest.mark.index
@pytest.mark.parametrize("name", ["luban-boot-generic", "luban-boot-virt", "linux-kernel-virt"])
def test_index(name):
    assert_xim_add_succeeds(f"pkgs/l/{name}.lua")
