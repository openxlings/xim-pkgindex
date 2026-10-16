"""The Luban editions of 2026.10.16.2: 2026.10.16.1 with mcpp 2026.10.16.3,
which reads the system configuration's upstream (/xlings) and whose xlings
builds its catalog inside a system, so that mcpp in a system borrows the
system's gcc instead of downloading it (mcpp design 2026-10-16 §9.5)."""
import json

import pytest
from tests.lib.luban_recipe import run_recipe

V = "2026.10.16.2"


def made(tmp_path, edition):
    target = tmp_path / edition
    result = run_recipe(f"pkgs/luban/luban-{edition}.lua", target, V)
    assert result.returncode == 0, result.stderr + result.stdout
    return target, json.loads((target / ".xlings.json").read_text())


@pytest.mark.static
def test_core_carries_the_mcpp_that_reads_the_upstream(tmp_path):
    target, manifest = made(tmp_path, "core")
    assert "xim:mcpp@2026.10.16.3" in manifest["packages"]
    assert manifest["from"] == "subos:luban-tiny@2026.10.16.1"
    config = (target / "usr/share/factory/etc/mcpp/config.toml").read_text()
    assert 'upstream = ["/xlings"]' in config


@pytest.mark.static
@pytest.mark.parametrize("edition", ["agent-workspace", "desktop", "desktop-xdesk"])
def test_an_edition_on_core_is_on_this_core(tmp_path, edition):
    _, manifest = made(tmp_path, edition)
    assert manifest["from"] == f"subos:luban-core@{V}"
    assert manifest["min_client"] == "2026.10.16.1"


@pytest.mark.static
@pytest.mark.parametrize("arch", ["x86_64", "aarch64"])
def test_mcpp_targets_this_machines_glibc(tmp_path, arch):
    # On aarch64 the target was x86_64-linux-gnu, which mcpp refuses to build
    # there (editions CI, 2026-10-17).
    from tests.lib.luban_recipe import run_recipe as run
    target = tmp_path / arch
    result = run("pkgs/luban/luban-core.lua", target, V, env={"LUBAN_TEST_ARCH": arch})
    assert result.returncode == 0, result.stderr + result.stdout
    config = (target / "usr/share/factory/etc/mcpp/config.toml").read_text()
    assert f'default_target = "{arch}-linux-gnu"' in config
