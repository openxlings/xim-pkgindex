"""Tests for the nushell package (`nu` CLI)."""
import os
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
    assert_valid_xvm_node_kinds,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "nushell"
PKG_FILE = "pkgs/n/nushell.lua"


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
    def test_platforms_arches_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["nu"]
        assert meta.has_xvm_enable is True
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "nushell")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/nushell/nushell/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "0.117.0")
    local ver = assert(section["0.117.0"], "missing 0.117.0 in " .. plat)
    assert(ver.sha256)
    for _, arch in ipairs(arches) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        assert(tpl:find("${tag}", 1, true) and tpl:find("${version}", 1, true), "missing ${tag}/${version} in " .. tpl)
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_posix_tarball_and_group_registration(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local stem = "nu-0.117.0-x86_64-unknown-linux-musl"
local extracted = "/cache/" .. stem
local idir = "/xpkgs/nushell/0.117.0"
dirs[extracted] = true
files[extracted .. "/nu"] = true
files[extracted .. "/nu_plugin_query"] = true
files[extracted .. "/LICENSE"] = true

pkginfo = {
    name = function() return "nushell" end,
    version = function() return "0.117.0" end,
    install_file = function() return "/cache/" .. stem .. ".tar.gz" end,
    install_dir = function() return idir end,
}
os.host = function() return "linux" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    dirs[dst] = true
    dirs[src] = nil
    local moved = {}
    for k, v in pairs(files) do
        if k:sub(1, #src + 1) == src .. "/" then
            moved[dst .. k:sub(#src + 1)] = v
        end
    end
    for k, v in pairs(moved) do files[k] = v end
end
log = { info = function() end }
fs = { mkdir_p = function(p) dirs[p] = true end }
system = {
    exec = function(cmd) table.insert(execs, cmd) end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'chmod +x "' .. idir .. '/nu"')
assert(execs[2] == 'chmod +x "' .. idir .. '/nu_plugin_query"')

files[idir .. "/nu"] = nil
assert(not installed(), "accepted missing nu binary")
files[idir .. "/nu"] = true
files[idir .. "/LICENSE"] = nil
assert(not installed(), "accepted missing LICENSE")
files[idir .. "/LICENSE"] = true

assert(config())
assert(#xvm_adds == 3)
assert(xvm_adds[1][1] == "nushell" and xvm_adds[1][2].type == "group")
assert(xvm_adds[2][1] == "nu" and xvm_adds[2][2].bindir == idir)
assert(xvm_adds[3][1] == "nu_plugin_query" and xvm_adds[3][2].bindir == idir and xvm_adds[3][2].binding == "nushell@0.117.0")

assert(uninstall())
assert(xvm_rms[#xvm_rms - 1] == "nu")
assert(xvm_rms[#xvm_rms] == "nushell")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_windows_flat_zip(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local idir = "C:/xpkgs/nushell/0.117.0"

pkginfo = {
    name = function() return "nushell" end,
    version = function() return "0.117.0" end,
    install_file = function() return "C:/cache/nu-0.117.0-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return idir end,
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
        files[idir .. "/nu.exe"] = true
        files[idir .. "/nu_plugin_query.exe"] = true
        files[idir .. "/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\nu%-0%.117%.0%-x86_64%-pc%-windows%-msvc%.zip" %-C "C:\\\\xpkgs\\\\nushell\\\\0%.117%.0"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 3)
assert(xvm_adds[1][1] == "nushell" and xvm_adds[1][2].type == "group")
assert(xvm_adds[2][1] == "nu" and xvm_adds[2][2].bindir == idir)
assert(xvm_adds[3][1] == "nu_plugin_query" and xvm_adds[3][2].bindir == idir and xvm_adds[3][2].binding == "nushell@0.117.0")

assert(uninstall())
assert(xvm_rms[#xvm_rms - 1] == "nu")
assert(xvm_rms[#xvm_rms] == "nushell")
''',
            PKG_FILE,
        )


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
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=300)


class TestVerify:
    def _run_nu(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("nu" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        out = self._run_nu("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "0.117.0")
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_eval_expression(self):
        out = self._run_nu("-c", "1 + 2")
        assert out.strip() == "3", out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("nu")
        assert_xvm_registered("nushell")
