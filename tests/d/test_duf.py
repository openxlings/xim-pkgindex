"""duf metadata, isolation, installed payload and real disk-information tests."""
import json
import os
from pathlib import Path
import re
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
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home, xpkgs_dir
from tests.lib.xpkg_parser import parse_xpkg

PKG = "duf"
PKG_FILE = "pkgs/d/duf.lua"
VERSION = "0.9.1"
REPO = Path(__file__).resolve().parents[2]


def _run_xlings(*args, timeout=180):
    """Use the native client without login-shell environment overrides or WSL."""
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for package index and lifecycle checks"
    result = subprocess.run(
        [command, *args], capture_output=True, text=True, encoding="utf-8",
        errors="replace", timeout=timeout,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


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
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_resource_matrix_matches_autoupdate(self, meta):
        assert set(meta.platforms) == {"linux", "macosx", "windows"}
        lua = shutil.which("lua5.4") or shutil.which("lua")
        if not lua:
            pytest.skip("Lua interpreter is unavailable")
        subprocess.run(
            [lua, "-", PKG_FILE, VERSION],
            input='''
import = function() end
dofile(arg[1])
local version = arg[2]
local auto = assert(package.extensions.autoupdate)
assert(auto.source == package.repo .. "/releases")
assert(auto.resources.GLOBAL.required == true)
assert(auto.resources.CN == nil)
assert(package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
assert(package.xvm_enable and package.programs[1] == package.name)
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[platform])
    assert(p.latest.ref == version)
    assert(p.deps == nil)
    local v = assert(p[version])
    for _, arch in ipairs(package.archs) do
        local hash = assert(v.sha256[arch])
        assert(#hash == 64 and hash:match("^%x+$"))
        local url = p.source:gsub("%${version}", version)
            :gsub("%${arch_alias}", v.arch_alias[arch])
        local update = assert(auto.resources.GLOBAL.url[platform][arch])
            :gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        assert(url == update, platform .. "/" .. arch .. " URL mismatch")
    end
end
''',
            text=True,
            capture_output=True,
            check=True,
            cwd=REPO,
            timeout=15,
        )


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
    def test_no_host_package_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_runtime(self, meta):
        imports = set(re.findall(r'import\("([^"]+)"\)', meta.raw_content))
        assert imports <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.shell",
        }
        assert not re.search(
            r'\b(?:path\.|is_host\(|os\.(?:host|arch|curdir|execv)\(|raise\()',
            meta.raw_content,
        )


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        _run_xlings("config", "--add-xpkg", str(REPO / PKG_FILE), "--agent", timeout=45)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        output = _run_xlings("install", under_test(PKG), "--yes", "--agent")
        assert "installed" in output.lower(), output


class TestVerify:
    def _run(self, *args):
        home = Path(xlings_home()) / "subos"
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = home / subos / "bin"
        if not bindir.is_dir():
            bindir = home / "default" / "bin"
        shim = bindir / ("duf.exe" if os.name == "nt" else "duf")
        assert shim.is_file(), f"Missing installed duf shim: {shim}"
        return subprocess.run(
            [str(shim), *args], capture_output=True, text=True,
            encoding="utf-8", check=True, timeout=30,
        ).stdout

    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert expected in self._run("--version")

    @pytest.mark.verify
    def test_payload(self):
        version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        roots = list(Path(xpkgs_dir()).glob(f"*-x-duf/{version}"))
        exe = "duf.exe" if os.name == "nt" else "duf"
        assert any((root / exe).is_file() and (root / "duf.1").is_file()
                   for root in roots), f"duf executable/man page missing: {roots}"

    @pytest.mark.verify
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_json_describes_mounted_filesystems(self):
        rows = json.loads(self._run("--json"))
        assert isinstance(rows, list) and rows
        for row in rows:
            for key in ("device", "mount_point", "fs_type"):
                assert isinstance(row[key], str) and row[key]
            for key in ("total", "used", "free"):
                assert type(row[key]) is int and row[key] >= 0
            assert row["used"] <= row["total"]
            assert row["free"] <= row["total"]
        assert any(row["total"] > 0 and Path(row["mount_point"]).is_dir()
                   for row in rows), "No real mounted filesystem with capacity reported"
