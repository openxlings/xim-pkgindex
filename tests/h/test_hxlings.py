"""hxlings"""
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
    assert_xim_add_succeeds, assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "hxlings"
PKG_FILE = "pkgs/h/hxlings.lua"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


def _latest():
    """the version the xpkg's `latest` points to (every platform must agree)"""
    with open(PKG_FILE, encoding="utf-8") as f:
        code = "\n".join(l for l in f.read().splitlines() if not l.lstrip().startswith("--"))
    refs = set(re.findall(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"\s*\}', code))
    assert len(refs) == 1, f"latest points to several versions: {sorted(refs)}"
    return refs.pop()


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
    def test_platforms_and_sha256_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local expected = {
    linux = "x86_64",
    macosx = "aarch64",
    windows = "x86_64",
}
for plat, arch in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == arg[2], plat .. " latest should be " .. arg[2])
    local entry = assert(p[ref] and p[ref][arch], "missing arch " .. arch .. " for " .. plat)
    assert(type(entry.url) == "string" and entry.url:find("FarnaHerry/Hxlings/releases/download/v" .. ref .. "/", 1, false))
    assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"))
end
''', PKG_FILE, _latest())

    @pytest.mark.static
    def test_installed_checks_platform_payload(self):
        _run_lua('''
import = function() end
dofile(arg[1])
pkginfo = { install_dir = function() return "/pkg" end }
local present = {}
os.isfile = function(p) return present[p] == true end
assert(not installed())

-- Windows payload
present["/pkg/hxlings.exe"] = true
assert(installed())
present = {}

-- POSIX payload requires both wrapper and bin/hxlings
present["/pkg/hxlings"] = true
assert(not installed())
present["/pkg/bin/hxlings"] = true
assert(installed())
''', PKG_FILE)

    @pytest.mark.static
    def test_install_moves_extracted_posix_and_windows_payloads(self):
        _run_lua('''
import = function() end
dofile(arg[1])

-- POSIX extracted directory move + chmod +x + elfpatch.set_interpreter
local files, dirs, moved, chmods, interps = {}, {}, {}, {}, {}
pkginfo = {
    install_file = function() return "/cache/hxlings-0.1.5-linux-x86_64.tar.gz" end,
    install_dir = function() return "/xpkgs/hxlings/0.1.5" end,
}
dirs["/cache/hxlings-0.1.5-linux-x86_64"] = true
fs = { mkdir_p = function() end }
elfpatch = { set_interpreter = function(elf, loader) table.insert(interps, {elf, loader}) end }
os.tryrm = function(p) dirs[p] = nil end
os.isdir = function(p) return dirs[p] == true end
os.isfile = function(p) return files[p] == true end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/hxlings"] = true
    files[dst .. "/bin/hxlings"] = true
    files[dst .. "/run.sh"] = true
    files[dst .. "/lib/ld-linux-x86-64.so.2"] = true
    files[dst .. "/lib/libc.so.6"] = true
end
system = { exec = function(cmd) table.insert(chmods, cmd) end }

assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/hxlings-0.1.5-linux-x86_64" and moved[1][2] == "/xpkgs/hxlings/0.1.5")
assert(#chmods == 3)
assert(#interps == 2)
assert(interps[1][1] == "/xpkgs/hxlings/0.1.5/bin/hxlings" and interps[1][2] == "/xpkgs/hxlings/0.1.5/lib/ld-linux-x86-64.so.2")
assert(interps[2][1] == "/xpkgs/hxlings/0.1.5/lib/libc.so.6" and interps[2][2] == "/xpkgs/hxlings/0.1.5/lib/ld-linux-x86-64.so.2")

-- Windows archive fallback when zip is not pre-extracted
files, dirs, moved = {}, {}, {}
local execs = {}
pkginfo = {
    install_file = function() return "C:\\\\cache\\\\hxlings-0.1.5-windows-x86_64.zip" end,
    install_dir = function() return "C:\\\\xpkgs\\\\hxlings\\\\0.1.5" end,
}
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        dirs["C:\\\\xpkgs\\\\hxlings\\\\0.1.5.staging/hxlings-0.1.5-windows-x86_64"] = true
    end,
}
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    files[dst .. "/hxlings.exe"] = true
end
assert(install())
assert(#execs == 1 and execs[1]:find("System32\\\\tar%.exe", 1, false))
assert(#moved == 1 and moved[1][2] == "C:\\\\xpkgs\\\\hxlings\\\\0.1.5")
''', PKG_FILE)

    @pytest.mark.static
    def test_config_and_start_menu_shortcut_only_without_desktop(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local mkdirs, execs, rms, xvm_adds, xvm_rms, warns, files = {}, {}, {}, {}, {}, {}, {}
pkginfo = {
    install_dir = function() return "C:/xlings/hxlings/0.1.5" end,
    version = function() return "0.1.5" end,
}
files["C:/xlings/hxlings/0.1.5/hxlings.exe"] = true
os.isfile = function(p) return files[p] == true end
os.getenv = function(k) return k == "APPDATA" and "C:\\\\Users\\\\O'Neil\\\\AppData\\\\Roaming" or nil end
fs = { mkdir_p = function(p) table.insert(mkdirs, p) end }
system = { exec = function(cmd) table.insert(execs, cmd) end }
os.tryrm = function(p) table.insert(rms, p) end
log = { warn = function(msg) table.insert(warns, msg) end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "hxlings" and xvm_adds[1][2].alias == "hxlings.exe")
assert(mkdirs[1] == "C:\\\\Users\\\\O'Neil\\\\AppData\\\\Roaming\\\\Microsoft\\\\Windows\\\\Start Menu\\\\Programs")
assert(#execs == 1)
assert(execs[1]:find("Start Menu\\\\Programs\\\\Hxlings%.lnk", 1, false))
assert(execs[1]:find("O''Neil", 1, false))
assert(not execs[1]:find("\\\\Desktop\\\\", 1, true))
assert(#warns == 0)

assert(uninstall())
assert(#rms == 1 and rms[1] == "C:\\\\Users\\\\O'Neil\\\\AppData\\\\Roaming\\\\Microsoft\\\\Windows\\\\Start Menu\\\\Programs\\\\Hxlings.lnk")
assert(not rms[1]:find("Desktop", 1, true))
assert(#xvm_rms == 1 and xvm_rms[1] == "hxlings")

-- Best-effort fallback: Start Menu failure must not abort config()
execs, warns, xvm_adds = {}, {}, {}
system.exec = function() error("access denied") end
assert(config())
assert(#xvm_adds == 1)
assert(#warns == 1)

-- POSIX config() does not invoke PowerShell
files, execs, xvm_adds = {}, {}, {}
os.getenv = function() return nil end
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][2].alias == nil)
assert(#execs == 0)
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
            "xim.libxpkg.elfpatch", "xim.libxpkg.fs", "xim.libxpkg.log",
            "xim.libxpkg.pkginfo", "xim.libxpkg.system", "xim.libxpkg.xvm",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestVerify:
    # hxlings is a GUI application with no CLI flags (see the xpkg header), so
    # the install is checked through its xvm registration, not by running it.
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("hxlings")
