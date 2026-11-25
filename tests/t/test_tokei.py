"""Tests for the tokei package."""
import os
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
    assert_command_output, assert_xvm_registered, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "tokei"
PKG_FILE = "pkgs/t/tokei.lua"
VERSION = "12.1.2"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args], input=script, text=True, capture_output=True, check=True
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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_supported_platforms_and_sha256_pinned(self, meta):
        """Upstream v12.1.2 ships Linux (x86_64 musl, aarch64 gnu) and Windows
        (x86_64 MSVC exe); no aarch64-apple-darwin or windows/aarch64 binaries exist."""
        assert set(meta.platforms.keys()) == {"linux", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "tokei")
assert(package.xpm.macosx == nil, "macosx lacks aarch64-apple-darwin upstream")

local linux = assert(package.xpm.linux)
assert(linux.latest and linux.latest.ref == ver)
assert(linux.deps and linux.deps.runtime)
local ldeps = {}
for _, d in ipairs(linux.deps.runtime) do ldeps[d] = true end
assert(ldeps["xim:glibc"] and ldeps["xim:gcc-runtime"])

for _, arch in ipairs({"x86_64", "aarch64"}) do
    local entry = assert(linux[ver] and linux[ver][arch], "missing linux/" .. arch)
    assert(type(entry.url) == "string" and entry.url:find("v" .. ver, 1, true))
    assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"))
end

local win = assert(package.xpm.windows)
assert(win.latest and win.latest.ref == ver)
assert(win.deps and win.deps.runtime)
local wdeps = {}
for _, d in ipairs(win.deps.runtime) do wdeps[d] = true end
assert(wdeps["xim:vcruntime"])
local w64 = assert(win[ver] and win[ver].x86_64, "missing windows/x86_64")
assert(type(w64.url) == "string" and w64.url:find("v" .. ver, 1, true))
assert(w64.url:match("%.exe$") ~= nil)
assert(type(w64.sha256) == "string" and #w64.sha256 == 64 and w64.sha256:match("^%x+$"))
assert(win[ver].aarch64 == nil, "windows/aarch64 has no official upstream binaries")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/XAMPPRocky/tokei/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
assert(auto.resources.GLOBAL.url.macosx == nil)
assert(auto.resources.GLOBAL.url.linux.x86_64:find("${tag}", 1, true))
assert(auto.resources.GLOBAL.url.linux.aarch64:find("${tag}", 1, true))
assert(auto.resources.GLOBAL.url.windows.x86_64:find("${tag}", 1, true))
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_linux_install_installed_config_uninstall_hooks(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local present, moved, removed, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
present["/tmp/cache/tokei"] = true
pkginfo = {
    name = function() return "tokei" end,
    install_dir = function() return "/opt/xpkgs/tokei/12.1.2" end,
    install_file = function() return "/tmp/cache/tokei-x86_64-unknown-linux-musl.tar.gz" end,
}
os.isfile = function(p) return present[p] == true end
os.tryrm = function(p) table.insert(removed, p) end
fs = { mkdir_p = function() end }
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    present[src] = nil
    present[dst] = true
end
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/tmp/cache/tokei" and moved[1][2] == "/opt/xpkgs/tokei/12.1.2/tokei")
assert(installed())
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "tokei" and xvm_adds[1][2].bindir == "/opt/xpkgs/tokei/12.1.2")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "tokei")
''', PKG_FILE)

    @pytest.mark.static
    def test_windows_exe_install_with_vcruntime(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local exe_path = "C:/cache/tokei-x86_64-pc-windows-msvc.exe"
local dst_exe = "C:/xpkgs/tokei/12.1.2/tokei.exe"
local present = { [exe_path] = true }
local moved, copied = {}, {}
pkginfo = {
    name = function() return "tokei" end,
    install_dir = function() return "C:/xpkgs/tokei/12.1.2" end,
    install_file = function() return exe_path end,
    dep_install_dir = function(dep)
        assert(dep == "xim:vcruntime")
        return "C:/xpkgs/xim-x-vcruntime/14.44"
    end,
}
os.isfile = function(p) return present[p] == true end
os.tryrm = function() end
os.getenv = function(k)
    if k == "OS" then return "Windows_NT" end
    return nil
end
fs = {
    mkdir_p = function() end,
    files = function(d)
        assert(d == "C:/xpkgs/xim-x-vcruntime/14.44/bin")
        return { d .. "/runtime_a.dll", d .. "/runtime_b.dll" }
    end,
}
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    present[src] = nil
    present[dst] = true
end
os.cp = function(src, dst)
    table.insert(copied, {src, dst})
end

assert(not installed())
assert(install())
assert(installed())
assert(#moved == 1 and moved[1][1] == exe_path and moved[1][2] == dst_exe)
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/tokei/12.1.2")
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
    def test_tokei_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output("tokei --version", contains=f"tokei {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_tokei(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("tokei")
        assert_xvm_shim_exists("tokei")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_counts_code(self, tmp_path):
        sample = tmp_path / "hello.rs"
        sample.write_text('fn main() {\n    println!("hi");\n}\n', encoding="utf-8")
        proc = subprocess.run(
            ["bash", "-l", "-c", f"tokei '{tmp_path}'"],
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert "Rust" in proc.stdout
        assert "Total" in proc.stdout
