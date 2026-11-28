"""检查 broot 的资源矩阵、安装隔离与嵌入的默认配置。"""
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_required_fields,
    assert_uses_new_api,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

REPO = Path(__file__).resolve().parents[2]
RECIPE = REPO / "pkgs/b/broot.lua"
EXE = ".exe" if os.name == "nt" else ""


def run_xlings(*args):
    """直接运行当前环境的客户端，并检查安装钩子的报错"""
    client = Path(xlings_home()) / "bin" / ("xlings" + EXE)
    command = str(client) if client.is_file() else shutil.which("xlings")
    assert command
    result = subprocess.run(
        [command, *args], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=240,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output


@pytest.mark.static
def test_recipe():
    """检查必填元数据、受支持的平台和命令注册"""
    meta = parse_xpkg(str(RECIPE))
    assert_required_fields(meta)
    assert meta.spec == "2" and meta.pkg_type == "package"
    assert meta.programs == ["broot"]
    assert set(meta.platforms) == {"linux", "macosx", "windows"}
    assert_config_registers_package_name(meta)


@pytest.mark.static
def test_shared_archive_matrix():
    """核对四个受支持目标的更新地址、归档校验值与解压依赖"""
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("需要 Lua 检查资源矩阵")
    subprocess.run(
        [lua, "-", str(RECIPE)], check=True, text=True, timeout=10,
        input="""
import = function() end
dofile(arg[1])
local urls = package.extensions.autoupdate.resources.GLOBAL.url
local hash = "13630ae5d3b011ddc81fca05cb80dbee6189dad3ba393dd477f5f687c7b5106d"
local version = "1.62.0"
local source = package.xpm.source:gsub("%${version}", version)
assert(package.ci.mirror)
for _, host in ipairs({"linux", "macosx", "windows"}) do
    local section = package.xpm[host]
    assert(section.deps.build[1] == "xim:7zip" and not section.deps.runtime)
    for _, arch in ipairs({"aarch64", "x86_64"}) do
        local supported = host == "linux" or host == "macosx" and arch == "aarch64"
            or host == "windows" and arch == "x86_64"
        local url = urls[host][arch]
        assert(section[version].sha256[arch] == (supported and hash or nil))
        if supported then
            assert(url:gsub("%${tag}", "v" .. version):gsub("%${version}", version) == source)
        else
            assert(url == nil)
        end
    end
end
""",
    )


@pytest.mark.isolation
def test_hook_isolation():
    """检查钩子对 shell 配置、命令搜索路径和系统包管理器的隔离"""
    for check in (
        assert_no_bashrc_modification, assert_no_direct_path_modification,
        assert_no_direct_pkg_manager, assert_no_exec_xvm, assert_uses_new_api,
    ):
        check(str(RECIPE))


@pytest.mark.index
def test_index():
    """在测试索引中注册配方"""
    run_xlings("config", "--add-xpkg", str(RECIPE))


@pytest.mark.lifecycle
def test_install():
    """使用测试索引安装 broot"""
    run_xlings("install", under_test("broot"), "-y")


@pytest.mark.verify
def test_embedded_configuration(tmp_path):
    """通过已安装的命令导出默认配置，验证程序可独立使用嵌入的资源"""
    subos = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default")
    shim = subos / "bin" / ("broot" + EXE)
    result = subprocess.run(
        [str(shim), "--write-default-conf", str(tmp_path)], capture_output=True, timeout=15,
    )
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "conf.hjson").is_file()
    assert (tmp_path / "verbs.hjson").is_file()
    assert (tmp_path / "skins" / "dark-blue.hjson").is_file()
