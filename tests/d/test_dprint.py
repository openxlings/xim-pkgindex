"""Tests for the dprint package (`dprint` CLI)."""
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
    assert_config_registers_package_name,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_xvm_registered,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "dprint"
PKG_FILE = "pkgs/d/dprint.lua"
VERSION = "0.65.0"
REPO = Path(__file__).resolve().parents[2]


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
        cwd=REPO,
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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_platforms_arches_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["dprint"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "dprint")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "dprint")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/dprint/dprint/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local count = 0
for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(not section.deps, plat .. " should not declare runtime deps for static binaries")
    assert(type(section.source) == "string" and section.source:find("${version}", 1, true))
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    assert(ver.sha256, "missing sha256 table in " .. plat)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        assert(tpl:find("${tag}", 1, true), "missing ${tag} in " .. tpl)
        local auto_resolved = tpl:gsub("%${tag}", "''' + VERSION + '''")
        local xpm_resolved = section.source:gsub("%${version}", "''' + VERSION + '''"):gsub("%${arch}", arch)
        assert(auto_resolved == xpm_resolved, "xpm and autoupdate URLs disagree for " .. plat .. "/" .. arch)
        count = count + 1
    end
end
assert(count == 6)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_all_six_sha256_unique(self, meta):
        sha_matches = re.findall(r'(?:x86_64|aarch64)\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(sha_matches) == 6
        assert len(set(sha_matches)) == 6

    @pytest.mark.static
    @pytest.mark.skipif(shutil.which("luac") is None, reason="no luac on this machine")
    def test_lua_syntax(self):
        r = subprocess.run(["luac", "-p", str(REPO / PKG_FILE)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr

    @pytest.mark.static
    def test_hooks_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

-- POSIX install from .zip archive
local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files["/cache/dprint-x86_64-unknown-linux-musl.zip"] = true

pkginfo = {
    name = function() return "dprint" end,
    version = function() return "0.65.0" end,
    install_file = function() return "/cache/dprint-x86_64-unknown-linux-musl.zip" end,
    install_dir = function() return "/xpkgs/dprint/0.65.0" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^'unzip'") then
            files["/xpkgs/dprint/0.65.0/dprint"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == "'unzip' '-q' '-o' '/cache/dprint-x86_64-unknown-linux-musl.zip' '-d' '/xpkgs/dprint/0.65.0'")
assert(execs[2] == "'chmod' '+x' '/xpkgs/dprint/0.65.0/dprint'")
assert(installed())

files["/xpkgs/dprint/0.65.0/dprint"] = nil
assert(not installed(), "accepted missing dprint binary")
files["/xpkgs/dprint/0.65.0/dprint"] = true

assert(config())
assert(#xvm_adds == 1)
assert(xvm_adds[1][1] == "dprint" and xvm_adds[1][2].bindir == "/xpkgs/dprint/0.65.0")

assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "dprint")

-- Windows install via libs/payload.lua (.zip -> System32\\tar.exe)
files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files["C:/cache/dprint-x86_64-pc-windows-msvc.zip"] = true
pkginfo = {
    name = function() return "dprint" end,
    version = function() return "0.65.0" end,
    install_file = function() return "C:/cache/dprint-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/dprint/0.65.0" end,
}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "OS" then return "Windows_NT" end
    if k == "SystemRoot" then return "C:\\\\Windows" end
    return nil
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/dprint/0.65.0/dprint.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\dprint%-x86_64%-pc%-windows%-msvc%.zip" %-C "C:\\\\xpkgs\\\\dprint\\\\0%.65%.0"$'))
assert(installed())

-- Missing archive and extracted binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
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
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    def _run_dprint(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("dprint" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        res = self._run_dprint("--version")
        assert res.returncode == 0, res.stdout + res.stderr
        assert f"dprint {expected}" in res.stdout, res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_license_and_help(self):
        res_help = self._run_dprint("--help")
        assert res_help.returncode == 0, res_help.stdout + res_help.stderr
        assert "Auto-formats source code based on the specified plugins." in res_help.stdout, res_help.stdout

        res_lic = self._run_dprint("license")
        assert res_lic.returncode == 0, res_lic.stdout + res_lic.stderr
        assert "DPRINT CLI LICENSE" in res_lic.stdout, res_lic.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_shim_exists("dprint")
        if os.environ.get("XLINGS_TEST_SUBOS"):
            assert_xvm_registered("dprint")
