"""Tests for the popeye package."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
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

PKG = "popeye"
PKG_FILE = "pkgs/p/popeye.lua"
VERSION = "0.22.1"
REPO = Path(__file__).resolve().parents[2]


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
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_platforms_arches_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            r'''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "popeye")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/derailed/popeye/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)
local global_url = assert(au.resources.GLOBAL.url)

assert(package.xpm.linux.deps == nil, "static linux binaries must declare no runtime deps")
assert(package.xpm.macosx.deps == nil, "macosx binaries must declare no runtime deps")
assert(package.xpm.windows.deps == nil, "static Go windows binaries must declare no runtime deps")

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
local seen_filenames = {}
local count = 0
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    local version = assert(section.latest and section.latest.ref, "missing latest.ref: " .. plat)
    assert(version == ver, plat .. " latest.ref mismatch")
    local entry = assert(section[version], "missing version entry: " .. plat)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias, plat .. "/" .. arch)
        local digest = assert(entry.sha256 and entry.sha256[arch], "missing sha256: " .. plat .. "/" .. arch)
        assert(type(digest) == "string" and #digest == 64 and digest:match("^[0-9a-f]+$"), plat .. "/" .. arch)
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        assert(tmpl:find("${tag}", 1, true), "autoupdate template must use ${tag}")
        assert(not tmpl:find("${arch_alias}", 1, true), "autoupdate template must not use ${arch_alias}")
        local resolved_au = tmpl:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local resolved_xpm = section.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
        local filename = resolved_xpm:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch " .. arch .. " in " .. plat)
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
            r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
assert(loadfile(arg[1]))()
local ver = arg[2]

local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
local function populate(root, exe)
    files[root .. "/" .. exe] = true
    files[root .. "/LICENSE"] = true
    files[root .. "/README.md"] = true
end

-- 1. POSIX flat .tar.gz extracted directly into install_dir
pkginfo = {
    name = function() return "popeye" end,
    version = function() return ver end,
    install_file = function() return "/cache/popeye_linux_amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/popeye/" .. ver end,
}
files["/cache/popeye_linux_amd64.tar.gz"] = true
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
        if cmd:match("^tar %-xzf") then
            populate("/xpkgs/popeye/" .. ver, "popeye")
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/popeye_linux_amd64.tar.gz" -C "/xpkgs/popeye/' .. ver .. '"')
assert(execs[2] == 'chmod +x "/xpkgs/popeye/' .. ver .. '/popeye"')
assert(installed())

files["/xpkgs/popeye/" .. ver .. "/LICENSE"] = nil
assert(not installed(), "must return false when LICENSE is missing")
files["/xpkgs/popeye/" .. ver .. "/LICENSE"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "popeye" and adds[1][2].bindir == "/xpkgs/popeye/" .. ver)
assert(uninstall())
assert(#rms == 1 and rms[1] == "popeye")

-- 2. Windows flat .tar.gz extracted via System32\tar.exe
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "popeye" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/popeye_windows_amd64.tar.gz" end,
    install_dir = function() return "C:/xpkgs/popeye/" .. ver end,
}
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        populate("C:/xpkgs/popeye/" .. ver, "popeye.exe")
    end,
}

files["C:/cache/popeye_windows_amd64.tar.gz"] = true
assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\Windows\\System32\\tar.exe -xf "C:\\cache\\popeye_windows_amd64.tar.gz" -C "C:\\xpkgs\\popeye\\' .. ver .. '"')
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "popeye" and adds[1][2].bindir == "C:/xpkgs/popeye/" .. ver)
assert(uninstall())
assert(#rms == 1 and rms[1] == "popeye")

-- 3. Windows fallback when archive was pre-extracted into parent dir
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
populate("C:/cache", "popeye.exe")
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 0)

-- 4. Missing archive and extracted binary must fail
files = {}
os.getenv = function() return nil end
pkginfo = {
    name = function() return "popeye" end,
    version = function() return ver end,
    install_file = function() return "/cache/popeye_linux_amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/popeye/" .. ver end,
}
local ok = pcall(install)
assert(not ok, "install() must fail when archive does not exist")
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
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


@skip_if_not("linux")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=120)


@skip_if_not("linux")
class TestVerify:
    @staticmethod
    def _popeye_bin() -> str:
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("popeye" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("popeye")
        assert found, f"Missing installed popeye shim at {shim} or in PATH"
        return found

    def _run_popeye(self, *args: str) -> str:
        proc = subprocess.run(
            [self._popeye_bin(), *args],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=15,
        )
        return proc.stdout + proc.stderr

    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        out = self._run_popeye("version")
        assert expected in out, out

    @pytest.mark.verify
    def test_help(self):
        out = self._run_popeye("--help")
        assert "Popeye scans your Kubernetes clusters" in out, out

    @pytest.mark.verify
    def test_info(self):
        out = self._run_popeye("info")
        assert "Logs:" in out, out

    @pytest.mark.verify
    def test_non_blocking_probe(self):
        out = self._run_popeye("/?")
        assert 'unknown command "/?"' in out, out

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = "current" if (Path(xlings_home()) / "subos" / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_shim(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS")
        if subos:
            shim = Path(xlings_home()) / "subos" / subos / "bin" / ("popeye" + suffix)
            assert shim.is_file(), f"shim not found at {shim}"
        else:
            assert_xvm_shim_exists(PKG)
