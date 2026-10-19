import json
import pytest
from tests.lib.luban_recipe import run_recipe
from tests.lib.assertions import assert_xim_add_succeeds

@pytest.mark.static
@pytest.mark.parametrize("version", ["0.1.0", "2026.10.11.1"])
def test_default_development_tools(tmp_path, version):
    target = tmp_path / "core"
    result = run_recipe("pkgs/luban/luban-core.lua", target, version)
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    names = {p.split(":")[1].split("@")[0] for p in manifest["packages"]}
    assert {"bash", "coreutils", "gcc", "binutils", "make"} <= names
    extra = {"fish", "vim", "nvim", "git", "mcpp", "ninja"}
    assert (extra <= names) if version != "0.1.0" else not (extra & names)
    assert "claude" not in names, "an agent's tools are luban-agent-workspace's"
    assert manifest["from"] == "subos:luban-tiny@" + version

@pytest.mark.index
def test_index():
    assert_xim_add_succeeds("pkgs/luban/luban-core.lua")


@pytest.mark.static
def test_2026_10_19_adds_cmake_xmake_yazi_and_procps(tmp_path):
    """core 2026.10.19.1 (xlings design 2026-10-19 §20): the new tools, ps
    procps-ng's, and cmake/xmake only where they are offered (x86_64)."""
    target = tmp_path / "core"
    result = run_recipe("pkgs/luban/core.lua", target, "2026.10.19.1")
    assert result.returncode == 0, result.stderr
    manifest = json.loads((target / ".xlings.json").read_text())
    names = {p.split(":")[1].split("@")[0] for p in manifest["packages"]}
    assert {"yazi", "procps-ng", "gcc", "fish", "mcpp"} <= names
    import platform
    if platform.machine() in ("x86_64", "AMD64"):
        assert {"cmake", "xmake"} <= names
    checks = json.loads((target / "usr/share/luban/checks.d/core.json").read_text())
    tools = next(c for c in checks["checks"] if c["id"] == "core-tools")
    assert "ps -C ps" in tools["run"] and "yazi --version" in tools["run"]
    assert manifest["from"] == "luban:tiny@2026.10.18.1"
