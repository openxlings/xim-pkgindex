"""Tests for surrealdb package (multi-model document-graph database CLI & server)."""
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
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "surrealdb"
PKG_FILE = "pkgs/s/surrealdb.lua"


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
        assert meta.programs == ["surreal"]
        _run_lua('''
import = function() end
dofile(arg[1])
local linux = assert(package.xpm.linux)
assert(linux.deps and linux.deps.runtime, "linux must declare runtime deps")
local seen = {}
for _, d in ipairs(linux.deps.runtime) do seen[d] = true end
assert(seen["xim:glibc@>=2.39"], "linux must depend on xim:glibc@>=2.39")
assert(seen["xim:gcc-runtime"], "linux must depend on xim:gcc-runtime")

local expected = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "4.0.1", plat .. " latest must ref 4.0.1")
    assert(type(p.source) == "string" and p.source:find("${version}", 1, true),
           plat .. " source must template ${version}")
    local v = assert(p["4.0.1"], "missing 4.0.1 on " .. plat)
    assert(v.arch_alias and v.arch_alias.x86_64 == "amd64", plat .. " missing x86_64 arch_alias")
    for _, arch in ipairs(arches) do
        local h = assert(v.sha256 and v.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"),
               "invalid sha256 for " .. plat .. "/" .. arch)
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_install_config_uninstall_sandbox(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX pre-extracted binary beside archive
local files, execs, xvm_adds, xvm_removes = {}, {}, {}, {}
local install_file = "/tmp/cache/surreal-v4.0.1.linux-amd64.tgz"
local install_dir = "/tmp/xpkgs/surrealdb/4.0.1"
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
xvm = {
    add = function(name, opts) xvm_adds[name] = opts or {} end,
    remove = function(name) xvm_removes[#xvm_removes + 1] = name end,
}
pkginfo = {
    name = function() return "surrealdb" end,
    version = function() return "4.0.1" end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
}

files["/tmp/cache/surreal"] = true
assert(not installed())
assert(install())
assert(installed())
assert(files["/tmp/xpkgs/surrealdb/4.0.1/surreal"])
assert(#execs == 1 and execs[1]:find("chmod +x", 1, true))
assert(config())
assert(xvm_adds["surreal"] and xvm_adds["surreal"].bindir == install_dir and not xvm_adds["surreal"].alias)
assert(xvm_adds["surrealdb"] and xvm_adds["surrealdb"].type == "group")
assert(uninstall())
assert(#xvm_removes == 2)

-- Case 2: POSIX .tgz fallback when not pre-extracted
files, execs = {}, {}
files[install_file] = true
system.exec = function(cmd)
    execs[#execs + 1] = cmd
    if cmd:find("tar -xzf", 1, true) then
        files[install_dir .. "/surreal"] = true
    end
end
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2 and execs[1]:find("tar -xzf", 1, true) and execs[2]:find("chmod +x", 1, true))

-- Case 3: Windows raw .exe binary
files, execs, xvm_adds, xvm_removes = {}, {}, {}, {}
install_file = "C:/cache/surreal-v4.0.1.windows-amd64.exe"
install_dir = "C:/xpkgs/surrealdb/4.0.1"
files[install_file] = true
assert(not installed())
assert(install())
assert(installed())
assert(files[install_dir .. "/surreal.exe"])
assert(#execs == 0)
assert(config())
assert(xvm_adds["surreal"] and xvm_adds["surreal"].alias == "surreal.exe")
assert(xvm_adds["surrealdb"] and xvm_adds["surrealdb"].type == "group")
assert(uninstall())
assert(#xvm_removes == 2)
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
    def test_surreal_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "4.0.1")
        assert_command_output("surreal --version", contains=expected)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_surreal_validate(self):
        assert_command_output("echo 'SELECT * FROM user;' | surreal validate --stdin", contains="OK")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_surreal_and_group(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("surreal")
        assert_xvm_registered("surrealdb")
        bindir = Path(xlings_home()) / "subos" / os.environ["XLINGS_TEST_SUBOS"] / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / "default" / "bin"
        assert (bindir / "surreal").is_file(), f"missing surreal shim in {bindir}"
        assert not (bindir / "surrealdb").exists(), f"unexpected group shim surrealdb in {bindir}"
