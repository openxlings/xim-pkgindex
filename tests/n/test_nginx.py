"""nginx"""
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

PKG = "nginx"
PKG_FILE = "pkgs/n/nginx.lua"


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
    def test_windows_official_stable_and_sha256_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
local win = assert(package.xpm.windows)
assert(win.latest and win.latest.ref == "1.30.7")
assert(win["1.30"] and win["1.30"].ref == "1.30.7")
local v = assert(win["1.30.7"] and win["1.30.7"].x86_64)
assert(type(v.url) == "string" and v.url == "https://nginx.org/download/nginx-1.30.7.zip")
assert(type(v.sha256) == "string" and #v.sha256 == 64 and v.sha256:match("^%x+$"))
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_and_install_via_payload_module(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local required = {
    "nginx.exe", "conf/nginx.conf", "conf/mime.types", "html/index.html",
}

pkginfo = {
    name = function() return "nginx" end,
    version = function() return "1.30.7" end,
    install_file = function() return "C:/cache/nginx-1.30.7.zip" end,
    install_dir = function() return "C:/xpkgs/nginx/1.30.7" end,
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
            files["C:/xpkgs/nginx/1.30.7/" .. rel] = true
        end
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\nginx%-1%.30%.7%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\nginx\\\\1%.30%.7"$'))
assert(installed())

for _, rel in ipairs(required) do
    files["C:/xpkgs/nginx/1.30.7/" .. rel] = nil
    assert(not installed(), "accepted missing " .. rel)
    files["C:/xpkgs/nginx/1.30.7/" .. rel] = true
end

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "nginx" and xvm_adds[1][2].bindir == "C:/xpkgs/nginx/1.30.7")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "nginx")
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
