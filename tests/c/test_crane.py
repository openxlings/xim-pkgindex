"""Tests for the crane package."""
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
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "crane"
PKG_FILE = "pkgs/c/crane.lua"
VERSION = "0.22.1"
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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_all_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["crane"]
        _run_lua(
            '''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "crane")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/google/go-containerregistry/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected = {
    linux = { x86_64 = "x86_64", aarch64 = "arm64" },
    macosx = { x86_64 = "x86_64", aarch64 = "arm64" },
    windows = { x86_64 = "x86_64", aarch64 = "arm64" },
}
local count = 0
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(p.latest and p.latest.ref == ver, "latest.ref mismatch in " .. plat)
    local entry = assert(p[ver], "missing " .. ver .. " in " .. plat)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias, plat .. "/" .. arch)
        local sha = assert(entry.sha256 and entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local auto_tpl = assert(global_url[plat] and global_url[plat][arch])
        assert(auto_tpl:find("${tag}", 1, true), "autoupdate must use ${tag}: " .. plat .. "/" .. arch)
        local auto_resolved = auto_tpl:gsub("%${tag}", "v" .. ver):gsub("%${version}", ver)
        local xpm_resolved = p.source:gsub("%${version}", ver):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved, "installer/updater URLs disagree for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local ver = arg[2]

-- Case 1: POSIX flat .tar.gz extracted directly into install_dir
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "crane" end,
    version = function() return ver end,
    install_file = function() return "/cache/go-containerregistry_Linux_x86_64.tar.gz" end,
    install_dir = function() return "/xpkgs/crane/" .. ver end,
}
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k:sub(1, #p) == p then files[k] = nil end
    end
end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xf") then
            files["/xpkgs/crane/" .. ver .. "/crane"] = true
            files["/xpkgs/crane/" .. ver .. "/gcrane"] = true
            files["/xpkgs/crane/" .. ver .. "/krane"] = true
            files["/xpkgs/crane/" .. ver .. "/LICENSE"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

files["/cache/go-containerregistry_Linux_x86_64.tar.gz"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 4)
assert(execs[1] == 'tar -xf "/cache/go-containerregistry_Linux_x86_64.tar.gz" -C "/xpkgs/crane/' .. ver .. '"')
assert(execs[2] == 'chmod +x "/xpkgs/crane/' .. ver .. '/crane"')
assert(execs[3] == 'chmod +x "/xpkgs/crane/' .. ver .. '/gcrane"')
assert(execs[4] == 'chmod +x "/xpkgs/crane/' .. ver .. '/krane"')

files["/xpkgs/crane/" .. ver .. "/krane"] = nil
assert(not installed(), "accepted missing krane binary")
files["/xpkgs/crane/" .. ver .. "/krane"] = true

assert(config())
assert(#adds == 3)
assert(adds[1][1] == "crane" and adds[1][2].bindir == "/xpkgs/crane/" .. ver and adds[1][2].binding == nil)
assert(adds[2][1] == "gcrane" and adds[2][2].bindir == "/xpkgs/crane/" .. ver and adds[2][2].binding == "crane@" .. ver)
assert(adds[3][1] == "krane" and adds[3][2].bindir == "/xpkgs/crane/" .. ver and adds[3][2].binding == "crane@" .. ver)

assert(uninstall())
assert(#rms == 3)
assert(rms[1] == "krane" and rms[2] == "gcrane" and rms[3] == "crane")

-- Case 2: Windows flat .tar.gz via System32\\tar.exe
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "crane" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/go-containerregistry_Windows_x86_64.tar.gz" end,
    install_dir = function() return "C:/xpkgs/crane/" .. ver end,
}
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/crane/" .. ver .. "/crane.exe"] = true
        files["C:/xpkgs/crane/" .. ver .. "/gcrane.exe"] = true
        files["C:/xpkgs/crane/" .. ver .. "/krane.exe"] = true
        files["C:/xpkgs/crane/" .. ver .. "/LICENSE"] = true
    end,
}

files["C:/cache/go-containerregistry_Windows_x86_64.tar.gz"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\go-containerregistry_Windows_x86_64.tar.gz" -C "C:\\\\xpkgs\\\\crane\\\\' .. ver .. '"')
assert(config())
assert(#adds == 3)
assert(uninstall())
assert(#rms == 3)

-- Case 3: Windows fallback when archive was pre-extracted into parent dir
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
files["C:/cache/crane.exe"] = true
files["C:/cache/gcrane.exe"] = true
files["C:/cache/krane.exe"] = true
files["C:/cache/LICENSE"] = true
files["C:/cache/README.md"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 0)
''',
            PKG_FILE,
            VERSION,
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
            "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    def _shim(self, prog: str) -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / (prog + suffix)
        if shim.is_file():
            return shim
        found = shutil.which(prog)
        assert found, f"Missing installed shim at {shim} or in PATH"
        return Path(found)

    def _run_prog(self, prog: str, *args: str) -> str:
        shim = self._shim(prog)
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_versions(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert expected in self._run_prog("crane", "version")
        assert expected in self._run_prog("gcrane", "version")
        assert expected in self._run_prog("krane", "version")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        for prog in ("crane", "gcrane", "krane"):
            assert_xvm_registered(prog)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_completion_offline_smoke(self):
        out = self._run_prog("crane", "completion", "bash")
        assert "__start_crane" in out or "complete" in out
