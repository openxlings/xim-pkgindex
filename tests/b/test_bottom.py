"""Tests for the bottom package (`btm` CLI/TUI)."""
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
    assert_config_registers_package_name,
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

PKG = "bottom"
PKG_FILE = "pkgs/b/bottom.lua"
REPO_ROOT = Path(__file__).resolve().parents[2]


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
        cwd=REPO_ROOT,
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

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_package_registration(self, meta):
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_all_platforms_and_arches_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["btm"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "bottom")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "btm")
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/ClementTsang/bottom/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}

for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.deps == nil, plat .. " musl/static-CRT binaries need no runtime deps")
    assert(section.latest and section.latest.ref == "0.15.0")
    local ver = assert(section["0.15.0"], "missing 0.15.0 in " .. plat)
    assert(ver.arch_alias and ver.sha256)
    for _, arch in ipairs(arches) do
        assert(ver.arch_alias[arch] == arch, "unexpected alias for " .. plat .. "/" .. arch)
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        assert(tpl:find("${tag}", 1, true), "missing ${tag} in " .. tpl)
    end
end
assert(package.xpm.windows["0.15.0"].sha256.aarch64 == nil, "windows/aarch64 imports VCRUNTIME140.dll and is omitted")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_posix_tar_and_group_registration(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
system = {}
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files["/cache/bottom_x86_64-unknown-linux-musl.tar.gz"] = true

pkginfo = {
    name = function() return "bottom" end,
    version = function() return "0.15.0" end,
    install_file = function() return "/cache/bottom_x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/bottom/0.15.0" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function(p) dirs[p] = true end }
system.exec = function(cmd)
    table.insert(execs, cmd)
    if cmd:match("^'tar' ") then
        files["/xpkgs/bottom/0.15.0/btm"] = true
    end
end
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == "'tar' '-xzf' '/cache/bottom_x86_64-unknown-linux-musl.tar.gz' '-C' '/xpkgs/bottom/0.15.0'")
assert(execs[2] == "'chmod' '+x' '/xpkgs/bottom/0.15.0/btm'")
assert(installed())

files["/xpkgs/bottom/0.15.0/btm"] = nil
assert(not installed(), "accepted missing btm binary")
files["/xpkgs/bottom/0.15.0/btm"] = true

assert(config())
assert(#xvm_adds == 2)
assert(xvm_adds[1][1] == "btm" and xvm_adds[1][2].bindir == "/xpkgs/bottom/0.15.0")
assert(xvm_adds[2][1] == "bottom" and xvm_adds[2][2].type == "group")

assert(uninstall())
assert(#xvm_rms == 2)
assert(xvm_rms[1] == "btm" and xvm_rms[2] == "bottom")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_windows_zip_via_payload_module(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
system = {}
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "bottom" end,
    version = function() return "0.15.0" end,
    install_file = function() return "C:/cache/bottom_x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/bottom/0.15.0" end,
}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system.exec = function(cmd)
    table.insert(execs, cmd)
    files["C:/xpkgs/bottom/0.15.0/btm.exe"] = true
end

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\bottom_x86_64%-pc%-windows%-msvc%.zip" %-C "C:\\\\xpkgs\\\\bottom\\\\0%.15%.0"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 2)
assert(xvm_adds[1][1] == "btm" and xvm_adds[1][2].bindir == "C:/xpkgs/bottom/0.15.0")
assert(xvm_adds[2][1] == "bottom" and xvm_adds[2][2].type == "group")

assert(uninstall())
assert(#xvm_rms == 2)
assert(xvm_rms[1] == "btm" and xvm_rms[2] == "bottom")
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
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
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
    def _run_btm(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("btm" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        out = self._run_btm("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "0.15.0")
        assert f"bottom {expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help(self):
        out = self._run_btm("--help")
        assert "bottom" in out.lower() and "--version" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = Path(xlings_home()) / "subos"
            monkeypatch.setenv(
                "XLINGS_TEST_SUBOS",
                "current" if (subos / "current").is_dir() else "default",
            )
        assert_xvm_registered("btm")
        assert_xvm_registered("bottom")
