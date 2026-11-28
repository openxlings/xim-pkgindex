"""Tests for the pocketbase package."""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_command_output,
    assert_config_registers_package_name,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_xim_add_succeeds,
    assert_xvm_registered,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "pocketbase"
PKG_FILE = "pkgs/p/pocketbase.lua"
VERSION = "0.40.6"
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
    def test_resource_architecture_mapping_and_autoupdate(self):
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "pocketbase")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/pocketbase/pocketbase/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    assert(not p.deps, "static/self-contained binary should not declare runtime deps on " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == "0.40.6")
    local entry = assert(p[version], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), platform .. "/" .. arch)
        local auto = au.resources.GLOBAL.url[platform][arch]
        assert(auto:find("${tag}", 1, true) and auto:find("${version}", 1, true),
               "autoupdate template must use ${tag} and ${version}: " .. platform .. "/" .. arch)
        local auto_resolved = auto:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local xpm_resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved,
               "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_install_config_uninstall_posix_and_windows(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX install with pre-extracted flat .zip beside archive
local files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "pocketbase" end,
    version = function() return "0.40.6" end,
    install_file = function() return "/cache/pocketbase_0.40.6_linux_amd64.zip" end,
    install_dir = function() return "/xpkgs/pocketbase/0.40.6" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(mvs, {src, dst})
    files[src] = nil
    files[dst] = true
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

assert(not installed())
files["/cache/pocketbase"] = true
files["/cache/LICENSE.md"] = true
files["/cache/CHANGELOG.md"] = true
assert(install())
assert(installed())
assert(#mvs == 3)
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/pocketbase/0.40.6/pocketbase"')
assert(config())
assert(#adds == 1 and adds[1][1] == "pocketbase" and adds[1][2].bindir == "/xpkgs/pocketbase/0.40.6")
assert(uninstall())
assert(#rms == 1 and rms[1] == "pocketbase")

-- Case 2: POSIX install fallback when .zip is not pre-extracted (unzip -q -o)
files, dirs, mvs, execs = {}, {}, {}, {}
files["/cache/pocketbase_0.40.6_linux_amd64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^unzip ") then
            files["/xpkgs/pocketbase/0.40.6/pocketbase"] = true
            files["/xpkgs/pocketbase/0.40.6/LICENSE.md"] = true
        end
    end,
}
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'unzip -q -o "/cache/pocketbase_0.40.6_linux_amd64.zip" -d "/xpkgs/pocketbase/0.40.6"')
assert(execs[2] == 'chmod +x "/xpkgs/pocketbase/0.40.6/pocketbase"')

-- Case 3: Windows install via libs/payload.lua (.zip -> System32\\tar.exe)
files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "pocketbase" end,
    version = function() return "0.40.6" end,
    install_file = function() return "C:/cache/pocketbase_0.40.6_windows_amd64.zip" end,
    install_dir = function() return "C:/xpkgs/pocketbase/0.40.6" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/pocketbase/0.40.6/pocketbase.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\pocketbase_0.40.6_windows_amd64.zip" -C "C:\\\\xpkgs\\\\pocketbase\\\\0.40.6"')
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
    def test_portable_lua_and_libxpkg_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
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
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("pocketbase --version", contains="0.40.6")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help(self):
        assert_command_output("pocketbase --help", contains="serve")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists(PKG)
