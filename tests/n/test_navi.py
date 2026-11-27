"""验证 navi 的平台注册、安装和离线速查表检索。"""

import os
from pathlib import Path
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg


RECIPE = "pkgs/n/navi.lua"
VERSION = os.environ.get("XLINGS_TEST_VERSION", "2.24.0")
SUFFIX = ".exe" if os.name == "nt" else ""


def run_xlings(*args):
    """直接运行当前测试环境的 xlings，使用调用者提供的隔离目录。"""
    name = "xlings" + SUFFIX
    executable = Path(xlings_home()) / "bin" / name
    if not executable.is_file():
        executable = shutil.which(name)
    assert executable, "missing xlings executable"
    subprocess.run([executable, *args], check=True, timeout=480)


@pytest.mark.static
def test_metadata():
    """核对元数据、平台及声明的命令。"""
    meta = parse_xpkg(RECIPE)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)
    assert_valid_xvm_node_kinds(meta)
    assert_no_typos(RECIPE)
    assert meta.spec == "2" and meta.has_xvm_enable
    assert meta.programs == ["navi"]
    assert set(meta.platforms) == {"linux", "windows"}


@pytest.mark.static
def test_finder_and_shell_dependencies():
    """在 Lua 中校验每个平台实际生效的运行依赖。"""
    check = """
import = function() end
dofile(arg[1])
assert(#package.archs == 1 and package.archs[1] == "x86_64")
for platform, required in pairs({
    linux = {"xim:fzf", "xim:bash", "xim:coreutils", "xim:git"},
    windows = {"xim:fzf", "xim:git"},
}) do
    local deps = package.xpm[platform].deps.runtime
    for _, name in ipairs(required) do
        local found = false
        for _, dep in ipairs(deps) do if dep == name then found = true end end
        assert(found, platform .. " requires " .. name)
    end
end
"""
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to inspect the dependency declarations"
    subprocess.run([lua, "-", RECIPE], input=check, text=True, check=True)


@pytest.mark.isolation
def test_hooks_stay_in_subos():
    """检查安装钩子的隔离边界。"""
    assert_no_bashrc_modification(RECIPE)
    assert_no_direct_path_modification(RECIPE)
    assert_no_direct_pkg_manager(RECIPE)
    assert_no_exec_xvm(RECIPE)
    assert_uses_new_api(RECIPE)


@pytest.mark.index
def test_register():
    """将被测配方注册到隔离索引。"""
    run_xlings("config", "--add-xpkg", str(Path(RECIPE).resolve()))


@pytest.mark.lifecycle
def test_install():
    """安装本轮测试所选的包和依赖。"""
    run_xlings("install", under_test("navi", VERSION), "-y")


@pytest.mark.verify
def test_print_best_local_match(tmp_path):
    """只从子系统查找 fzf，打印本地匹配项并保留命令原文。"""
    subos = Path(xlings_home()) / "subos"
    active = os.environ.get("XLINGS_TEST_SUBOS")
    if not active:
        active = "current" if (subos / "current" / "bin").is_dir() else "default"
    bin_dir = subos / active / "bin"
    assert (bin_dir / ("fzf" + SUFFIX)).is_file()
    navi = bin_dir / ("navi" + SUFFIX)
    env = dict(os.environ, PATH=str(bin_dir), NAVI_CONFIG_YAML="{}")
    version = subprocess.run([navi, "--version"], env=env, capture_output=True,
                             text=True, check=True, timeout=15)
    assert version.stdout.strip() == f"navi {VERSION}"

    (tmp_path / "example.cheat").write_text(
        "% sample\n\n# First candidate\necho first\n\n# Second candidate\necho second\n",
        encoding="utf-8",
    )
    result = subprocess.run(
        [navi, "--path", tmp_path, "--query", "Second candidate", "--best-match", "--print"],
        env=env, capture_output=True, text=True, check=True, timeout=30,
    )
    assert result.stdout.strip() == "echo second"
