"""验证 kubectx 的包定义、安装和离线上下文切换"""

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

PKG_FILE = "pkgs/k/kubectx.lua"


@pytest.mark.static
def test_package_definition():
    """检查包的元数据和注册命令是否符合规范"""
    meta = parse_xpkg(PKG_FILE)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)
    assert_valid_xvm_node_kinds(meta)
    assert_config_registers_package_name(meta)
    assert_no_typos(PKG_FILE)
    assert meta.programs == ["kubectx"]
    assert set(meta.platforms) == {"linux", "macosx", "windows"}


@pytest.mark.isolation
def test_hook_isolation():
    """检查安装钩子是否遵循环境隔离要求"""
    assert_no_exec_xvm(PKG_FILE)
    assert_no_bashrc_modification(PKG_FILE)
    assert_no_direct_path_modification(PKG_FILE)
    assert_no_direct_pkg_manager(PKG_FILE)
    assert_uses_new_api(PKG_FILE)


@pytest.mark.index
def test_registration():
    """将本地包加入索引并确认搜索结果包含 kubectx"""
    subprocess.run(["xlings", "config", "--add-xpkg", str(Path(PKG_FILE).resolve())],
                   check=True, timeout=60)
    result = subprocess.run(["xlings", "search", "kubectx"], check=True,
                            capture_output=True, text=True, timeout=60)
    assert "List and switch Kubernetes contexts" in result.stdout


@pytest.mark.lifecycle
def test_install():
    """从当前测试索引安装 kubectx"""
    subprocess.run(["xlings", "install", under_test("kubectx"), "-y"], check=True, timeout=180)


@pytest.mark.verify
def test_switch_context(tmp_path):
    """通过已安装的命令切换临时 kubeconfig 中的上下文并恢复上一次选择"""
    subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
    bindir = Path(xlings_home()) / "subos" / subos / "bin"
    shim = shutil.which("kubectx", path=str(bindir))
    assert shim, f"kubectx shim missing in {bindir}"

    config = tmp_path / "config"
    config.write_text(
        "apiVersion: v1\nkind: Config\ncurrent-context: first\n"
        "contexts:\n- name: first\n  context: {}\n- name: second\n  context: {}\n",
        encoding="utf-8",
    )
    env = {**os.environ, "KUBECONFIG": str(config), "XDG_CACHE_HOME": str(tmp_path),
           "KUBECTX_IGNORE_FZF": "1", "NO_COLOR": "1"}

    def kubectx(*args):
        """通过子系统入口运行命令并读取标准输出"""
        return subprocess.run([shim, *args], env=env, check=True, capture_output=True,
                              text=True, timeout=20).stdout.strip()

    assert set(kubectx().splitlines()) == {"first", "second"}
    assert kubectx("--current") == "first"
    kubectx("second")
    assert kubectx("--current") == "second"
    kubectx("-")
    assert kubectx("--current") == "first"
