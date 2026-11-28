"""mysql"""
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
    assert_xim_add_succeeds,
)

PKG = "mysql"
PKG_FILE = "pkgs/m/mysql.lua"


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
        assert set(meta.platforms.keys()) == {"macosx", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
local expected = {
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
local aliases = {
    ["9.7"] = "9.7.4",
    ["8.4"] = "8.4.11",
    ["8.0"] = "8.0.46",
}
local versions = {"9.7.4", "8.4.11", "8.0.46"}
local win = assert(package.xpm.windows)
assert(win.deps and win.deps.runtime and win.deps.runtime[1] == "xim:vcruntime",
       "windows must depend on xim:vcruntime")
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "9.7.4", plat .. " latest must ref 9.7.4")
    for branch, target in pairs(aliases) do
        assert(p[branch] and p[branch].ref == target,
               plat .. " alias " .. branch .. " must ref " .. target)
    end
    for _, ver in ipairs(versions) do
        local v = assert(p[ver], "missing " .. ver .. " on " .. plat)
        local series = ver:match("^(%d+%.%d+)%.")
        local esc_ver = ver:gsub("%.", "%%.")
        for _, arch in ipairs(arches) do
            local r = assert(v[arch], "missing " .. ver .. " " .. plat .. "/" .. arch)
            assert(type(r.url) == "string", "missing url")
            assert(r.url:match("^https://cdn%.mysql%.com/Downloads/MySQL%-" .. series .. "/mysql%-" .. esc_ver),
                   "unexpected url format: " .. r.url)
            if plat == "macosx" then
                local mac_arch = (arch == "aarch64") and "arm64" or "x86_64"
                assert(r.url:match("%-macos15%-" .. mac_arch .. "%.tar%.gz$"),
                       "unexpected macOS tarball suffix: " .. r.url)
            else
                assert(r.url:match("%-winx64%.zip$"),
                       "unexpected Windows archive suffix: " .. r.url)
            end
            assert(type(r.sha256) == "string" and #r.sha256 == 64 and r.sha256:match("^%x+$"),
                   "invalid sha256 for " .. ver .. " " .. plat .. "/" .. arch)
        end
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_and_windows_vcruntime_copy(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local progs = {
    "mysql", "mysqld", "mysqladmin", "mysqldump",
    "mysqlcheck", "mysqlimport", "mysqlshow", "mysqlbinlog",
}
local files, dirs, copied = {}, {}, {}
pkginfo = {
    name = function() return "mysql" end,
    install_dir = function() return "C:/xpkgs/mysql/9.7.4" end,
    install_file = function() return "C:/cache/mysql-9.7.4-winx64.zip" end,
    dep_install_dir = function(dep)
        assert(dep == "xim:vcruntime")
        return "C:/xpkgs/vcruntime/14.44.35211"
    end,
}
dirs["C:/cache/mysql-9.7.4-winx64"] = true
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = {
    mkdir_p = function() end,
    files = function(d)
        assert(d == "C:/xpkgs/vcruntime/14.44.35211/bin")
        return { d .. "/crt_a.dll", d .. "/crt_b.dll" }
    end,
}
os.mv = function(src, dst)
    dirs[src] = nil
    dirs[dst] = true
    for _, p in ipairs(progs) do
        files[dst .. "/bin/" .. p .. ".exe"] = true
    end
end
os.cp = function(src, dst)
    table.insert(copied, {src, dst})
end

assert(not installed())
assert(install())
assert(installed())
assert(#copied == 2)
assert(copied[1][2] == "C:/xpkgs/mysql/9.7.4/bin")

-- Missing any one program must fail installed()
files["C:/xpkgs/mysql/9.7.4/bin/mysqlbinlog.exe"] = nil
assert(not installed())
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
            "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)
