"""act"""
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
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_command_output,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "act"
PKG_FILE = "pkgs/a/act.lua"


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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
dofile(arg[1])

assert(package.spec == "2", "spec must be 2")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "act")

local expected_assets = {
    linux = {
        x86_64  = "act_Linux_x86_64.tar.gz",
        aarch64 = "act_Linux_arm64.tar.gz",
    },
    macosx = {
        x86_64  = "act_Darwin_x86_64.tar.gz",
        aarch64 = "act_Darwin_arm64.tar.gz",
    },
    windows = {
        x86_64  = "act_Windows_x86_64.zip",
        aarch64 = "act_Windows_arm64.zip",
    },
}

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/nektos/act/releases")
local global_au = assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.url)
assert(au.resources.GLOBAL.required == true)

for plat, arches in pairs(expected_assets) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == "0.2.99", plat .. " latest should be 0.2.99")
    local ver = assert(p[ref], "missing version entry in " .. plat)
    assert(ver.arch_alias and ver.arch_alias.x86_64 == "x86_64" and ver.arch_alias.aarch64 == "arm64")
    assert(ver.sha256)
    for arch, asset in pairs(arches) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local expanded = p.source:gsub("%${version}", ref):gsub("%${arch_alias}", ver.arch_alias[arch])
        local expected_url = "https://github.com/nektos/act/releases/download/v0.2.99/" .. asset
        assert(expanded == expected_url, plat .. "/" .. arch .. " source mismatch: " .. expanded)
        local tmpl = assert(global_au[plat] and global_au[plat][arch],
                            "missing autoupdate template for " .. plat .. "/" .. arch)
        assert(tmpl:gsub("%${version}", ref) == expected_url,
               "autoupdate template mismatch for " .. plat .. "/" .. arch)
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_installed_checks_binary(self):
        _run_lua(
            '''
import = function() end
dofile(arg[1])
pkginfo = { install_dir = function() return "/pkg" end }
local present = {}
os.isfile = function(p) return present[p] == true end

assert(not installed())
present["/pkg/act"] = true
assert(installed())

present = {}
present["/pkg/act.exe"] = true
assert(installed())
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_install_handles_preextracted_and_zip_fallback(self):
        _run_lua(
            '''
import = function() end
dofile(arg[1])
winpath = { native = function(p) return (tostring(p):gsub("/", "\\\\")) end }

-- 1. Pre-extracted POSIX binary moved from download_dir to install_dir + chmod +x
local files, moved, chmods = {}, {}, {}
pkginfo = {
    install_file = function() return "/cache/act_Linux_x86_64.tar.gz" end,
    install_dir = function() return "/xpkgs/act/0.2.99" end,
}
files["/cache/act"] = true
files["/cache/LICENSE"] = true
fs = { mkdir_p = function() end }
os.tryrm = function() end
os.isfile = function(p) return files[p] == true end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    files[src] = nil
    files[dst] = true
end
system = { exec = function(cmd) table.insert(chmods, cmd) end }

assert(install())
assert(#moved == 2)
assert(moved[1][1] == "/cache/act" and moved[1][2] == "/xpkgs/act/0.2.99/act")
assert(moved[2][1] == "/cache/LICENSE" and moved[2][2] == "/xpkgs/act/0.2.99/LICENSE")
assert(#chmods == 1 and chmods[1]:find("chmod %+x"))

-- 2. Windows zip fallback via System32\\tar.exe when zip is not pre-extracted
files, moved = {}, {}
local execs = {}
pkginfo = {
    install_file = function() return "C:\\\\cache\\\\act_Windows_x86_64.zip" end,
    install_dir = function() return "C:\\\\xpkgs\\\\act\\\\0.2.99" end,
}
files["C:\\\\cache\\\\act_Windows_x86_64.zip"] = true
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:\\\\xpkgs\\\\act\\\\0.2.99/act.exe"] = true
    end,
}
assert(install())
assert(#execs == 1 and execs[1]:find("System32\\\\tar%.exe", 1, false))
assert(installed())

-- 3. Pre-extracted Windows binary moved directly without invoking tar.exe
files, moved, execs = {}, {}, {}
files["C:/cache/act.exe"] = true
assert(install())
assert(#execs == 0)
assert(#moved == 1 and moved[1][1] == "C:/cache/act.exe" and moved[1][2] == "C:\\\\xpkgs\\\\act\\\\0.2.99/act.exe")

-- 4. Missing both pre-extracted binary and archive must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither extracted binary nor archive exists")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_config_and_uninstall(self):
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local adds, rms = {}, {}
pkginfo = { install_dir = function() return "/pkg" end }
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(config())
assert(#adds == 1 and adds[1][1] == "act" and adds[1][2].bindir == "/pkg")

assert(uninstall())
assert(#rms == 1 and rms[1] == "act")
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
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "0.2.99")
        assert_command_output("act --version", contains=f"act version {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("act")
