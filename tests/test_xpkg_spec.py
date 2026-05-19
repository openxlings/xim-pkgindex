"""xpkg spec 规范强制检测 — 对所有包执行 D1/D3 规则

D1: config hook 必须通过 xvm.add(package.name) 注册包名
D3: 普通包(非 script/config/bugfix/template)必须定义 config hook

豁免条件:
- ref 包
- 有自定义 installed() hook 的包
- type 为 script/config/bugfix/template 的包
"""
import glob
import os
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import assert_config_registers_package_name


def _discover_xpkg_files():
    """扫描 pkgs/ 下所有 .lua 文件"""
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pattern = os.path.join(project_root, "pkgs", "**", "*.lua")
    files = sorted(glob.glob(pattern, recursive=True))
    # 返回相对路径用于 test ID
    return [os.path.relpath(f, project_root) for f in files]


@pytest.mark.static
@pytest.mark.parametrize("pkg_file", _discover_xpkg_files(), ids=lambda f: os.path.basename(f).replace(".lua", ""))
def test_spec_d1_package_name_registered(pkg_file):
    """[Spec D1/D3] 包必须在 config hook 中注册 package.name"""
    meta = parse_xpkg(pkg_file)
    assert_config_registers_package_name(meta)
