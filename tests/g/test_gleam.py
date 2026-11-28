"""gleam"""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_valid_xvm_node_kinds,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "gleam"
PKG_FILE = "pkgs/g/gleam.lua"


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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_platforms_archs_sha256_and_autoupdate_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])

assert(package.spec == "2", "spec must be 2")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "gleam")

local expected_assets = {
    linux = {
        x86_64  = "gleam-v1.19.2-x86_64-unknown-linux-musl.tar.gz",
        aarch64 = "gleam-v1.19.2-aarch64-unknown-linux-musl.tar.gz",
    },
    macosx = {
        x86_64  = "gleam-v1.19.2-x86_64-apple-darwin.tar.gz",
        aarch64 = "gleam-v1.19.2-aarch64-apple-darwin.tar.gz",
    },
    windows = {
        x86_64  = "gleam-v1.19.2-x86_64-pc-windows-msvc.zip",
        aarch64 = "gleam-v1.19.2-aarch64-pc-windows-msvc.zip",
    },
}

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/gleam-lang/gleam/releases")
local global_au = assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.url)
assert(au.resources.GLOBAL.required == true)

for plat, arches in pairs(expected_assets) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.deps == nil, plat .. " should have no runtime deps")
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == "1.19.2", plat .. " latest should be 1.19.2")
    for arch, asset in pairs(arches) do
        local entry = assert(p[ref] and p[ref][arch], "missing arch " .. arch .. " for " .. plat)
        local expected_url = "https://github.com/gleam-lang/gleam/releases/download/v1.19.2/" .. asset
        assert(entry.url == expected_url, plat .. "/" .. arch .. " url mismatch: " .. tostring(entry.url))
        assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"),
               plat .. "/" .. arch .. " invalid sha256")
        local tmpl = assert(global_au[plat] and global_au[plat][arch],
                            "missing autoupdate template for " .. plat .. "/" .. arch)
        local resolved = tmpl:gsub("${tag}", "v1.19.2"):gsub("${version}", "1.19.2")
        assert(resolved == expected_url,
               "autoupdate template mismatch for " .. plat .. "/" .. arch .. ": " .. resolved)
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_checks_binary(self):
        _run_lua('''
import = function() end
dofile(arg[1])
pkginfo = { install_dir = function() return "/pkg" end }
local present = {}
os.isfile = function(p) return present[p] == true end

assert(not installed())
present["/pkg/gleam"] = true
assert(installed())

present = {}
present["/pkg/gleam.exe"] = true
assert(installed())
''', PKG_FILE)

    @pytest.mark.static
    def test_install_extracts_posix_windows_and_preextracted(self):
        _run_lua('''
import = function() end
dofile(arg[1])
winpath = { native = function(p) return (tostring(p):gsub("/", "\\\\")) end }

-- 1. POSIX archive extracted directly into install_dir + chmod +x
local files, execs, moved = {}, {}, {}
pkginfo = {
    install_file = function() return "/cache/gleam-v1.19.2-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/gleam/1.19.2" end,
}
files["/cache/gleam-v1.19.2-x86_64-unknown-linux-musl.tar.gz"] = true
fs = { mkdir_p = function() end }
os.tryrm = function() end
os.isfile = function(p) return files[p] == true end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    files[src] = nil
    files[dst] = true
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^tar %-xzf") then
            files["/xpkgs/gleam/1.19.2/gleam"] = true
        end
    end,
}

assert(install())
assert(#execs == 2)
assert(execs[1]:find("^tar %-xzf"))
assert(execs[2]:find("chmod %+x"))
assert(installed())

-- 2. Windows zip extracted via System32\\tar.exe directly into install_dir
files, execs, moved = {}, {}, {}
pkginfo = {
    install_file = function() return "C:\\\\cache\\\\gleam-v1.19.2-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:\\\\xpkgs\\\\gleam\\\\1.19.2" end,
}
files["C:\\\\cache\\\\gleam-v1.19.2-x86_64-pc-windows-msvc.zip"] = true
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:\\\\xpkgs\\\\gleam\\\\1.19.2/gleam.exe"] = true
    end,
}
assert(install())
assert(#execs == 1 and execs[1]:find("System32\\\\tar%.exe", 1, false))
assert(installed())

-- 3. Pre-extracted binary fallback when archive is absent
files, execs, moved = {}, {}, {}
files["C:/cache/gleam.exe"] = true
assert(install())
assert(#execs == 0)
assert(#moved == 1 and moved[1][1] == "C:/cache/gleam.exe" and moved[1][2] == "C:\\\\xpkgs\\\\gleam\\\\1.19.2/gleam.exe")

-- 4. Missing both archive and pre-extracted binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
''', PKG_FILE)

    @pytest.mark.static
    def test_config_and_uninstall(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local adds, rms = {}, {}
pkginfo = { install_dir = function() return "/pkg" end }
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(config())
assert(#adds == 1 and adds[1][1] == "gleam" and adds[1][2].bindir == "/pkg")

assert(uninstall())
assert(#rms == 1 and rms[1] == "gleam")
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
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
            "xim.libxpkg.system", "xim.libxpkg.xvm",
            "xim.pkgindex.winpath",
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
    def test_version(self):
        assert_command_output("gleam --version", contains="gleam 1.19.2")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("gleam")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_format_stdin(self):
        proc = subprocess.run(
            ["bash", "-l", "-c", "gleam format --stdin"],
            input="pub fn main() { 1 + 2 }\n",
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert "pub fn main() {\n  1 + 2\n}" in proc.stdout
