"""Tests for the arcmd package."""
import json
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
    assert_config_registers_package_name,
    assert_valid_xvm_node_kinds,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "arcmd"
PKG_FILE = "pkgs/a/arcmd.lua"
VERSION = "0.5.2"
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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_platforms_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == []
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver = assert(package.xpm.linux and package.xpm.linux.latest and package.xpm.linux.latest.ref)
assert(package.spec == "2")
assert(package.name == "arcmd")
assert(package.namespace == nil)
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(type(package.programs) == "table" and #package.programs == 0)

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/Ciao1019/ArcMD/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64" },
}

local count = 0
for plat, aliases in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.deps == nil, plat .. " stays on the host loader / OS DLLs with no runtime deps")
    assert(type(p.source) == "string")
    assert(p.latest and p.latest.ref == ver, plat .. " latest must ref " .. ver)
    local v = assert(p[ver], "missing latest version entry on " .. plat)
    for k, entry in pairs(p) do
        if k ~= "source" and k ~= "latest" and k ~= "deps" then
            assert(type(entry) == "table", plat .. "/" .. k .. " must be a table")
            local has_per_arch = entry.x86_64 ~= nil or entry.aarch64 ~= nil
            if has_per_arch then
                for arch in pairs(aliases) do
                    local a = assert(entry[arch], "missing per-arch entry for " .. plat .. "/" .. k .. "/" .. arch)
                    assert(type(a.sha256) == "string" and #a.sha256 == 64 and a.sha256:match("^%x+$"))
                    local auto_url = assert(auto.resources.GLOBAL.url[plat][arch])
                    local resolved = auto_url:gsub("%${tag}", "v" .. k):gsub("%${version}", k)
                    local actual_url = type(a.url) == "table" and a.url.GLOBAL or a.url
                    assert(resolved == actual_url, "autoupdate URL disagrees for " .. plat .. "/" .. k .. "/" .. arch)
                end
            else
                assert(type(entry.arch_alias) == "table", plat .. "/" .. k .. " must declare arch_alias")
                assert(type(entry.sha256) == "table", plat .. "/" .. k .. " must declare per-arch sha256 table")
                for arch, alias in pairs(aliases) do
                    assert(entry.arch_alias[arch] == alias, "unexpected arch_alias for " .. plat .. "/" .. k .. "/" .. arch)
                    local digest = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. k .. "/" .. arch)
                    assert(type(digest) == "string" and #digest == 64 and digest:match("^%x+$"))
                    local xpm_url = p.source:gsub("%${version}", k):gsub("%${arch_alias}", alias)
                    local auto_url = assert(auto.resources.GLOBAL.url[plat][arch])
                    local resolved = auto_url:gsub("%${tag}", "v" .. k):gsub("%${version}", k)
                    assert(resolved == xpm_url, "autoupdate URL disagrees for " .. plat .. "/" .. k .. "/" .. arch)
                end
                for arch_key in pairs(entry.sha256) do
                    assert(aliases[arch_key] ~= nil, "unexpected arch in sha256: " .. plat .. "/" .. k .. "/" .. arch_key)
                end
            end
        end
    end
    for arch in pairs(aliases) do
        count = count + 1
    end
end
assert(package.xpm.windows[ver].aarch64 == nil and (package.xpm.windows[ver].sha256 == nil or package.xpm.windows[ver].sha256.aarch64 == nil), "windows/aarch64 is not published upstream")
assert(count == 5)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_linux_macos_and_windows_sandbox(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
system = {}
shell = assert(loadfile("libs/shell.lua"))()
shortcut = assert(loadfile("libs/shortcut.lua"))()
dofile(arg[1])

local ver = arg[2]

-- Case 1: Linux flat .tar.gz extracted directly into install_dir
local files, dirs, execs, adds, rms, warns = {}, {}, {}, {}, {}, {}
local host = "linux"
local install_file = "/cache/arcmd-" .. ver .. "-linux-amd64.tar.gz"
local install_dir = "/xpkgs/arcmd/" .. ver
files[install_file] = true
os.host = function() return host end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    files[p] = nil
    for k in pairs(files) do
        if k:sub(1, #p + 1) == p .. "/" then files[k] = nil end
    end
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end, warn = function(m) table.insert(warns, m) end }
system.exec = function(cmd)
    table.insert(execs, cmd)
    if cmd:match("^'tar' ") then
        files[install_dir .. "/arcmd"] = true
        files[install_dir .. "/LICENSE"] = true
        files[install_dir .. "/arcmd.png"] = true
        files[install_dir .. "/third_party/README.md"] = true
    end
end
pkginfo = {
    name = function() return "arcmd" end,
    version = function() return ver end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == "'tar' '-xzf' '" .. install_file .. "' '-C' '" .. install_dir .. "'")
assert(execs[2] == "'chmod' '+x' '" .. install_dir .. "/arcmd'")
files[install_dir .. "/third_party/README.md"] = nil
assert(not installed(), "accepted missing third_party/README.md")
files[install_dir .. "/third_party/README.md"] = true
assert(config())
assert(#adds == 1 and adds[1][1] == "arcmd" and adds[1][2].bindir == install_dir and adds[1][2].alias == nil)
assert(uninstall())
assert(#rms == 1 and rms[1] == "arcmd")
assert(#warns == 0)

-- Case 2: macOS ArcMD.app bundle inside .tar.gz
files, dirs, execs, adds, rms, warns = {}, {}, {}, {}, {}, {}
host = "macosx"
install_file = "/cache/arcmd-" .. ver .. "-darwin-arm64.tar.gz"
install_dir = "/xpkgs/arcmd/" .. ver
files[install_file] = true
system.exec = function(cmd)
    table.insert(execs, cmd)
    if cmd:match("^'tar' ") then
        files[install_dir .. "/ArcMD.app/Contents/MacOS/ArcMD"] = true
        files[install_dir .. "/ArcMD.app/Contents/Info.plist"] = true
        files[install_dir .. "/ArcMD.app/Contents/Resources/LICENSE"] = true
    end
end

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == "'tar' '-xzf' '" .. install_file .. "' '-C' '" .. install_dir .. "'")
assert(execs[2] == "'chmod' '+x' '" .. install_dir .. "/ArcMD.app/Contents/MacOS/ArcMD'")
assert(config())
assert(#adds == 1 and adds[1][1] == "arcmd"
       and adds[1][2].bindir == install_dir .. "/ArcMD.app/Contents/MacOS"
       and adds[1][2].alias == "ArcMD")
assert(uninstall())
assert(#rms == 1 and rms[1] == "arcmd")
assert(#warns == 0)

-- Case 3: Windows flat .zip + Start Menu shortcut (no Desktop icon)
files, dirs, execs, adds, rms, warns = {}, {}, {}, {}, {}, {}
local removed_paths = {}
host = "windows"
install_file = "C:/cache/arcmd-" .. ver .. "-windows-amd64.zip"
install_dir = "C:/xpkgs/arcmd/" .. ver
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    if k == "APPDATA" then return "C:\\\\Users\\\\alice\\\\AppData\\\\Roaming" end
    return nil
end
os.tryrm = function(p)
    table.insert(removed_paths, p)
    dirs[p] = nil
    files[p] = nil
end
system.exec = function(cmd)
    table.insert(execs, cmd)
    if cmd:find("tar.exe", 1, true) then
        files[install_dir .. "/ArcMD.exe"] = true
        files[install_dir .. "/LICENSE"] = true
        files[install_dir .. "/third_party/README.md"] = true
    elseif cmd:find("CreateShortcut(", 1, true) then
        local q = string.char(39)
        local _, b = cmd:find("CreateShortcut(", 1, true)
        local v = cmd:sub(b + 2)
        local e = v:find(q .. ");", 1, true)
        files[(v:sub(1, e - 1)):gsub(q .. q, q)] = true
    end
end

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\arcmd-' .. ver .. '-windows-amd64.zip" -C "C:\\\\xpkgs\\\\arcmd\\\\' .. ver .. '"')
assert(config())
assert(#adds == 1 and adds[1][1] == "arcmd" and adds[1][2].bindir == install_dir and adds[1][2].alias == "ArcMD.exe")
assert(#execs == 2 and execs[2]:find("Start Menu\\\\Programs\\\\ArcMD%.lnk", 1, false))
assert(not execs[2]:find("Desktop", 1, true))
assert(#warns == 0)
assert(uninstall())
assert(#rms == 1 and rms[1] == "arcmd")
assert(removed_paths[#removed_paths] == "C:\\\\Users\\\\alice\\\\AppData\\\\Roaming\\\\Microsoft\\\\Windows\\\\Start Menu\\\\Programs\\\\ArcMD.lnk")
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
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
            "xim.pkgindex.shortcut",
        }
        assert not re.search(r"\b(?:path\.|is_host\(|os\.host\(|raise\()", src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=180)


class TestVerify:
    def _run_arcmd(self, *args, env=None):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("arcmd" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=env,
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help(self):
        out = self._run_arcmd("--help")
        assert "arcmd status" in out and "arcmd doc" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_status_and_doc_roundtrip(self, tmp_path):
        env = {**os.environ, "ARCMD_HOME": str(tmp_path / "arcmd-home")}
        expected = os.environ.get("XLINGS_TEST_VERSION") or _run_lua(
            'import = function() end; dofile(arg[1]); io.write(package.xpm.linux.latest.ref)',
            PKG_FILE,
        )

        status = json.loads(self._run_arcmd("status", "-json", env=env))
        assert status["ok"] is True
        assert status["result"]["version"] == expected
        assert status["result"]["spaceCount"] >= 1

        created = json.loads(
            self._run_arcmd(
                "doc", "create",
                "-title", "Xlings Verify",
                "-content", "# Hello\n\nVerified in isolated ARCMD_HOME.",
                "-json",
                env=env,
            )
        )
        assert created["ok"] is True
        assert created["result"]["title"] == "Xlings Verify"

        listing = json.loads(self._run_arcmd("doc", "list", "-json", env=env))
        assert listing["ok"] is True
        titles = {item["title"] for item in listing["result"]["items"]}
        assert "Xlings Verify" in titles, titles

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos = "current" if (subos_dir / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered("arcmd")
