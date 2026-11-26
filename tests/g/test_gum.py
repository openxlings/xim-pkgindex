"""Tests for the gum package."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "gum"
PKG_FILE = "pkgs/g/gum.lua"
VERSION = "2.0.2"
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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "gum")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/charmbracelet/gum/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "x86_64", aarch64 = "arm64" },
    macosx = { x86_64 = "x86_64", aarch64 = "arm64" },
    windows = { x86_64 = "x86_64" },
}

local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    assert(p.deps == nil, platform .. " uses static binary and needs no runtime deps")
    assert(p.latest and p.latest.ref == ver, platform .. " latest must ref " .. ver)
    local entry = assert(p[ver], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), platform .. "/" .. arch)
        local auto_url = assert(auto.resources.GLOBAL.url[platform][arch])
        local resolved = p.source:gsub("%${version}", ver):gsub("%${arch_alias}", alias)
        assert(auto_url:gsub("%${tag}", "v" .. ver):gsub("%${version}", ver) == resolved,
               "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch in sha256: " .. platform .. "/" .. arch)
    end
end
assert(count == 5)
assert(package.xpm.windows[ver].sha256.aarch64 == nil, "windows/aarch64 has no upstream asset")
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_installed_install_config_uninstall_posix_and_windows(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX extracted directory via libs/payload.lua
local files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "gum" end,
    version = function() return "2.0.2" end,
    install_file = function() return "/cache/gum_2.0.2_Linux_x86_64.tar.gz" end,
    install_dir = function() return "/xpkgs/gum/2.0.2" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    files[p .. "/gum"] = nil
    files[p .. "/gum.exe"] = nil
    files[p .. "/LICENSE"] = nil
end
os.mv = function(src, dst)
    table.insert(mvs, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/gum"] = true
    files[dst .. "/LICENSE"] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

dirs["/cache/gum_2.0.2_Linux_x86_64"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#mvs == 1 and mvs[1][1] == "/cache/gum_2.0.2_Linux_x86_64" and mvs[1][2] == "/xpkgs/gum/2.0.2")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/gum/2.0.2/gum"')
assert(config())
assert(#adds == 1 and adds[1][1] == "gum" and adds[1][2].bindir == "/xpkgs/gum/2.0.2")
assert(uninstall())
assert(#rms == 1 and rms[1] == "gum")

-- Case 2: Windows .zip via libs/payload.lua -> System32\\tar.exe --strip-components=1
files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "gum" end,
    version = function() return "2.0.2" end,
    install_file = function() return "C:/cache/gum_2.0.2_Windows_x86_64.zip" end,
    install_dir = function() return "C:/xpkgs/gum/2.0.2" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
files["C:/cache/gum_2.0.2_Windows_x86_64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/gum/2.0.2/gum.exe"] = true
        files["C:/xpkgs/gum/2.0.2/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\gum_2.0.2_Windows_x86_64.zip" --strip-components=1 -C "C:\\\\xpkgs\\\\gum\\\\2.0.2"')
assert(config())
assert(#adds == 1 and adds[1][1] == "gum" and adds[1][2].bindir == "C:/xpkgs/gum/2.0.2")
assert(uninstall())
assert(#rms == 1 and rms[1] == "gum")

-- Case 3: Missing extracted dir and archive must fail
files, dirs = {}, {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither extracted dir nor archive exists")
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
    def _run_gum(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("gum" + suffix)
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
    def test_gum_version(self):
        out = self._run_gum("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert f"v{expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_gum_help(self):
        out = self._run_gum("--help")
        assert "gum" in out.lower() and "--version" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_gum_style(self):
        out = self._run_gum("style", "hello")
        assert "hello" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos = "current" if (subos_dir / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered("gum")
