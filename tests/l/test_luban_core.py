import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

@pytest.mark.static
@pytest.mark.parametrize("version", ["0.1.0", "0.2.0"])
def test_default_development_tools(tmp_path, version):
    target = tmp_path / "core"
    result = run_recipe("pkgs/l/luban-core.lua", target, version)
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    names = {p.split(":")[1].split("@")[0] for p in manifest["packages"]}
    assert {"bash", "coreutils", "gcc", "binutils", "make"} <= names
    extra = {"fish", "vim", "nvim", "git", "mcpp", "claude"}
    assert (extra <= names) if version == "0.2.0" else not (extra & names)
    assert manifest["from"] == "subos:luban-tiny@" + version

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds("pkgs/l/luban-core.lua")
