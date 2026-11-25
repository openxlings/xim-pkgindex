"""Tests for duckdb package (in-process analytical SQL database CLI)."""
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
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "duckdb"
PKG_FILE = "pkgs/d/duckdb.lua"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


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

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_platforms_deps_and_sha256_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
local linux = assert(package.xpm.linux)
assert(linux.deps and linux.deps.runtime, "linux must declare runtime deps")
local seen = {}
for _, d in ipairs(linux.deps.runtime) do seen[d] = true end
assert(seen["xim:glibc@>=2.39"], "linux must depend on xim:glibc@>=2.39")
assert(seen["xim:gcc-runtime"], "linux must depend on xim:gcc-runtime")

for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "2.0.1", plat .. " latest must ref 2.0.1")
    assert(type(p.source) == "string" and p.source:find("${version}", 1, true),
           plat .. " source must template ${version}")
    local v = assert(p["2.0.1"], "missing 2.0.1 on " .. plat)
    assert(v.arch_alias and v.arch_alias.x86_64 == "amd64" and v.arch_alias.aarch64 == "arm64",
           plat .. " arch_alias mismatch")
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(v.sha256 and v.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"),
               "invalid sha256 for " .. plat .. "/" .. arch)
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_install_posix_and_windows_zip_sandbox(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX pre-extracted binary beside archive
local files, execs = {}, {}
local host = "linux"
local install_file = "/tmp/cache/duckdb-cli-linux-amd64.tar.gz"
local install_dir = "/tmp/xpkgs/duckdb/2.0.1"
os.host = function() return host end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function() end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function() end }
log = { info = function() end }
system = { exec = function(cmd) execs[#execs + 1] = cmd end }
pkginfo = {
    name = function() return "duckdb" end,
    version = function() return "2.0.1" end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
}

files["/tmp/cache/duckdb"] = true
assert(not installed())
assert(install())
assert(installed())
assert(files["/tmp/xpkgs/duckdb/2.0.1/duckdb"])
assert(#execs == 1 and execs[1]:find("chmod +x", 1, true))

-- Case 2: Windows .zip not pre-extracted -> falls back to payload.unpack (System32 tar.exe)
files, execs = {}, {}
host = "windows"
install_file = "C:/cache/duckdb-cli-windows-amd64.zip"
install_dir = "C:/xpkgs/duckdb/2.0.1"
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system.exec = function(cmd)
    execs[#execs + 1] = cmd
    files["C:/xpkgs/duckdb/2.0.1/duckdb.exe"] = true
end
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1 and execs[1]:find("System32\\\\tar.exe", 1, true))
''', PKG_FILE)


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
    def test_portable_lua_and_libxpkg_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
            "xim.libxpkg.system", "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_duckdb_version(self):
        assert_command_output("duckdb --version", contains="2.0.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_duckdb_query(self):
        assert_command_output('duckdb -c "SELECT 42 AS answer;"', contains="42")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_duckdb(self):
        assert_xvm_registered("duckdb")
