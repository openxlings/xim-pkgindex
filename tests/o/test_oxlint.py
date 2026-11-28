"""Tests for the oxlint package."""
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_command_output,
    assert_config_registers_package_name,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_platform_supported,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "oxlint"
PKG_FILE = "pkgs/o/oxlint.lua"
REPO = Path(__file__).resolve().parents[2]
VERSION = "1.95.0"


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
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_package_registration(self, meta):
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_resource_matrix_and_autoupdate(self):
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "oxlint")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/oxc-project/oxc/releases", "unexpected autoupdate source")
assert(auto.tag == "oxlint_v${version}", "unexpected autoupdate tag")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)

local expected_arches = { x86_64 = true, aarch64 = true }
local basenames = {}
local count = 0
for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.deps == nil, "unexpected runtime deps on " .. plat)
    assert(p.latest and p.latest.ref == ver, "latest mismatch on " .. plat)
    local entry = assert(p[ver], "missing version entry on " .. plat)
    for arch in pairs(expected_arches) do
        local sha = assert(entry.sha256[arch], "missing sha256: " .. plat .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), plat .. "/" .. arch)
        local auto_tmpl = assert(auto.resources.GLOBAL.url[plat][arch])
        assert(auto_tmpl:find("${tag}", 1, true), "autoupdate URL must contain ${tag}")
        local tag = auto.tag:gsub("%${version}", ver)
        local auto_resolved = auto_tmpl:gsub("%${tag}", tag):gsub("%${version}", ver)
        local xpm_resolved = p.source:gsub("%${version}", ver):gsub("%${arch}", arch)
        assert(auto_resolved == xpm_resolved, "installer/updater URLs disagree for " .. plat .. "/" .. arch)
        local base = xpm_resolved:match("([^/]+)$")
        assert(not basenames[base], "duplicate asset basename: " .. tostring(base))
        basenames[base] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(expected_arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- POSIX archive extraction + rename + chmod + config + uninstall
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "oxlint" end,
    version = function() return "1.95.0" end,
    install_file = function() return "/cache/oxlint-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/store/xpkgs/xim-x-oxlint/1.95.0" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(d)
    dirs[d] = nil
    for k in pairs(files) do
        if k:sub(1, #d) == d then files[k] = nil end
    end
end
os.mv = function(src, dst)
    assert(files[src], "missing mv src: " .. src)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^tar %-xzf") then
            files["/store/xpkgs/xim-x-oxlint/1.95.0/oxlint-x86_64-unknown-linux-musl"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
files["/cache/oxlint-x86_64-unknown-linux-musl.tar.gz"] = true
assert(install())
assert(files["/store/xpkgs/xim-x-oxlint/1.95.0/oxlint"] == true)
assert(files["/store/xpkgs/xim-x-oxlint/1.95.0/oxlint-x86_64-unknown-linux-musl"] == nil)
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/oxlint-x86_64-unknown-linux-musl.tar.gz" -C "/store/xpkgs/xim-x-oxlint/1.95.0"')
assert(execs[2] == 'chmod +x "/store/xpkgs/xim-x-oxlint/1.95.0/oxlint"')
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "oxlint" and adds[1][2].bindir == "/store/xpkgs/xim-x-oxlint/1.95.0")
assert(uninstall())
assert(#rms == 1 and rms[1] == "oxlint")

-- Windows zip extraction via System32\\tar.exe + rename to oxlint.exe
files, dirs, execs = {}, {}, {}
pkginfo.install_file = function() return "C:/cache/oxlint-x86_64-pc-windows-msvc.zip" end
pkginfo.install_dir = function() return "C:/store/xpkgs/xim-x-oxlint/1.95.0" end
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
files["C:/cache/oxlint-x86_64-pc-windows-msvc.zip"] = true
system.exec = function(cmd)
    table.insert(execs, cmd)
    files["C:/store/xpkgs/xim-x-oxlint/1.95.0/oxlint-x86_64-pc-windows-msvc.exe"] = true
end

assert(not installed())
assert(install())
assert(files["C:/store/xpkgs/xim-x-oxlint/1.95.0/oxlint.exe"] == true)
assert(files["C:/store/xpkgs/xim-x-oxlint/1.95.0/oxlint-x86_64-pc-windows-msvc.exe"] == nil)
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\oxlint-x86_64-pc-windows-msvc.zip" -C "C:\\\\store\\\\xpkgs\\\\xim-x-oxlint\\\\1.95.0"')
assert(installed())

-- Missing archive and extracted binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
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
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
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
    def _oxlint_bin(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("oxlint" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("oxlint")
        assert found, f"Missing installed oxlint shim at {shim} or in PATH"
        return found

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output(f'"{self._oxlint_bin()}" --version', contains=f"Version: {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = "current" if (Path(xlings_home()) / "subos" / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered("oxlint")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_shim_exists(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS")
        if subos:
            shim = Path(xlings_home()) / "subos" / subos / "bin" / ("oxlint" + suffix)
            assert shim.is_file(), f"shim not found at {shim}"
        else:
            subos = "current" if (Path(xlings_home()) / "subos" / "current" / "bin").is_dir() else "default"
            shim = Path(xlings_home()) / "subos" / subos / "bin" / ("oxlint" + suffix)
            assert shim.is_file(), f"shim not found at {shim}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_lint_js(self, tmp_path):
        oxlint_bin = self._oxlint_bin()
        bad = tmp_path / "bad.js"
        bad.write_text("const x = 1; debugger;\n", encoding="utf-8")
        proc = subprocess.run(
            [oxlint_bin, str(bad)],
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert "no-debugger" in out
        assert "Found 2 warnings" in out
