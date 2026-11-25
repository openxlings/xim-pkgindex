"""winscp"""
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

PKG = "winscp"
PKG_FILE = "pkgs/w/winscp.lua"


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
    def test_windows_only(self, meta):
        assert set(meta.platforms.keys()) == {"windows"}
        assert 'archs = {"x86_64"}' in meta.raw_content

    @pytest.mark.static
    def test_sha256_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local win = assert(package.xpm.windows)
local ref = assert(win.latest and win.latest.ref)
local entry = assert(win[ref] and win[ref].x86_64)
assert(type(entry.url) == "string" and entry.url:find("WinSCP%-" .. ref .. "%-Portable%.zip", 1, false))
assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"))
''', PKG_FILE)

    @pytest.mark.static
    def test_declares_extractor(self, meta):
        assert "xim:7zip" in meta.raw_content

    @pytest.mark.static
    def test_installed_rejects_incomplete_payload(self):
        _run_lua('''
import = function() end
dofile(arg[1])
pkginfo = { install_dir = function() return "/pkg" end }
local present = {}
os.isfile = function(p) return present[p] == true end
assert(not installed())
present["/pkg/WinSCP.exe"] = true
assert(not installed())
present["/pkg/WinSCP.com"] = true
assert(installed())
present["/pkg/WinSCP.exe"] = nil
assert(not installed())
''', PKG_FILE)

    @pytest.mark.static
    def test_start_menu_shortcut_only_without_desktop(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
shortcut = assert(loadfile("libs/shortcut.lua"))()
dofile(arg[1])
local mkdirs, execs, rms, xvm_adds, xvm_rms, warns = {}, {}, {}, {}, {}, {}
pkginfo = {
    install_dir = function() return "C:/xlings/winscp/6.7.1" end,
    version = function() return "6.7.1" end,
    name = function() return "winscp" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "APPDATA" and "C:\\\\Users\\\\O'Neil\\\\AppData\\\\Roaming" or nil end
local present = {}
os.isfile = function(p) return present[p] == true end
fs = { mkdir_p = function(p) table.insert(mkdirs, p) end }
-- The entry PowerShell would have written is the first single-quoted value;
-- marking it present is what lets the module's own wrote-check stay quiet.
system = { exec = function(cmd)
    table.insert(execs, cmd)
    local q = string.char(39)
    local _, b = cmd:find("CreateShortcut(", 1, true)
    local v = cmd:sub(b + 2)
    local e = v:find(q .. ");", 1, true)
    present[(v:sub(1, e - 1)):gsub(q .. q, q)] = true
end }
os.tryrm = function(p) table.insert(rms, p) end
log = { warn = function(msg) table.insert(warns, msg) end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(config())
assert(#xvm_adds == 2)
assert(mkdirs[1] == "C:\\\\Users\\\\O'Neil\\\\AppData\\\\Roaming\\\\Microsoft\\\\Windows\\\\Start Menu\\\\Programs")
assert(#execs == 1)
assert(execs[1]:find("Start Menu\\\\Programs\\\\WinSCP%.lnk", 1, false))
assert(execs[1]:find("O''Neil", 1, false))
assert(not execs[1]:find("Desktop", 1, true))
assert(#warns == 0)

assert(uninstall())
assert(#rms == 1 and rms[1] == "C:\\\\Users\\\\O'Neil\\\\AppData\\\\Roaming\\\\Microsoft\\\\Windows\\\\Start Menu\\\\Programs\\\\WinSCP.lnk")
assert(not rms[1]:find("Desktop", 1, true))
assert(#xvm_rms == 2)

-- Best-effort fallback: Start Menu failure must not abort config()
execs, warns, xvm_adds = {}, {}, {}
system.exec = function() error("access denied") end
assert(config())
assert(#xvm_adds == 2)
assert(#warns == 1)
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
            "xim.pkgindex.shortcut", "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)
