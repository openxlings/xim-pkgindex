"""验证录制程序的隔离安装与离线录制。"""
import os
from pathlib import Path
import subprocess

import pytest

from tests.lib.assertions import assert_no_direct_path_modification, assert_required_fields
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

RECIPE = "pkgs/a/asciinema.lua"


@pytest.mark.static
def test_metadata():
    """核查配方声明的平台。"""
    meta = parse_xpkg(RECIPE)
    assert_required_fields(meta)
    assert set(meta.platforms) == {"linux", "macosx"}


@pytest.mark.isolation
def test_environment():
    """检查安装钩子是否直接修改 PATH。"""
    assert_no_direct_path_modification(RECIPE)


@pytest.mark.index
def test_register():
    """将待测配方注册到当前测试索引。"""
    subprocess.run(["xlings", "config", "--add-xpkg", str(Path(RECIPE).resolve())], check=True)


@pytest.mark.lifecycle
def test_install():
    """通过当前测试索引安装录制程序。"""
    subprocess.run(["xlings", "install", under_test("asciinema"), "-y"], check=True)


@pytest.mark.verify
def test_record_and_convert(tmp_path):
    """录制一次临时终端输出，并从录制文件还原文本。"""
    base = Path(xlings_home()) / "subos"
    subos = os.getenv("XLINGS_TEST_SUBOS", "current")
    binary = base / subos / "bin/asciinema"
    if not binary.exists() and subos == "current":
        binary = base / "default/bin/asciinema"
    env = dict(os.environ, ASCIINEMA_CONFIG_HOME=str(tmp_path / "config"), SHELL="/bin/sh")
    cast = tmp_path / "sample.cast"
    subprocess.run([binary, "record", "--headless", "-c", "echo package-proof", cast],
                   env=env, check=True, timeout=20)
    raw = subprocess.check_output([binary, "convert", "-f", "raw", cast, "-"], env=env, timeout=20)
    assert b"package-proof" in raw
