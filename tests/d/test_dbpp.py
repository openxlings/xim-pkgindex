"""Tests for the farnaherry:dbpp package."""
import json
import os
from pathlib import Path
import re
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
    assert_xim_add_succeeds,
)
from tests.lib.platform_utils import xlings_home
from tests.lib.xpkg_parser import parse_xpkg

VERSION = "0.4.2"
PKG = f"farnaherry:dbpp@{VERSION}"
PKG_NAME = "dbpp"
PKG_FILE = "pkgs/d/dbpp.lua"


def _dbpp(*args, env=None):
    bins = [str(Path(xlings_home()) / "subos" / name / "bin") for name in ("current", "default")]
    executable = shutil.which(PKG_NAME, path=os.pathsep.join(bins))
    assert executable, "dbpp shim is missing from XLINGS_HOME"
    result = subprocess.run(
        [executable, *args],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        check=True,
    ).stdout


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)
        assert meta.spec == "2"

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_namespace_and_platforms(self, meta):
        assert meta.namespace == "farnaherry"
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)
        assert meta.programs == []
        assert meta.has_xvm_enable is True

    @pytest.mark.static
    def test_arch_gating_and_runtime_deps(self):
        out = _run_lua(
            '''
import = function() end
os.arch = function() return "x86_64" end
dofile(arg[1])
assert(package.xpm.linux.deps and package.xpm.linux.deps.runtime)
for _, dep in ipairs(package.xpm.linux.deps.runtime) do
    assert(dep:match("^xim:"), "expected xim: prefix on " .. dep)
end
print("X64_OK")
''',
            PKG_FILE,
        )
        assert "X64_OK" in out

        out_arm = _run_lua(
            '''
import = function() end
os.arch = function() return "aarch64" end
dofile(arg[1])
assert(package.xpm.linux.deps == nil)
print("ARM64_OK")
''',
            PKG_FILE,
        )
        assert "ARM64_OK" in out_arm


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


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

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_lua_and_approved_imports_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.selfcontain",
        }
        assert not re.search(r"\b(?:path\.|is_host\(|os\.host\(|raise\()", src)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        result = subprocess.run(
            ["xlings", "install", PKG, "-y"],
            capture_output=True,
            text=True,
            timeout=600,
        )
        assert result.returncode == 0, result.stdout + result.stderr


class TestVerify:
    @pytest.mark.verify
    def test_version_and_help(self):
        assert VERSION in _dbpp("--version")
        assert "SQLite-first ADBC" in _dbpp("--help")

    @pytest.mark.verify
    def test_doctor_and_sqlite_cli(self, tmp_path):
        env = {
            **os.environ,
            "HOME": str(tmp_path),
            "XDG_DATA_HOME": str(tmp_path / "data"),
            "XDG_CONFIG_HOME": str(tmp_path / "config"),
            "DBPP_DATA_DIR": str(tmp_path / "dbpp-data"),
        }
        info = json.loads(_dbpp("doctor", "--json", env=env))
        assert info["ok"] is True
        assert info["version"] == VERSION
        assert info["sqlite_driver_exists"] is True

        db_path = tmp_path / "verify.sqlite"
        for statement in (
            "CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT);",
            "INSERT INTO items (name) VALUES ('xlings');",
        ):
            result = json.loads(_dbpp("exec", "--sqlite", str(db_path), statement, "--json", env=env))
            assert result["ok"] is True

        res = json.loads(_dbpp(
            "query", "--sqlite", str(db_path), "SELECT id, name FROM items;", "--json", env=env,
        ))
        assert res["ok"] is True
        assert res["row_count"] == 1
        assert res["rows"] == [["1", "xlings"]]
