import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

# The libc is a choice (Luban OS design part 2 §2.3): the same machine as
# tiny, on musl.
@pytest.mark.static
def test_tiny_on_musl(tmp_path):
    target = tmp_path / "tiny-musl"
    result = run_recipe("pkgs/l/luban-tiny-musl.lua", target, "2026.10.11.1")
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    assert manifest["abi"] == {"kernel": "linux", "libc": "musl"}
    assert manifest["from"].startswith("subos:luban-nano@")
    assert any(p.startswith("xim:musl@") for p in manifest["packages"])
    assert not any(p.startswith("xim:glibc@") for p in manifest["packages"])
    assert manifest["min_client"] == "2026.10.11.1", "the client that makes a musl root"
    assert "::restart:/usr/bin/luban-init" in (target / "usr/share/factory/etc/inittab").read_text()
    assert 'VARIANT_ID=tiny-musl' in (target / "usr/share/factory/etc/os-release").read_text()

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds("pkgs/l/luban-tiny-musl.lua")
