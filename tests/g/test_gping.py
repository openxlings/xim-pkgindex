"""Tests for the gping package."""
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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "gping"
PKG_FILE = "pkgs/g/gping.lua"
VERSION = "1.21.0"
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
    def test_platforms_arches_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["gping"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "gping")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "gping")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/orf/gping/releases")
assert(auto.tag == "gping-v${version}")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

assert(not package.xpm.linux.deps, "static musl linux binaries need no runtime deps")
assert(not package.xpm.macosx.deps, "macosx binaries need no runtime deps")
local wdeps = package.xpm.windows.deps and package.xpm.windows.deps.runtime or {}
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime")

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}

local seen_hashes = {}
local count = 0
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    local arch_set = {}
    for _, arch in ipairs(arches) do
        arch_set[arch] = true
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(not seen_hashes[h], "duplicate sha256 for " .. plat .. "/" .. arch)
        seen_hashes[h] = true
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        local tag = auto.tag:gsub("%${version}", "''' + VERSION + '''")
        local resolved_au = tmpl:gsub("%${tag}", tag):gsub("%${version}", "''' + VERSION + '''")
        local alias = (ver.arch_alias and ver.arch_alias[arch]) or arch
        local resolved_xpm = section.source
            :gsub("%${version}", "''' + VERSION + '''")
            :gsub("%${arch_alias}", alias)
            :gsub("%${arch}", arch)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(ver.sha256) do
        assert(arch_set[arch], "unexpected arch " .. arch .. " in " .. plat)
    end
end
assert(count == 5)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_posix_tar_and_fallback(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "gping" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "/cache/gping-Linux-musl-x86_64.tar.gz" end,
    install_dir = function() return "/xpkgs/gping/''' + VERSION + '''" end,
}
files["/cache/gping-Linux-musl-x86_64.tar.gz"] = true
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
        if cmd:match("^'tar' '%-xzf'") then
            files["/xpkgs/gping/''' + VERSION + '''/gping"] = true
        end
    end,
}
shell = assert(loadfile("libs/shell.lua"))()
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

dofile(arg[1])

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == "'tar' '-xzf' '/cache/gping-Linux-musl-x86_64.tar.gz' '-C' '/xpkgs/gping/''' + VERSION + ''''")
assert(execs[2] == "'chmod' '+x' '/xpkgs/gping/''' + VERSION + '''/gping'")
assert(installed())

files["/xpkgs/gping/''' + VERSION + '''/gping"] = nil
assert(not installed(), "accepted missing gping binary")

-- Pre-extracted fallback when framework already unpacked archive beside install_file
files = { ["/cache/gping"] = true, ["/cache/gping.1"] = true }
execs = {}
assert(install())
assert(#execs == 1)
assert(execs[1] == "'chmod' '+x' '/xpkgs/gping/''' + VERSION + '''/gping'")
assert(files["/xpkgs/gping/''' + VERSION + '''/gping"] == true)
assert(files["/xpkgs/gping/''' + VERSION + '''/gping.1"] == true)
assert(installed())

assert(config())
assert(#adds == 1 and adds[1][1] == "gping" and adds[1][2].bindir == "/xpkgs/gping/''' + VERSION + '''")
assert(uninstall())
assert(#rms == 1 and rms[1] == "gping")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_windows_zip_and_vcruntime_copy(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
local files, dirs, execs, copied, adds, rms = {}, {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "gping" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "C:/cache/gping-Windows-msvc-x86_64.zip" end,
    install_dir = function() return "C:/xpkgs/gping/''' + VERSION + '''" end,
    dep_install_dir = function(dep)
        assert(dep == "xim:vcruntime")
        return "C:/xpkgs/vcruntime/14.44.35211"
    end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.cp = function(src, dst) table.insert(copied, {src, dst}) end
log = { info = function() end }
fs = {
    mkdir_p = function(p) dirs[p] = true end,
    files = function(d)
        assert(d == "C:/xpkgs/vcruntime/14.44.35211/bin")
        return { d .. "/vcruntime140.dll", d .. "/msvcp140.dll" }
    end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/gping/''' + VERSION + '''/gping.exe"] = true
    end,
}
shell = assert(loadfile("libs/shell.lua"))()
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

dofile(arg[1])

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\gping-Windows-msvc-x86_64.zip" -C "C:\\\\xpkgs\\\\gping\\\\''' + VERSION + '''"')
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/gping/''' + VERSION + '''")
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "gping" and adds[1][2].bindir == "C:/xpkgs/gping/''' + VERSION + '''")
assert(uninstall())
assert(#rms == 1 and rms[1] == "gping")
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
        assert_install_succeeds(under_test(PKG), timeout=180)


class TestVerify:
    def _shim_path(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("gping" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_gping(self, *args):
        result = subprocess.run(
            [str(self._shim_path()), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            stdin=subprocess.DEVNULL,
            timeout=15,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        out = self._run_gping("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert f"gping {expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_non_blocking(self):
        out = self._run_gping("--help")
        assert "Ping, but with a graph." in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_short_help_and_invalid_flag_non_blocking(self):
        short_out = self._run_gping("-h")
        assert "Usage: gping" in short_out, short_out
        bad = subprocess.run(
            [str(self._shim_path()), "--nonexistent-flag"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            stdin=subprocess.DEVNULL,
            timeout=5,
        )
        assert bad.returncode != 0
        assert "unexpected argument" in (bad.stdout + bad.stderr), bad.stdout + bad.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos_name = "current" if (subos_dir / "current").is_dir() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos_name)
        assert_xvm_registered("gping")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists("gping")
