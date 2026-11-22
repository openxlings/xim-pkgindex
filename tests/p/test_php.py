"""php"""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "php"
PKG_FILE = "pkgs/p/php.lua"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


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
    def test_all_platforms_and_sha256_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local expected = {
    linux = {
        arches = {"x86_64", "aarch64"},
        aliases = {
            latest = "8.5.12",
            ["8.5"] = "8.5.12",
            ["8.4"] = "8.4.27",
            ["8.3"] = "8.3.36",
            ["8.2"] = "8.2.35",
            ["8.1"] = "8.1.34",
            ["8.0"] = "8.0.30",
        },
        versions = {"8.5.12", "8.4.27", "8.3.36", "8.2.35", "8.1.34", "8.0.30"},
    },
    macosx = {
        arches = {"x86_64", "aarch64"},
        aliases = {
            latest = "8.5.12",
            ["8.5"] = "8.5.12",
            ["8.4"] = "8.4.27",
            ["8.3"] = "8.3.36",
            ["8.2"] = "8.2.35",
            ["8.1"] = "8.1.34",
            ["8.0"] = "8.0.30",
        },
        versions = {"8.5.12", "8.4.27", "8.3.36", "8.2.35", "8.1.34", "8.0.30"},
    },
    windows = {
        arches = {"x86_64"},
        aliases = {
            latest = "8.5.12",
            ["8.5"] = "8.5.12",
            ["8.4"] = "8.4.27",
            ["8.3"] = "8.3.36",
            ["8.2"] = "8.2.35",
            ["8.1"] = "8.1.34",
            ["8.0"] = "8.0.30",
            ["7.4"] = "7.4.33",
        },
        versions = {"8.5.12", "8.4.27", "8.3.36", "8.2.35", "8.1.34", "8.0.30", "7.4.33"},
    },
}
for plat, spec in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    for alias, target in pairs(spec.aliases) do
        assert(p[alias] and p[alias].ref == target,
            plat .. " alias " .. alias .. " expected ref " .. target)
    end
    for _, ver in ipairs(spec.versions) do
        local v = assert(p[ver], "missing version " .. ver .. " on " .. plat)
        for _, arch in ipairs(spec.arches) do
            local r = assert(v[arch], "missing " .. plat .. "/" .. arch .. "@" .. ver)
            assert(type(r.url) == "string" and r.url:find("php%-" .. ver, 1, false),
                "unexpected url for " .. plat .. "/" .. arch .. "@" .. ver)
            assert(type(r.sha256) == "string" and #r.sha256 == 64 and r.sha256:match("^%x+$"),
                "invalid sha256 for " .. plat .. "/" .. arch .. "@" .. ver)
        end
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_checks_binary(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = "8.5.12"
pkginfo = {
    install_dir = function() return "/pkg" end,
    version = function() return ver end,
}
local present = {}
os.isfile = function(p) return present[p] == true end
assert(not installed())
present["/pkg/php"] = true
assert(installed())
present["/pkg/php"] = nil
present["/pkg/php.exe"] = true
assert(installed())

ver = "7.4.33"
assert(not installed(), "7.4.33 requires php7.dll alongside php.exe")
present["/pkg/php7.dll"] = true
assert(installed())
''', PKG_FILE)

    @pytest.mark.static
    def test_install_routes_static_and_win_vc15(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local present, moved, execs = {}, {}, {}
local cur_ver, cur_file, cur_dir = "8.4.27", "/tmp/php-8.4.27-1-cli-linux-x86_64.tar.gz", "/pkg/8.4.27"
pkginfo = {
    version = function() return cur_ver end,
    install_file = function() return cur_file end,
    install_dir = function() return cur_dir end,
}
fs = { mkdir_p = function() end }
os.tryrm = function() end
os.isfile = function(p) return present[p] == true end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    present[dst] = true
end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("tar%.exe") then
            present[cur_dir .. "/php.exe"] = true
            present[cur_dir .. "/php7.dll"] = true
        end
    end,
}

assert(install())
assert(moved[1][1] == "/tmp/php" and moved[1][2] == "/pkg/8.4.27/php")
assert(execs[1] == 'chmod +x "/pkg/8.4.27/php"')

moved, execs = {}, {}
cur_ver = "7.4.33"
cur_file = "C:/cache/php-7.4.33-nts-Win32-vc15-x64.zip"
cur_dir = "C:/install/7.4.33"
assert(install())
assert(#moved == 0)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\php%-7%.4%.33%-nts%-Win32%-vc15%-x64%.zip" %-C "C:\\\\install\\\\7%.4%.33"$'))
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
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
            "xim.libxpkg.system", "xim.libxpkg.xvm",
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
        assert_command_output("php -v", contains="PHP 8.5.12")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_eval_script(self):
        assert_command_output("php -r 'echo 6 * 7 . \"\\n\";'", contains="42")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("php")
