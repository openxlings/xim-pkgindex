"""redis"""
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

PKG = "redis"
PKG_FILE = "pkgs/r/redis.lua"


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
    def test_windows_prebuilt_and_sha256_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.spec == "3")
assert(package.name == "redis")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(#package.archs == 1 and package.archs[1] == "x86_64")
local win = assert(package.xpm.windows)
assert(win.latest and win.latest.ref == "8.10.3")
local v = assert(win["8.10.3"] and win["8.10.3"].x86_64)
assert(type(v.url) == "string" and v.url == "https://github.com/redis-windows/redis-windows/releases/download/8.10.3/Redis-8.10.3-Windows-x64-msys2.zip")
assert(type(v.sha256) == "string" and #v.sha256 == 64 and v.sha256:match("^%x+$"))
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_install_config_and_uninstall_via_payload_module(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local required = {
    "redis-server.exe",
    "redis-cli.exe",
    "redis-benchmark.exe",
    "redis-check-aof.exe",
    "redis-check-rdb.exe",
    "redis-sentinel.exe",
    "redis.conf",
    "sentinel.conf",
}
local programs = {
    "redis-server",
    "redis-cli",
    "redis-benchmark",
    "redis-check-aof",
    "redis-check-rdb",
    "redis-sentinel",
}

pkginfo = {
    name = function() return "redis" end,
    version = function() return "8.10.3" end,
    install_file = function() return "C:/cache/Redis-8.10.3-Windows-x64-msys2.zip" end,
    install_dir = function() return "C:/xpkgs/redis/8.10.3" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        for _, rel in ipairs(required) do
            files["C:/xpkgs/redis/8.10.3/" .. rel] = true
        end
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\Redis%-8%.10%.3%-Windows%-x64%-msys2%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\redis\\\\8%.10%.3"$'))
assert(installed())

for _, rel in ipairs(required) do
    files["C:/xpkgs/redis/8.10.3/" .. rel] = nil
    assert(not installed(), "accepted missing " .. rel)
    files["C:/xpkgs/redis/8.10.3/" .. rel] = true
end

assert(config())
assert(#xvm_adds == #programs)
assert(xvm_adds[1][1] == "redis-server")
assert(xvm_adds[1][2].bindir == "C:/xpkgs/redis/8.10.3")
assert(xvm_adds[1][2].binding == nil)
for i = 2, #programs do
    assert(xvm_adds[i][1] == programs[i])
    assert(xvm_adds[i][2].bindir == "C:/xpkgs/redis/8.10.3")
    assert(xvm_adds[i][2].binding == "redis-server@8.10.3")
end

assert(uninstall())
assert(#xvm_rms == #programs)
for i = 1, #programs do
    assert(xvm_rms[i] == programs[#programs - i + 1])
end
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
            "xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)
