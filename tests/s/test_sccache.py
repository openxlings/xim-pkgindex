"""Tests for the sccache package."""
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

PKG = "sccache"
PKG_FILE = "pkgs/s/sccache.lua"


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
        assert meta.spec == "2"

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
assert(package.programs and #package.programs == 1 and package.programs[1] == "sccache")

local expected_assets = {
    linux = {
        x86_64  = "sccache-v0.20.1-x86_64-unknown-linux-musl.tar.gz",
        aarch64 = "sccache-v0.20.1-aarch64-unknown-linux-musl.tar.gz",
    },
    macosx = {
        x86_64  = "sccache-v0.20.1-x86_64-apple-darwin.tar.gz",
        aarch64 = "sccache-v0.20.1-aarch64-apple-darwin.tar.gz",
    },
    windows = {
        x86_64  = "sccache-v0.20.1-x86_64-pc-windows-msvc.zip",
        aarch64 = "sccache-v0.20.1-aarch64-pc-windows-msvc.zip",
    },
}

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/mozilla/sccache/releases")
local global_au = assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.url)
assert(au.resources.GLOBAL.required == true)

for plat, arches in pairs(expected_assets) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == "0.20.1", plat .. " latest should be 0.20.1")
    for arch, asset in pairs(arches) do
        local entry = assert(p[ref] and p[ref][arch], "missing arch " .. arch .. " for " .. plat)
        local expected_url = "https://github.com/mozilla/sccache/releases/download/v0.20.1/" .. asset
        assert(entry.url == expected_url, plat .. "/" .. arch .. " url mismatch: " .. tostring(entry.url))
        assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"),
               plat .. "/" .. arch .. " invalid sha256")
        local tmpl = assert(global_au[plat] and global_au[plat][arch],
                            "missing autoupdate template for " .. plat .. "/" .. arch)
        local expanded = tmpl:gsub("${tag}", "v0.20.1"):gsub("${version}", "0.20.1")
        assert(expanded == expected_url,
               "autoupdate template mismatch for " .. plat .. "/" .. arch)
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_and_install_hooks(self):
        _run_lua('''
import = function() end
dofile(arg[1])

-- Stub payload module (as when local overlay lacks libs/)
payload = setmetatable({}, { __call = function() return {} end })
pkginfo = {
    install_file = function() return "/cache/sccache-v0.20.1-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/sccache/0.20.1" end,
}

local dirs, files, chmods = {}, {}, {}
dirs["/cache/sccache-v0.20.1-x86_64-unknown-linux-musl"] = true
fs = { mkdir_p = function() end }
os.tryrm = function() end
os.isdir = function(p) return dirs[p] == true end
os.isfile = function(p) return files[p] == true end
os.mv = function(src, dst)
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/sccache"] = true
end
system = { exec = function(cmd) table.insert(chmods, cmd) end }

assert(not installed())
assert(install())
assert(installed())
assert(#chmods == 1 and chmods[1]:find("chmod %+x"))

-- Real payload module branch
local unpack_opts, required_list
payload = {
    present = function(list)
        for _, f in ipairs(list) do
            if not files["/xpkgs/sccache/0.20.1/" .. f] then return false end
        end
        return true
    end,
    unpack = function(opt) unpack_opts = opt end,
    require = function(list) required_list = list end,
}
assert(install())
assert(unpack_opts.extracted == "sccache-v0.20.1-x86_64-unknown-linux-musl")
assert(unpack_opts.strip == 1)
assert(#required_list == 1 and required_list[1] == "sccache")

-- Missing extracted dir under stub branch must fail
payload = {}
dirs = {}
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when extracted directory is missing")
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
assert(#adds == 1 and adds[1][1] == "sccache" and adds[1][2].bindir == "/pkg")

assert(uninstall())
assert(#rms == 1 and rms[1] == "sccache")
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
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
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
    def test_version(self):
        assert_command_output("sccache --version", contains="sccache 0.20.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("sccache")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help(self):
        assert_command_output("sccache --help", contains="sccache")
