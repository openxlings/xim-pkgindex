"""Tests for the watchexec package."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

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
    assert_command_output,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "watchexec"
PKG_FILE = "pkgs/w/watchexec.lua"
REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def code(meta):
    return "\n".join(
        line for line in meta.raw_content.splitlines()
        if not line.lstrip().startswith("--")
    )


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
    def test_expected_platforms(self, meta):
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)

    @pytest.mark.static
    def test_no_forbidden_xmake_apis(self, code):
        for pat in (r"\bpath\.", r"\bos\.host\s*\(", r"\bis_host\s*\(", r"\btry\s*\{", r"\braise\s*\("):
            assert not re.search(pat, code), f"forbidden xmake API pattern matched: {pat}"

    @pytest.mark.static
    def test_autoupdate_and_mirror_configured(self, meta, code):
        assert meta.programs == ["watchexec"]
        assert meta.has_xvm_enable
        assert "ci = { mirror = true }" in code
        assert 'source = "https://github.com/watchexec/watchexec/releases"' in code
        assert "${tag}" in code
        assert "${version}" in code

    @pytest.mark.static
    def test_resource_matrix_and_autoupdate_parity(self):
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
        assert(type(sum) == "string" and sum:match("^[0-9a-f]+$") and #sum == 64,
               platform .. "/" .. arch .. " sha256")
        local resolved = p.source:gsub("%${version}", version):gsub("%${arch}", arch)
        assert(resolved:match("^https://"), platform .. "/" .. arch .. " url")
        local auto = package.extensions.autoupdate.resources.GLOBAL.url[platform][arch]
        local auto_expanded = auto:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        assert(auto_expanded == resolved, "installer/updater URLs disagree for " .. platform .. "/" .. arch)
        local filename = resolved:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unexpected arch: " .. arch) end
end
assert(count == 5)
assert(package.xpm.linux.deps == nil, "musl static Linux binaries should not declare runtime deps")
local win_deps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(win_deps[1] == "xim:vcruntime" and #win_deps == 1)
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
local dirs = {}
local execs = {}
local xvm_calls = {}
local unpack_calls = {}
local cur_install_file = ""
local cur_install_dir = ""
local vcruntime_dir = "C:\\store\\xpkgs\\xim-x-vcruntime\\14.44.35211"

local mods = {
    ["xim.libxpkg.fs"] = function()
        fs = {
            files = function(d)
                if d == vcruntime_dir .. "/bin" then
                    return { vcruntime_dir .. "/bin/vcruntime140.dll" }
                end
                return {}
            end,
        }
    end,
    ["xim.libxpkg.pkginfo"] = function()
        pkginfo = {
            install_file = function() return cur_install_file end,
            install_dir = function() return cur_install_dir end,
            dep_install_dir = function(dep)
                if dep == "xim:vcruntime" then return vcruntime_dir end
                return nil
            end,
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
            exec = function(cmd)
                table.insert(execs, cmd)
                local archive, parent = cmd:match('^tar %-xJf "([^"]+)" %-C "([^"]+)"$')
                if archive and parent then
                    local stem = archive:match("([^/]+)$"):gsub("%.tar%.xz$", "")
                    dirs[parent .. "/" .. stem] = true
                end
            end,
        }
    end,
    ["xim.pkgindex.payload"] = function()
        payload = {
            present = function(list)
                for _, rel in ipairs(list) do
                    if not files[cur_install_dir .. "/" .. rel] then return false end
                end
                return true
            end,
            unpack = function(opt)
                table.insert(unpack_calls, opt)
                local exe = cur_install_file:match("%.zip$") and "watchexec.exe" or "watchexec"
                files[cur_install_dir .. "/" .. exe] = true
                return true
            end,
            require = function(list)
                for _, rel in ipairs(list) do
                    assert(files[cur_install_dir .. "/" .. rel], "missing required file: " .. rel)
                end
                return true
            end,
        }
    end,
}

function import(name)
    assert(mods[name], "unexpected import: " .. name)()
end

os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.cp = function(src, dst)
    local name = src:match("([^/\\]+)$")
    files[dst .. "/" .. name] = true
end

assert(loadfile(arg[1]))()

-- Unix case (archive not pre-extracted -> tar -xJf fallback runs)
cur_install_file = "/tmp/dl/watchexec-2.8.0-x86_64-unknown-linux-musl.tar.xz"
cur_install_dir = "/store/xpkgs/xim-x-watchexec/2.8.0"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(dirs["/tmp/dl/watchexec-2.8.0-x86_64-unknown-linux-musl"] == true)
assert(unpack_calls[1].extracted == "watchexec-2.8.0-x86_64-unknown-linux-musl")
assert(unpack_calls[1].strip == 1)
assert(files["/store/xpkgs/xim-x-watchexec/2.8.0/watchexec"] == true)
assert(installed() == true)

-- Windows case (copies xim:vcruntime DLLs app-local)
files = {}
dirs = {}
execs = {}
unpack_calls = {}
cur_install_file = "C:\\dl\\watchexec-2.8.0-x86_64-pc-windows-msvc.zip"
cur_install_dir = "C:\\store\\xpkgs\\xim-x-watchexec\\2.8.0"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(unpack_calls[1].extracted == "watchexec-2.8.0-x86_64-pc-windows-msvc")
assert(files[cur_install_dir .. "/watchexec.exe"] == true)
assert(files[cur_install_dir .. "/vcruntime140.dll"] == true)
assert(#execs == 0, "must not run tar/chmod on Windows")
assert(installed() == true)

-- config & uninstall
assert(config() == true)
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "watchexec" and xvm_calls[1][3].bindir == cur_install_dir)
assert(uninstall() == true)
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "watchexec")
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
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_lua_and_libxpkg_only(self):
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "2.8.0")
        assert_command_output("watchexec --version", contains=f"watchexec {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("watchexec")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_watches_file_change_and_runs_command(self, tmp_path):
        watch_dir = tmp_path / "watched"
        watch_dir.mkdir()
        target = watch_dir / "note.txt"
        target.write_text("v1\n", encoding="utf-8")
        marker = tmp_path / "triggered.txt"

        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        wx_bin = bindir / "watchexec"
        if not wx_bin.is_file():
            wx_bin = shutil.which("watchexec")
        assert wx_bin, "watchexec binary not found in subos bin or PATH"

        proc = subprocess.Popen(
            [str(wx_bin), "--postpone", "--no-vcs-ignore", "-w", str(watch_dir), "--shell=none", "--", "touch", str(marker)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            time.sleep(0.6)
            target.write_text("v2\n", encoding="utf-8")
            deadline = time.monotonic() + 10.0
            while time.monotonic() < deadline:
                if marker.is_file():
                    break
                time.sleep(0.1)
            assert marker.is_file(), "watchexec did not run command after watched file modification"
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
