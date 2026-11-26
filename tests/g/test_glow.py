"""Tests for the glow package."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_platform_supported,
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
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "glow"
PKG_FILE = "pkgs/g/glow.lua"
REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_lua(script: str, *args: str) -> str:
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
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping(self):
        source = r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.name == "glow", "name must be glow")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(#package.programs == 1 and package.programs[1] == "glow", "programs must be {glow}")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/charmbracelet/glow/releases")
local global_res = assert(auto.resources and auto.resources.GLOBAL)
assert(global_res.required == true)

local expected = {
    linux = { x86_64 = "x86_64", aarch64 = "arm64" },
    macosx = { x86_64 = "x86_64", aarch64 = "arm64" },
    windows = { x86_64 = "x86_64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing xpm." .. platform)
    assert(p.deps == nil, platform .. " static binary needs no runtime deps")
    local version = assert(p.latest and p.latest.ref, "missing latest.ref for " .. platform)
    assert(version == "3.0.0", "expected latest.ref == 3.0.0 for " .. platform)
    local entry = assert(p[version], "missing version entry for " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local digest = assert(entry.sha256[arch], "missing sha256 for " .. platform .. "/" .. arch)
        assert(#digest == 64 and digest:match("^[0-9a-f]+$"), platform .. "/" .. arch)
        local auto_tmpl = assert(global_res.url[platform] and global_res.url[platform][arch])
        assert(auto_tmpl:find("${tag}", 1, true), "autoupdate URL must use ${tag}")
        assert(auto_tmpl:find("${version}", 1, true), "autoupdate URL must use ${version}")
        local auto_resolved = auto_tmpl:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local xpm_resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved, "installer/updater URLs disagree for " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 5)
'''
        _run_lua(source, PKG_FILE)

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        source = r'''
function import() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
system = {}
shell = assert(loadfile("libs/shell.lua"))()

local files = {}
local dirs = {}
local execs = {}
local xvm_calls = {}
local cur_install_file = ""
local cur_install_dir = ""
local cur_host = "linux"

pkginfo = {
    name = function() return "glow" end,
    version = function() return "3.0.0" end,
    install_file = function() return cur_install_file end,
    install_dir = function() return cur_install_dir end,
}
os.host = function() return cur_host end
os.getenv = function(k) return k == "SystemRoot" and "C:\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(d)
    dirs[d] = nil
    for k in pairs(files) do
        if k:sub(1, #d) == d then files[k] = nil end
    end
end
os.mv = function(src, dst)
    assert(dirs[src], "missing src dir: " .. src)
    dirs[src] = nil
    dirs[dst] = true
    local prefix = src .. "/"
    local moved = {}
    for k, v in pairs(files) do
        if k:sub(1, #prefix) == prefix then
            table.insert(moved, { k, dst .. "/" .. k:sub(#prefix + 1), v })
        end
    end
    for _, item in ipairs(moved) do
        files[item[1]] = nil
        files[item[2]] = item[3]
    end
end
fs = { mkdir_p = function(d) dirs[d] = true end }
log = { info = function() end }
system.exec = function(cmd)
    table.insert(execs, cmd)
    if cur_host == "windows" then
        files[cur_install_dir .. "/glow.exe"] = true
        files[cur_install_dir .. "/LICENSE"] = true
    end
end
xvm = {
    add = function(name, opts) table.insert(xvm_calls, {"add", name, opts}) end,
    remove = function(name) table.insert(xvm_calls, {"remove", name}) end,
}

assert(loadfile(arg[1]))()

-- POSIX case (pre-extracted top-level directory matching archive stem)
cur_host = "linux"
cur_install_file = "/tmp/dl/glow_3.0.0_Linux_x86_64.tar.gz"
cur_install_dir = "/store/xpkgs/xim-x-glow/3.0.0"
dirs["/tmp/dl/glow_3.0.0_Linux_x86_64"] = true
files["/tmp/dl/glow_3.0.0_Linux_x86_64/glow"] = true
files["/tmp/dl/glow_3.0.0_Linux_x86_64/LICENSE"] = true
assert(installed() == false)
assert(install() == true)
assert(files[cur_install_dir .. "/glow"] == true)
assert(files[cur_install_dir .. "/LICENSE"] == true)
assert(#execs == 1 and execs[1] == "'chmod' '+x' '/store/xpkgs/xim-x-glow/3.0.0/glow'")
assert(installed() == true)

-- Windows case (zip extracted via payload.unpack / System32 tar.exe --strip-components=1)
files = {}
dirs = {}
execs = {}
cur_host = "windows"
cur_install_file = "C:/dl/glow_3.0.0_Windows_x86_64.zip"
cur_install_dir = "C:/store/xpkgs/xim-x-glow/3.0.0"
assert(installed() == false)
assert(install() == true)
assert(#execs == 1)
assert(execs[1]:match('^C:\\Windows\\System32\\tar%.exe %-xf "C:\\dl\\glow_3%.0%.0_Windows_x86_64%.zip" %-%-strip%-components=1 %-C "C:\\store\\xpkgs\\xim%-x%-glow\\3%.0%.0"$'))
assert(installed() == true)

-- config & uninstall
assert(config() == true)
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "glow" and xvm_calls[1][3].bindir == cur_install_dir)
assert(uninstall() == true)
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "glow")
'''
        _run_lua(source, PKG_FILE)


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
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|try\s*\{|raise\()', src)


@skip_if_not("linux")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


@skip_if_not("linux")
class TestVerify:
    @staticmethod
    def _glow_bin() -> str:
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("glow" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("glow")
        assert found, f"Missing glow shim ({shim}) and not found on PATH"
        return found

    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "3.0.0")
        assert_command_output("glow --version", contains=f"glow version {expected}")

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos_name = "current" if (subos_dir / "current").is_dir() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos_name)
        assert_xvm_registered("glow")

    @pytest.mark.verify
    def test_renders_markdown_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            md = Path(tmpdir) / "sample.md"
            md.write_text("# Hello Glow\n\n- item one\n", encoding="utf-8")
            proc = subprocess.run(
                [self._glow_bin(), str(md)],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                encoding="utf-8",
                check=True,
                timeout=15,
            )
            assert "Hello Glow" in proc.stdout, proc.stdout
            assert "item one" in proc.stdout, proc.stdout

    @pytest.mark.verify
    def test_slash_question_exits_cleanly(self):
        proc = subprocess.run(
            [self._glow_bin(), "/?"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=5,
        )
        assert proc.returncode != 0
