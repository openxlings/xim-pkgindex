"""Tests for the skeema package."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_command_output,
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

PKG = "skeema"
PKG_FILE = "pkgs/s/skeema.lua"
VERSION = "1.14.2"
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
    def test_all_platforms_and_arches_pinned_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx"}
        _run_lua(
            '''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.spec == "2")
assert(package.name == "skeema")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "skeema")
assert(package.xpm.windows == nil, "skeema should not define xpm.windows")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/skeema/skeema/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)
assert(global_url.windows == nil, "autoupdate should not define windows")

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
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
        assert(auto_tpl:find("${version}", 1, true), "autoupdate must use ${version}: " .. plat .. "/" .. arch)
        local auto_resolved = auto_tpl:gsub("%${tag}", "v" .. ver):gsub("%${version}", ver)
        local xpm_resolved = p.source:gsub("%${version}", ver):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved, "installer/updater URLs disagree for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 4)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local ver = arg[2]

local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "skeema" end,
    version = function() return ver end,
    install_file = function() return "/cache/skeema_" .. ver .. "_linux_amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/skeema/" .. ver end,
}
os.host = function() return "linux" end
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
            files["/xpkgs/skeema/" .. ver .. "/skeema"] = true
            files["/xpkgs/skeema/" .. ver .. "/LICENSE"] = true
            files["/xpkgs/skeema/" .. ver .. "/README.md"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

files["/cache/skeema_" .. ver .. "_linux_amd64.tar.gz"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'tar -xf "/cache/skeema_' .. ver .. '_linux_amd64.tar.gz" -C "/xpkgs/skeema/' .. ver .. '"')
assert(execs[2] == 'chmod +x "/xpkgs/skeema/' .. ver .. '/skeema"')

files["/xpkgs/skeema/" .. ver .. "/skeema"] = nil
assert(not installed(), "accepted missing skeema binary")
files["/xpkgs/skeema/" .. ver .. "/skeema"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "skeema" and adds[1][2].bindir == "/xpkgs/skeema/" .. ver)
assert(uninstall())
assert(#rms == 1 and rms[1] == "skeema")
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
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    def _skeema_bin(self) -> str:
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / "skeema"
        if shim.is_file():
            return str(shim)
        found = shutil.which("skeema")
        assert found, f"Missing installed skeema shim at {shim} or in PATH"
        return found

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output(f'"{self._skeema_bin()}" --version', contains=expected)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = "current" if (Path(xlings_home()) / "subos" / "current").is_dir() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered("skeema")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_and_version_offline(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output(f'"{self._skeema_bin()}" version', contains=expected)
        assert_command_output(f'"{self._skeema_bin()}" help lint', contains="Usage:")
