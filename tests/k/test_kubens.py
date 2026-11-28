"""验证 kubens 的包定义、安装和离线命名空间切换"""

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
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG_FILE = "pkgs/k/kubens.lua"


@pytest.mark.static
def test_package_definition():
    """检查包元数据、目标平台和导出的命令"""
    meta = parse_xpkg(PKG_FILE)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)
    assert_valid_xvm_node_kinds(meta)
    assert_config_registers_package_name(meta)
    assert_no_typos(PKG_FILE)
    assert meta.programs == ["kubens"]
    assert set(meta.platforms) == {"linux", "macosx", "windows"}


@pytest.mark.isolation
def test_hook_isolation():
    """检查安装钩子是否遵守环境隔离要求"""
    assert_no_exec_xvm(PKG_FILE)
    assert_no_bashrc_modification(PKG_FILE)
    assert_no_direct_path_modification(PKG_FILE)
    assert_no_direct_pkg_manager(PKG_FILE)
    assert_uses_new_api(PKG_FILE)


@pytest.mark.index
def test_registration():
    """注册包并确认本地索引可以找到 kubens"""
    subprocess.run(["xlings", "config", "--add-xpkg", str(Path(PKG_FILE).resolve())],
                   check=True, timeout=60)
    result = subprocess.run(["xlings", "search", "kubens"], capture_output=True,
                            text=True, check=True, timeout=60)
    assert "Switch the active Kubernetes namespace" in result.stdout


@pytest.mark.lifecycle
def test_install():
    """通过当前测试索引安装 kubens"""
    subprocess.run(["xlings", "install", under_test("kubens"), "-y"], check=True, timeout=180)


@pytest.mark.verify
def test_switch_namespace(tmp_path):
    """通过子系统入口离线切换命名空间，再恢复当前上下文的上一次选择"""
    subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
    bindir = Path(xlings_home()) / "subos" / subos / "bin"
    shim = shutil.which("kubens", path=str(bindir))
    assert shim, f"kubens shim missing in {bindir}"

    config = tmp_path / "kubeconfig"
    config.write_text(
        "apiVersion: v1\nkind: Config\ncurrent-context: isolated\n"
        "contexts:\n- name: isolated\n  context:\n    namespace: first\n",
        encoding="utf-8",
    )
    env = {**os.environ, "KUBECONFIG": str(config), "XDG_CACHE_HOME": str(tmp_path)}

    def kubens(*args):
        """运行命令并读取当前命名空间，错误输出随测试失败显示"""
        return subprocess.run([shim, *args], env=env, capture_output=True, text=True,
                              check=True, timeout=20).stdout.strip()

    assert kubens("--current") == "first"
    kubens("second", "--force")
    assert kubens("--current") == "second"
    kubens("-", "--force")
    assert kubens("--current") == "first"
