"""composer"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

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

PKG = "composer"
PKG_FILE = "pkgs/c/composer.lua"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


def _latest():
    """the version the xpkg's `latest` points to (every platform must agree)"""
    with open(PKG_FILE, encoding="utf-8") as f:
        code = "\n".join(l for l in f.read().splitlines() if not l.lstrip().startswith("--"))
    refs = set(re.findall(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"\s*\}', code))
    assert len(refs) == 1, f"latest points to several versions: {sorted(refs)}"
    return refs.pop()


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
    def test_platforms_deps_and_sha256_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local sha = nil
for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.deps and p.deps.runtime and p.deps.runtime[1] == "xim:php@>=8.0",
           plat .. " must depend on xim:php@>=8.0")
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == arg[2])
    local entry = assert(p[ref], "missing version entry for " .. plat)
    assert(type(entry.url) == "string" and entry.url:find("composer/releases/download/" .. ref .. "/composer.phar", 1, false))
    assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"))
    if sha then assert(entry.sha256 == sha) else sha = entry.sha256 end
end
''', PKG_FILE, _latest())

    @pytest.mark.static
    def test_installed_requires_phar_and_launcher(self):
        _run_lua('''
import = function() end
dofile(arg[1])
pkginfo = { install_dir = function() return "/pkg" end }
local present = {}
os.isfile = function(p) return present[p] == true end

assert(not installed())
present["/pkg/composer.phar"] = true
assert(not installed(), "phar alone without launcher must fail installed()")

present["/pkg/bin/composer"] = true
assert(installed())

present["/pkg/bin/composer"] = nil
present["/pkg/bin/composer.bat"] = true
assert(installed())
''', PKG_FILE)

    @pytest.mark.static
    def test_install_generates_posix_and_windows_launchers(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            phar_src = root / "download" / "composer.phar"
            phar_src.parent.mkdir(parents=True)
            phar_src.write_bytes(b"#!/usr/bin/env php\n<?php echo 'ok';\n")

            php_posix = root / "php-posix"
            php_posix.mkdir()
            (php_posix / "php").write_text("#!/bin/sh\n")

            php_win = root / "php-win"
            php_win.mkdir()
            (php_win / "php.exe").write_bytes(b"MZ")

            posix_dir = root / "out-posix"
            win_dir = root / "out-win"

            _run_lua('''
import = function() end
dofile(arg[1])
local phar_src, posix_dir, php_posix, win_dir, php_win = arg[2], arg[3], arg[4], arg[5], arg[6]

local function real_isfile(p)
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end
os.isfile = real_isfile
os.tryrm = function() end
fs = {
    mkdir_p = function(d)
        assert(os.execute(string.format('mkdir -p "%s"', d)))
    end,
}
os.cp = function(src, dst)
    assert(os.execute(string.format('cp "%s" "%s"', src, dst)))
end

-- POSIX install
local execs = {}
pkginfo = {
    install_file = function() return phar_src end,
    install_dir = function() return posix_dir end,
    dep_install_dir = function(dep)
        assert(dep == "xim:php")
        return php_posix
    end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        assert(os.execute(cmd))
    end,
}
assert(install())
assert(#execs == 2)
assert(execs[1]:find("chmod %+x"))
assert(execs[2]:find("bash %-n"))

-- Windows install (emulated via php.exe presence)
pkginfo = {
    install_file = function() return phar_src end,
    install_dir = function() return win_dir end,
    resolved_dep = function(dep)
        assert(dep == "xim:php")
        return { install_dir = php_win }
    end,
}
assert(install())
''', PKG_FILE, str(phar_src), str(posix_dir), str(php_posix), str(win_dir), str(php_win))

            posix_launcher = (posix_dir / "bin" / "composer").read_text(encoding="utf-8")
            assert f'PHP_HOME="{php_posix}"' in posix_launcher
            assert str(posix_dir / "composer.phar") in posix_launcher
            subprocess.run(["bash", "-n", str(posix_dir / "bin" / "composer")], check=True)

            win_bytes = (win_dir / "bin" / "composer.bat").read_bytes()
            assert b"\r\n" in win_bytes
            win_text = win_bytes.decode("utf-8")
            win_php_expected = str(php_win).replace("/", "\\")
            assert f'set "COMPOSER_PHP={win_php_expected}\\php.exe"' in win_text
            assert str(win_dir / "composer.phar").replace("/", "\\") in win_text

    @pytest.mark.static
    def test_config_and_uninstall(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local files, adds, rms = {}, {}, {}
pkginfo = { install_dir = function() return "/pkg" end }
os.isfile = function(p) return files[p] == true end
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(config())
assert(#adds == 1 and adds[1][1] == "composer" and adds[1][2].bindir == "/pkg/bin" and adds[1][2].filename == nil)

files["/pkg/bin/composer.bat"] = true
adds = {}
assert(config())
assert(#adds == 1 and adds[1][1] == "composer" and adds[1][2].bindir == "/pkg/bin" and adds[1][2].filename == "composer.bat")

assert(uninstall())
assert(#rms == 1 and rms[1] == "composer")
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
        assert_command_output("composer --version", contains=f"Composer version {_latest()}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("composer")
