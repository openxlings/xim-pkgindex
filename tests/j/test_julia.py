"""Tests for the julia package (official JuliaLang prebuilt binaries)."""
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
    assert_no_direct_pkg_manager, assert_xim_add_succeeds,
    assert_install_succeeds, assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "julia"
PKG_FILE = "pkgs/j/julia.lua"
VERSION = "1.13.4"


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
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and package.programs[1] == "julia")
assert(not (package.extensions and package.extensions.autoupdate),
       "julia uses <major>.<minor> URL paths not expressible in autoupdate")

local linux = assert(package.xpm.linux)
assert(not linux.deps, "julia carries its own libs via $ORIGIN and declares no xim:glibc")

local expected_arches = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
for plat, arches in pairs(expected_arches) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "1.13.4", plat .. " latest must ref 1.13.4")
    assert(type(p.source) == "string" and p.source:match("^https://julialang%-s3%.julialang%.org/"),
           plat .. " source must point to julialang-s3")
    local v = assert(p["1.13.4"], "missing 1.13.4 on " .. plat)
    for _, arch in ipairs(arches) do
        local h = assert(v.sha256 and v.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"),
               "invalid sha256 for " .. plat .. "/" .. arch)
    end
end
assert(not package.xpm.windows["1.13.4"].sha256.aarch64,
       "upstream publishes no windows aarch64 archive")
''', PKG_FILE)

    @pytest.mark.static
    def test_install_posix_and_windows_zip_sandbox(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: Linux/macOS pre-extracted julia-<version>/ directory
local files, dirs, execs, xvm_adds = {}, {}, {}, {}
local host = "linux"
local install_file = "/tmp/cache/julia-1.13.4-linux-x86_64.tar.gz"
local install_dir = "/tmp/xpkgs/julia/1.13.4"
os.host = function() return host end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/bin/julia"] = true
    files[dst .. "/etc/julia/startup.jl"] = true
    files[dst .. "/share/julia/base.cache"] = true
end
fs = { mkdir_p = function() end }
log = { info = function() end }
system = { exec = function(cmd) execs[#execs + 1] = cmd end }
xvm = {
    add = function(name, cfg) xvm_adds[#xvm_adds + 1] = { name = name, cfg = cfg } end,
    remove = function() end,
}
pkginfo = {
    name = function() return "julia" end,
    version = function() return "1.13.4" end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
}

dirs["/tmp/cache/julia-1.13.4"] = true
assert(not installed())
assert(install())
assert(installed())
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1].name == "julia")
assert(xvm_adds[1].cfg.bindir == "/tmp/xpkgs/julia/1.13.4/bin")
assert(xvm_adds[1].cfg.alias == nil)

-- Case 2: Windows .zip not pre-extracted -> System32 tar.exe with --strip-components=1
files, dirs, execs, xvm_adds = {}, {}, {}, {}
host = "windows"
install_file = "C:/cache/julia-1.13.4-win64.zip"
install_dir = "C:/xpkgs/julia/1.13.4"
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system.exec = function(cmd)
    execs[#execs + 1] = cmd
    files["C:/xpkgs/julia/1.13.4/bin/julia.exe"] = true
    files["C:/xpkgs/julia/1.13.4/etc/julia/startup.jl"] = true
    files["C:/xpkgs/julia/1.13.4/share/julia/base.cache"] = true
end
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1 and execs[1]:find("System32\\\\tar.exe", 1, true))
assert(execs[1]:find("--strip-components=1", 1, true))
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1].cfg.alias == "julia.exe")
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
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_lua_and_libxpkg_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_julia_version(self):
        assert_command_output("julia --version", contains=f"julia version {VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_julia_eval(self):
        assert_command_output("julia -e 'println(1 + 1)'", contains="2")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_julia(self):
        assert_xvm_registered("julia")
