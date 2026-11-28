"""Tests for the websocat package."""
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
    assert_platform_supported,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_command_output,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "websocat"
PKG_FILE = "pkgs/w/websocat.lua"
REPO_ROOT = Path(__file__).resolve().parents[2]


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
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping(self):
        lua = shutil.which("lua5.4") or shutil.which("lua")
        assert lua, "Lua is required to evaluate the resource matrix"
        source = r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
local expected = {
    linux = { x86_64 = true, aarch64 = true },
    macosx = { x86_64 = true, aarch64 = true },
    windows = { x86_64 = true },
}
local count = 0
local seen_filenames = {}
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    for arch in pairs(arches) do
        local sum = assert(entry.sha256[arch], platform .. "/" .. arch)
        assert(sum:match("^[0-9a-f]+$") and #sum == 64, platform .. "/" .. arch)
        local auto = package.extensions.autoupdate.resources.GLOBAL.url[platform][arch]
        local auto_expanded = auto:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local resolved = p.source:gsub("%${version}", version):gsub("%${arch}", arch)
        assert(auto_expanded == resolved, "installer/updater URLs disagree for " .. platform .. "/" .. arch)
        local filename = resolved:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unexpected arch: " .. arch) end
end
assert(count == 5)
'''
        subprocess.run(
            [lua, "-", PKG_FILE],
            input=source,
            text=True,
            check=True,
            cwd=REPO_ROOT,
            capture_output=True,
        )

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        lua = shutil.which("lua5.4") or shutil.which("lua")
        assert lua, "Lua is required to evaluate recipe hooks"
        source = r'''
local files = {}
local execs = {}
local xvm_calls = {}
local cur_install_file = ""
local cur_install_dir = ""

local mods = {
    ["xim.libxpkg.pkginfo"] = function()
        pkginfo = {
            install_file = function() return cur_install_file end,
            install_dir = function() return cur_install_dir end,
        }
    end,
    ["xim.libxpkg.xvm"] = function()
        xvm = {
            add = function(name, opts) table.insert(xvm_calls, {"add", name, opts}) end,
            remove = function(name) table.insert(xvm_calls, {"remove", name}) end,
        }
    end,
    ["xim.libxpkg.system"] = function()
        system = {
            exec = function(cmd) table.insert(execs, cmd) end,
        }
    end,
}

function import(name)
    assert(mods[name], "unexpected import: " .. name)()
end

os.isfile = function(p) return files[p] == true end
os.tryrm = function(d)
    for k in pairs(files) do
        if k:sub(1, #d) == d then files[k] = nil end
    end
end
os.mkdir = function(d) end
os.mv = function(src, dst)
    assert(files[src], "missing src: " .. src)
    files[src] = nil
    files[dst] = true
end

assert(loadfile(arg[1]))()

-- Unix case
cur_install_file = "/tmp/dl/websocat.x86_64-unknown-linux-musl"
cur_install_dir = "/store/xpkgs/xim-x-websocat/1.14.2"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(files["/store/xpkgs/xim-x-websocat/1.14.2/websocat"] == true)
assert(#execs == 1 and execs[1]:match('chmod %+x "/store/xpkgs/xim%-x%-websocat/1%.14%.2/websocat"'))
assert(installed() == true)

-- Windows case
files = {}
execs = {}
cur_install_file = "C:\\dl\\websocat.x86_64-pc-windows-gnu.exe"
cur_install_dir = "C:\\store\\xpkgs\\xim-x-websocat\\1.14.2"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(files["C:\\store\\xpkgs\\xim-x-websocat\\1.14.2/websocat.exe"] == true)
assert(#execs == 0, "must not run chmod on Windows")
assert(installed() == true)

-- config & uninstall
assert(config() == true)
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "websocat" and xvm_calls[1][3].bindir == cur_install_dir)
assert(uninstall() == true)
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "websocat")
'''
        subprocess.run(
            [lua, "-", PKG_FILE],
            input=source,
            text=True,
            check=True,
            cwd=REPO_ROOT,
            capture_output=True,
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
    def test_portable_lua_and_libxpkg_only(self):
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.libxpkg.system",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "1.14.2")
        assert_command_output("websocat --version", contains=expected)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("websocat")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_literal_output(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        ws_bin = bindir / ("websocat" + suffix)
        if not ws_bin.is_file():
            ws_bin = shutil.which("websocat")
        assert ws_bin, "websocat binary not found in subos bin or PATH"
        proc = subprocess.run(
            [str(ws_bin), "-u", "literal:websocat-ok", "-"],
            input="",
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )
        assert "websocat-ok" in proc.stdout
