"""验证 micro 的包定义、安装和内置编辑器插件"""

import os
from pathlib import Path
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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

RECIPE = "pkgs/m/micro.lua"


@pytest.mark.static
def test_metadata():
    """检查包元数据以及上游提供的命令和平台"""
    meta = parse_xpkg(RECIPE)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)
    assert_no_typos(RECIPE)
    assert meta.programs == ["micro"]
    assert set(meta.platforms) == {"linux", "macosx", "windows"}


@pytest.mark.isolation
def test_isolation():
    """检查生命周期钩子是否符合仓库的隔离约束"""
    assert_no_exec_xvm(RECIPE)
    assert_no_bashrc_modification(RECIPE)
    assert_no_direct_path_modification(RECIPE)
    assert_no_direct_pkg_manager(RECIPE)
    assert_uses_new_api(RECIPE)


@pytest.mark.index
def test_registration():
    """将配方注册到当前 xlings 索引"""
    subprocess.run(["xlings", "config", "--add-xpkg", str(Path(RECIPE).resolve())],
                   check=True, timeout=60)


@pytest.mark.lifecycle
def test_install():
    """安装当前索引中待测的 micro 版本"""
    subprocess.run(["xlings", "install", under_test("micro"), "-y"], check=True, timeout=180)


@pytest.mark.verify
def test_builtin_plugins(tmp_path):
    """通过已安装的编辑器读取内置插件，使用临时目录保存配置"""
    subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
    exe = "micro.exe" if os.name == "nt" else "micro"
    shim = Path(xlings_home()) / "subos" / subos / "bin" / exe
    result = subprocess.run(
        [str(shim), "-config-dir", str(tmp_path), "-plugin", "list"],
        capture_output=True, check=True, text=True, timeout=30,
    )
    assert "autoclose (built-in)" in result.stdout
