"""验证 Oh My Posh 的包定义、命令注册和提示符渲染"""
import json
import os
import shutil
import subprocess
from pathlib import Path

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
from tests.lib.platform_utils import project_root, under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "oh-my-posh"
PKG_FILE = "pkgs/o/oh-my-posh.lua"


@pytest.mark.static
def test_package_definition():
    """确认包定义在三个平台提供同一条命令"""
    meta = parse_xpkg(PKG_FILE)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)
    assert_no_typos(PKG_FILE)
    assert_valid_xvm_node_kinds(meta)
    assert meta.programs == [PKG]
    assert meta.has_xvm_enable
    assert set(meta.platforms) == {"linux", "macosx", "windows"}


@pytest.mark.isolation
def test_hook_isolation():
    """确认钩子只使用包管理接口，保持用户的 shell 配置独立"""
    assert_no_exec_xvm(PKG_FILE)
    assert_no_bashrc_modification(PKG_FILE)
    assert_no_direct_path_modification(PKG_FILE)
    assert_no_direct_pkg_manager(PKG_FILE)
    assert_uses_new_api(PKG_FILE)


@pytest.mark.index
def test_register_recipe():
    """通过 xlings 注册当前工作树中的配方"""
    subprocess.run(
        ["xlings", "config", "--add-xpkg", Path(project_root()) / PKG_FILE],
        check=True, timeout=45,
    )


@pytest.mark.lifecycle
def test_install():
    """安装当前索引所提供的版本，以供后续验证"""
    subprocess.run(["xlings", "install", under_test(PKG), "-y"], check=True, timeout=180)


@pytest.mark.verify
def test_render_and_export(tmp_path, monkeypatch):
    """通过已注册的命令渲染临时提示符，并核对导出的配置"""
    home = Path(xlings_home())
    subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
    shim = shutil.which(PKG, path=str(home / "subos" / subos / "bin"))
    assert shim, "oh-my-posh shim is missing"

    monkeypatch.setenv("XLINGS_HOME", str(home))
    for key in ("HOME", "USERPROFILE", "LOCALAPPDATA", "XDG_CACHE_HOME", "XDG_CONFIG_HOME"):
        monkeypatch.setenv(key, str(tmp_path))

    version = subprocess.check_output([shim, "version"], text=True, timeout=15).strip()
    assert version
    store = under_test(PKG).replace(":", "-x-")
    executable = PKG + (".exe" if os.name == "nt" else "")
    assert (home / "data" / "xpkgs" / store / version / executable).is_file()
    if "XLINGS_TEST_VERSION" in os.environ:
        assert version == os.environ["XLINGS_TEST_VERSION"]

    segment = {"type": "text", "style": "plain", "template": "xim prompt"}
    blocks = [{"type": "prompt", "alignment": "left", "segments": [segment]}]
    config = tmp_path / "test.omp.json"
    config.write_text(json.dumps({"version": 4, "blocks": blocks}), encoding="utf-8")
    prompt = subprocess.check_output(
        [shim, "print", "primary", "--config", config, "--plain", "--shell", "bash"],
        cwd=tmp_path, text=True, timeout=15,
    )
    assert prompt == "xim prompt"
    exported = subprocess.check_output(
        [shim, "config", "export", "--config", config, "--format", "json"],
        cwd=tmp_path, text=True, timeout=15,
    )
    assert json.loads(exported)["blocks"] == blocks
