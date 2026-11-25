"""Tests for the yq package."""
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

PKG = "yq"
PKG_FILE = "pkgs/y/yq.lua"
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
    linux = {x86_64="amd64", aarch64="arm64"},
    macosx = {x86_64="amd64", aarch64="arm64"},
    windows = {x86_64="amd64", aarch64="arm64"},
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
        local resolved = p.source:gsub("%${arch_alias}", alias)
        assert(auto == resolved, "installer/updater URLs disagree for " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unexpected arch: " .. arch) end
end
assert(count == 6)
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
cur_install_file = "/tmp/dl/yq_linux_amd64"
cur_install_dir = "/store/xpkgs/xim-x-yq/4.54.3"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(files["/store/xpkgs/xim-x-yq/4.54.3/yq"] == true)
assert(#execs == 1 and execs[1]:match('chmod %+x "/store/xpkgs/xim%-x%-yq/4%.54%.3/yq"'))
assert(installed() == true)

-- Windows case
files = {}
execs = {}
cur_install_file = "C:\\dl\\yq_windows_amd64.exe"
cur_install_dir = "C:\\store\\xpkgs\\xim-x-yq\\4.54.3"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(files["C:\\store\\xpkgs\\xim-x-yq\\4.54.3/yq.exe"] == true)
assert(#execs == 0, "must not run chmod on Windows")
assert(installed() == true)

-- config & uninstall
assert(config() == true)
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "yq" and xvm_calls[1][3].bindir == cur_install_dir)
assert(uninstall() == true)
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "yq")
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
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "4.54.3")
        assert_command_output("yq --version", contains=expected)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("yq")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_eval_yaml_to_json(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        yq_bin = bindir / ("yq" + suffix)
        if not yq_bin.is_file():
            yq_bin = shutil.which("yq")
        assert yq_bin, "yq binary not found in subos bin or PATH"
        proc = subprocess.run(
            [str(yq_bin), "-o=json", ".a.b"],
            input="a:\n  b: 42\n",
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )
        assert proc.stdout.strip() == "42"
