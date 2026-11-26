"""Tests for the git-lfs package."""
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

PKG = "git-lfs"
PKG_FILE = "pkgs/g/git-lfs.lua"
VERSION = "3.8.1"
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
    def test_platforms_arches_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver_expected = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "git-lfs")

local auto = assert(package.extensions and package.extensions.autoupdate, "missing autoupdate")
assert(auto.source == "https://github.com/git-lfs/git-lfs/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected = {
    linux = { os_tag = "linux", ext = "tar.gz" },
    macosx = { os_tag = "darwin", ext = "zip" },
    windows = { os_tag = "windows", ext = "zip" },
}
local count = 0
local basenames = {}
for plat, spec in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(not section.deps, "static binary should not declare deps on " .. plat)
    local version = assert(section.latest and section.latest.ref)
    assert(version == ver_expected)
    local ver = assert(section[version], "missing version entry in " .. plat)
    assert(ver.arch_alias and ver.arch_alias.x86_64 == "amd64" and ver.arch_alias.aarch64 == "arm64")
    for arch, alias in pairs({ x86_64 = "amd64", aarch64 = "arm64" }) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^[0-9a-f]+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local au_tmpl = assert(global_url[plat] and global_url[plat][arch])
        assert(au_tmpl:find("${tag}", 1, true))
        local au_resolved = au_tmpl:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local xpm_resolved = section.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(au_resolved == xpm_resolved, "URL mismatch on " .. plat .. "/" .. arch)
        assert(xpm_resolved:find("git%-lfs%-" .. spec.os_tag .. "%-" .. alias .. "%-v" .. version .. "%." .. spec.ext .. "$"))
        local base = xpm_resolved:match("([^/]+)$")
        assert(base and not basenames[base], "duplicate or missing basename: " .. tostring(base))
        basenames[base] = true
        count = count + 1
    end
    for arch in pairs(ver.sha256) do
        assert(arch == "x86_64" or arch == "aarch64", "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_linux_macos_and_windows_archives(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: Linux pre-extracted .tar.gz directory beside archive (git-lfs-3.8.1/)
local files, dirs, moved, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}, {}
dirs["/cache/git-lfs-3.8.1"] = true

pkginfo = {
    name = function() return "git-lfs" end,
    version = function() return "3.8.1" end,
    install_file = function() return "/cache/git-lfs-linux-amd64-v3.8.1.tar.gz" end,
    install_dir = function() return "/xpkgs/git-lfs/3.8.1" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/git-lfs"] = true
    files[dst .. "/README.md"] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/git-lfs-3.8.1" and moved[1][2] == "/xpkgs/git-lfs/3.8.1")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/git-lfs/3.8.1/git-lfs"')
assert(installed())

files["/xpkgs/git-lfs/3.8.1/git-lfs"] = nil
assert(not installed(), "accepted missing git-lfs binary")
files["/xpkgs/git-lfs/3.8.1/git-lfs"] = true
files["/xpkgs/git-lfs/3.8.1/README.md"] = nil
assert(not installed(), "accepted missing README.md")
files["/xpkgs/git-lfs/3.8.1/README.md"] = true

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "git-lfs" and xvm_adds[1][2].bindir == "/xpkgs/git-lfs/3.8.1")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "git-lfs")

-- Case 2: Linux unextracted .tar.gz fallback
files, dirs, moved, execs = {}, {}, {}, {}
files["/cache/git-lfs-linux-arm64-v3.8.1.tar.gz"] = true
pkginfo.install_file = function() return "/cache/git-lfs-linux-arm64-v3.8.1.tar.gz" end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar ") then
            files["/xpkgs/git-lfs/3.8.1/git-lfs"] = true
            files["/xpkgs/git-lfs/3.8.1/README.md"] = true
        end
    end,
}
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/git-lfs-linux-arm64-v3.8.1.tar.gz" --strip-components=1 -C "/xpkgs/git-lfs/3.8.1"')
assert(execs[2] == 'chmod +x "/xpkgs/git-lfs/3.8.1/git-lfs"')

-- Case 3: macOS .zip fallback via unzip -q -o (must NOT treat .zip as Windows)
files, dirs, moved, execs = {}, {}, {}, {}
os.host = function() return "macosx" end
files["/cache/git-lfs-darwin-arm64-v3.8.1.zip"] = true
pkginfo.install_file = function() return "/cache/git-lfs-darwin-arm64-v3.8.1.zip" end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^unzip ") then
            dirs["/xpkgs/git-lfs/3.8.1.unpack/git-lfs-3.8.1"] = true
        end
    end,
}
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'unzip -q -o "/cache/git-lfs-darwin-arm64-v3.8.1.zip" -d "/xpkgs/git-lfs/3.8.1.unpack"')
assert(execs[2] == 'chmod +x "/xpkgs/git-lfs/3.8.1/git-lfs"')

-- Case 4: macOS .zip fallback to bsdtar if unzip fails
files, dirs, moved, execs = {}, {}, {}, {}
files["/cache/git-lfs-darwin-amd64-v3.8.1.zip"] = true
pkginfo.install_file = function() return "/cache/git-lfs-darwin-amd64-v3.8.1.zip" end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^unzip ") then
            error("unzip unavailable")
        elseif cmd:match("^tar ") then
            files["/xpkgs/git-lfs/3.8.1/git-lfs"] = true
            files["/xpkgs/git-lfs/3.8.1/README.md"] = true
        end
    end,
}
assert(install())
assert(installed())
assert(#execs == 3)
assert(execs[2] == 'tar -xf "/cache/git-lfs-darwin-amd64-v3.8.1.zip" --strip-components=1 -C "/xpkgs/git-lfs/3.8.1"')
assert(execs[3] == 'chmod +x "/xpkgs/git-lfs/3.8.1/git-lfs"')

-- Case 5: Windows .zip via libs/payload.lua (System32\\tar.exe)
files, dirs, moved, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}, {}
pkginfo.install_file = function() return "C:/cache/git-lfs-windows-amd64-v3.8.1.zip" end
pkginfo.install_dir = function() return "C:/xpkgs/git-lfs/3.8.1" end
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or (k == "OS" and "Windows_NT" or nil) end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/git-lfs/3.8.1/git-lfs.exe"] = true
        files["C:/xpkgs/git-lfs/3.8.1/README.md"] = true
    end,
}
assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\git-lfs-windows-amd64-v3.8.1.zip" --strip-components=1 -C "C:\\\\xpkgs\\\\git-lfs\\\\3.8.1"')
assert(installed())

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "git-lfs" and xvm_adds[1][2].bindir == "C:/xpkgs/git-lfs/3.8.1")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "git-lfs")
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
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    def _shim_path(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("git-lfs" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        shim = str(self._shim_path())
        proc = subprocess.run(
            [shim, "version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=15,
        )
        assert f"git-lfs/{expected}" in (proc.stdout + proc.stderr), proc.stdout + proc.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help(self):
        shim = str(self._shim_path())
        proc = subprocess.run(
            [shim, "--help"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=15,
        )
        assert "git lfs" in (proc.stdout + proc.stderr), proc.stdout + proc.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = "current" if (Path(xlings_home()) / "subos" / "current").exists() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos_dir)
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        if (Path(xlings_home()) / "subos" / "current").exists():
            assert_xvm_shim_exists(PKG)
        else:
            self._shim_path()
