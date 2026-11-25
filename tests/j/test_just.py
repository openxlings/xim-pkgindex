"""Tests for the just package."""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_config_registers_package_name,
    assert_valid_xvm_node_kinds,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_command_output,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "just"
PKG_FILE = "pkgs/j/just.lua"
VERSION = "1.59.0"
REPO = Path(__file__).resolve().parents[2]


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
        cwd=REPO,
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
    def test_platforms_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and package.programs[1] == "just" and #package.programs == 1)

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/casey/just/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)

local count = 0
for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.deps == nil, plat .. " uses static binaries and needs no runtime deps")
    assert(p.latest and p.latest.ref == ver, plat .. " latest must ref " .. ver)
    local v = assert(p[ver], "missing version entry on " .. plat)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local entry = assert(v[arch], "missing " .. plat .. "/" .. arch)
        assert(type(entry.url) == "string" and entry.url:find("/" .. ver .. "/", 1, true))
        assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"))
        local auto_url = assert(auto.resources.GLOBAL.url[plat][arch])
        local resolved = auto_url:gsub("%${tag}", ver):gsub("%${version}", ver)
        assert(resolved == entry.url, "autoupdate URL disagrees for " .. plat .. "/" .. arch)
        count = count + 1
    end
end
assert(count == 6)
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_hooks_posix_and_windows_sandbox(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

-- Case 1: POSIX (.tar.gz extracted directly into install_dir)
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
local host = "linux"
local install_file = "/cache/just-1.59.0-x86_64-unknown-linux-musl.tar.gz"
local install_dir = "/xpkgs/just/1.59.0"
os.host = function() return host end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil; files[p .. "/just"] = nil; files[p .. "/just.exe"] = nil end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("tar", 1, true) then
            files[install_dir .. "/just"] = true
        end
    end,
}
pkginfo = {
    name = function() return "just" end,
    version = function() return "1.59.0" end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == "'tar' '-xzf' '/cache/just-1.59.0-x86_64-unknown-linux-musl.tar.gz' '-C' '/xpkgs/just/1.59.0'")
assert(execs[2] == "'chmod' '+x' '/xpkgs/just/1.59.0/just'")
assert(config())
assert(#adds == 1 and adds[1][1] == "just" and adds[1][2].bindir == "/xpkgs/just/1.59.0")
assert(uninstall())
assert(#rms == 1 and rms[1] == "just")

-- Case 2: Windows (.zip unpacked via libs/payload.lua -> System32\\tar.exe)
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
host = "windows"
install_file = "C:/cache/just-1.59.0-x86_64-pc-windows-msvc.zip"
install_dir = "C:/xpkgs/just/1.59.0"
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
system.exec = function(cmd)
    table.insert(execs, cmd)
    files["C:/xpkgs/just/1.59.0/just.exe"] = true
end

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\just-1.59.0-x86_64-pc-windows-msvc.zip" -C "C:\\\\xpkgs\\\\just\\\\1.59.0"')
assert(config())
assert(#adds == 1 and adds[1][1] == "just" and adds[1][2].bindir == "C:/xpkgs/just/1.59.0")
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
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
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
    def test_just_version(self):
        assert_command_output("just --version", contains=f"just {VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("just")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_just_runs_recipe(self, tmp_path):
        justfile = tmp_path / "justfile"
        justfile.write_text('greet name="world":\n    @echo "hello {{name}}"\n', encoding="utf-8")
        assert_command_output(
            f'just --justfile "{justfile}" greet xlings',
            contains="hello xlings",
        )
