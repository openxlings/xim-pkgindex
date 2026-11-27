"""Tests for the shfmt package."""
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

PKG = "shfmt"
PKG_FILE = "pkgs/s/shfmt.lua"
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
assert(package.spec == "3", "spec must be 3")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
local expected = {
    linux = {x86_64="amd64", aarch64="arm64"},
    macosx = {x86_64="amd64", aarch64="arm64"},
    windows = {x86_64="amd64"},
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        assert(entry.sha256[arch]:match("^[0-9a-f]+$") and #entry.sha256[arch] == 64, platform .. "/" .. arch)
        local auto = package.extensions.autoupdate.resources.GLOBAL.url[platform][arch]
        auto = auto:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(auto == resolved, "installer/updater URLs disagree for " .. platform .. "/" .. arch)
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
-- The hooks of spec "3" (design 2026-11-27 §9.6, §9.7): the host has placed
-- the downloaded file in install_dir under its own name before install()
-- runs; install() names it and makes it executable through the fs module.
local files = {}
local moves, chmods = {}, {}
local xvm_calls = {}
local cur = { file = "", dir = "", platform = "linux" }

local function join(...)
    return table.concat({...}, "/")
end
local mods = {
    ["xim.libxpkg.fs"] = function()
        fs = {
            is_file = function(p) return files[p] == true end,
            move = function(src, dst)
                assert(files[src], "missing src: " .. src)
                files[src] = nil
                files[dst] = true
                table.insert(moves, { src, dst })
            end,
            chmod = function(p, mode) table.insert(chmods, { p, mode }) end,
        }
    end,
    ["xim.libxpkg.path"] = function()
        path = { join = join, filename = function(p) return p:match("([^/\\]+)$") end }
    end,
    ["xim.libxpkg.pkginfo"] = function()
        pkginfo = {
            install_file = function() return cur.file end,
            install_dir = function() return cur.dir end,
            platform = function() return cur.platform end,
        }
    end,
    ["xim.libxpkg.xvm"] = function()
        xvm = {
            add = function(name, opts) table.insert(xvm_calls, {"add", name, opts}) end,
            remove = function(name) table.insert(xvm_calls, {"remove", name}) end,
        }
    end,
}

function import(name)
    assert(mods[name], "unexpected import: " .. name)()
end

assert(loadfile(arg[1]))()

-- Unix: the landed file becomes <dir>/shfmt, executable.
cur.file = "/tmp/dl/shfmt_v3.14.1_linux_amd64"
cur.dir = "/store/xpkgs/xim-x-shfmt/3.14.1"
cur.platform = "linux"
files[cur.dir .. "/shfmt_v3.14.1_linux_amd64"] = true
assert(installed() == false)
install()
assert(files[cur.dir .. "/shfmt"] == true and not files[cur.dir .. "/shfmt_v3.14.1_linux_amd64"])
assert(#chmods == 1 and chmods[1][1] == cur.dir .. "/shfmt" and chmods[1][2] == "+x")
assert(installed() == true)

-- Windows: shfmt.exe (fs.chmod does nothing there, by the module's contract).
files, moves, chmods = {}, {}, {}
cur.file = "C:\\dl\\shfmt_v3.14.1_windows_amd64.exe"
cur.dir = "C:\\store\\xpkgs\\xim-x-shfmt\\3.14.1"
cur.platform = "windows"
files[cur.dir .. "/shfmt_v3.14.1_windows_amd64.exe"] = true
assert(installed() == false)
install()
assert(files[cur.dir .. "/shfmt.exe"] == true)
assert(installed() == true)

-- config & uninstall
config()
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "shfmt" and xvm_calls[1][3].bindir == cur.dir)
uninstall()
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "shfmt")
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
        imports = set(re.findall(r'import\("([^"]+)"\)', src))
        assert imports <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.path",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
        }
        # `path` is libxpkg's module when the recipe imports it (spec "3");
        # otherwise it is the compatibility layer's global.
        if "xim.libxpkg.path" not in imports:
            assert not re.search(r'\bpath\.', src)
        assert not re.search(r'\b(?:is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "3.14.1")
        assert_command_output("shfmt --version", contains=expected)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("shfmt")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_formats_shell_script(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shfmt_bin = bindir / ("shfmt" + suffix)
        if not shfmt_bin.is_file():
            shfmt_bin = shutil.which("shfmt")
        assert shfmt_bin, "shfmt binary not found in subos bin or PATH"
        proc = subprocess.run(
            [str(shfmt_bin), "-i", "2", "-"],
            input="if [ -f foo ];then echo bar;fi\n",
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )
        assert proc.stdout == "if [ -f foo ]; then echo bar; fi\n"
