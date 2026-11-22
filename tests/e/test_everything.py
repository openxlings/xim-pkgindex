"""everything"""
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

PKG = "everything"
PKG_FILE = "pkgs/e/everything.lua"


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
    def test_windows_only_and_sha256_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
local win = assert(package.xpm.windows)
local ref = assert(win.latest and win.latest.ref)
local ver = assert(win[ref], "missing version " .. ref)
for _, arch in ipairs({"x86_64", "aarch64"}) do
    local entry = assert(ver[arch], "missing arch " .. arch)
    assert(type(entry.url) == "string" and entry.url:find("Everything%-" .. ref, 1, false))
    assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"))
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_and_arm64_normalization(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
dofile(arg[1])
local present, execs, moved = {}, {}, {}
pkginfo = {
    install_dir = function() return "C:/xpkgs/everything/1.4.1.1032" end,
    install_file = function() return "C:/cache/Everything-1.4.1.1032.ARM64.zip" end,
}
os.isfile = function(p) return present[p] == true end
os.tryrm = function() end
fs = { mkdir_p = function() end }
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    present[src] = nil
    present[dst] = true
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        present["C:/xpkgs/everything/1.4.1.1032/EverythingARM64.exe"] = true
        present["C:/xpkgs/everything/1.4.1.1032/Everything.lng"] = true
    end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][2] == "C:/xpkgs/everything/1.4.1.1032/everything.exe")
assert(installed())
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\Everything%-1%.4%.1%.1032%.ARM64%.zip" %-C "C:\\\\xpkgs\\\\everything\\\\1%.4%.1%.1032"$'))
''', PKG_FILE)

    @pytest.mark.static
    def test_start_menu_shortcut_only_without_desktop(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
shortcut = assert(loadfile("libs/shortcut.lua"))()
dofile(arg[1])
local mkdirs, execs, rms, xvm_adds, xvm_rms, warns, present = {}, {}, {}, {}, {}, {}, {}
pkginfo = {
    install_dir = function() return "C:/xpkgs/everything/1.4.1.1032" end,
    name = function() return "everything" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "APPDATA" and "C:\\\\Users\\\\alice\\\\AppData\\\\Roaming" or nil end
os.isfile = function(p) return present[p] == true end
fs = { mkdir_p = function(p) table.insert(mkdirs, p) end }
system = { exec = function(cmd)
    table.insert(execs, cmd)
    local q = string.char(39)
    local _, b = cmd:find("CreateShortcut(", 1, true)
    local v = cmd:sub(b + 2)
    local e = v:find(q .. ");", 1, true)
    present[(v:sub(1, e - 1)):gsub(q .. q, q)] = true
end }
os.tryrm = function(p)
    table.insert(rms, p)
    present[p] = nil
end
log = { warn = function(msg) table.insert(warns, msg) end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "everything")
assert(execs[1]:find("Start Menu\\\\Programs\\\\Everything%.lnk", 1, false))
assert(not execs[1]:find("Desktop", 1, true))
assert(#warns == 0)

assert(uninstall())
assert(#rms == 1 and rms[1] == "C:\\\\Users\\\\alice\\\\AppData\\\\Roaming\\\\Microsoft\\\\Windows\\\\Start Menu\\\\Programs\\\\Everything.lnk")
assert(not rms[1]:find("Desktop", 1, true))
assert(#xvm_rms == 1 and xvm_rms[1] == "everything")
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
