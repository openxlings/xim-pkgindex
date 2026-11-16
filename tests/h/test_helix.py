"""测试 helix 包"""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xvm_registered,
)

from tests.lib.platform_utils import under_test, xlings_home

PKG = "helix"
PKG_FILE = "pkgs/h/helix.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        recipe = Path(__file__).resolve().parents[2] / PKG_FILE
        run_xlings("config", "--add-xpkg", str(recipe))


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        run_xlings("install", under_test(PKG), "--yes", "--agent")


def run_xlings(*args):
    # Native argv avoids Windows' WSL bash.exe and shell-profile PATH changes.
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for package lifecycle checks"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


class TestVerify:
    def run_hx(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("hx" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        env = dict(os.environ)
        env.pop("HELIX_RUNTIME", None)
        result = subprocess.run([str(shim), *args], env=env, capture_output=True,
                                text=True, encoding="utf-8", timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        return re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)

    @pytest.mark.verify
    def test_version(self):
        version = self.run_hx("--version")
        assert re.match(r"helix \d+\.\d+(?:\.\d+)?\b", version), version
        if os.environ.get("XLINGS_TEST_VERSION"):
            assert version.split()[1] == os.environ["XLINGS_TEST_VERSION"]

    @pytest.mark.verify
    def test_runtime(self):
        health = self.run_hx("--health", "rust")
        for resource in ("Tree-sitter parser", "Highlight queries",
                         "Textobject queries", "Indent queries"):
            assert re.search(re.escape(resource) + r":\s*✓", health), health

    @pytest.mark.verify
    def test_xvm(self):
        assert_xvm_registered("helix")
        assert_xvm_registered("hx")
