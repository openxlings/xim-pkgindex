"""Tests for the sd package (`sd` CLI)."""
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

PKG = "sd"
PKG_FILE = "pkgs/s/sd.lua"
VERSION = "1.1.0"


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
    def test_all_platforms_and_arches_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["sd"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])

assert(package.spec == "2")
assert(package.name == "sd")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)

assert(package.xpm.linux.deps == nil, "static musl linux binaries need no runtime deps")
local wdeps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/chmln/sd/releases")
local global_au = assert(auto.resources and auto.resources.GLOBAL)
assert(global_au.required == true)
local global_url = assert(global_au.url)

local expected = {
    linux = {
        x86_64 = "sd-v1.1.0-x86_64-unknown-linux-musl.tar.gz",
        aarch64 = "sd-v1.1.0-aarch64-unknown-linux-musl.tar.gz",
    },
    macosx = {
        x86_64 = "sd-v1.1.0-x86_64-apple-darwin.tar.gz",
        aarch64 = "sd-v1.1.0-aarch64-apple-darwin.tar.gz",
    },
    windows = {
        x86_64 = "sd-v1.1.0-x86_64-pc-windows-msvc.zip",
    },
}

for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(type(section.source) == "string" and section.source:find("${version}", 1, true))
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    assert(ver.sha256, "missing sha256 table in " .. plat)
    for arch, asset in pairs(arches) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch],
                           "missing autoupdate url for " .. plat .. "/" .. arch)
        local expanded = tpl:gsub("${tag}", "v''' + VERSION + '''"):gsub("${version}", "''' + VERSION + '''")
        assert(expanded == "https://github.com/chmln/sd/releases/download/v''' + VERSION + '''/" .. asset,
               "autoupdate url mismatch for " .. plat .. "/" .. arch .. ": " .. expanded)
    end
end
assert(package.xpm.linux["''' + VERSION + '''"].arch_alias.x86_64 == "x86_64-unknown-linux-musl")
assert(package.xpm.linux["''' + VERSION + '''"].arch_alias.aarch64 == "aarch64-unknown-linux-musl")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_all_five_sha256_unique(self, meta):
        sha_matches = re.findall(r'(?:x86_64|aarch64)\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(sha_matches) == 5
        assert len(set(sha_matches)) == 5

    @pytest.mark.static
    def test_installed_checks_binary(self):
        _run_lua(
            '''
local calls = {}
import = function() end
dofile(arg[1])
payload = {
    present = function(files)
        table.insert(calls, files[1])
        return files[1] == "sd.exe"
    end,
}
assert(installed() == true)
assert(calls[1] == "sd" and calls[2] == "sd.exe")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_install_unpacks_and_copies_vcruntime_on_windows(self):
        _run_lua(
            '''
import = function() end
dofile(arg[1])

-- 1. Linux tarball unpack
local unpacked, required, copied = {}, {}, {}
pkginfo = {
    install_file = function() return "/cache/sd-v1.1.0-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/sd/1.1.0" end,
    dep_install_dir = function() return nil end,
}
payload = {
    unpack = function(opts) table.insert(unpacked, opts) end,
    require = function(files) table.insert(required, files[1]) end,
}
fs = { files = function() return {} end }
os.cp = function(s, d) table.insert(copied, {s, d}) end

assert(install())
assert(unpacked[1].extracted == "sd-v1.1.0-x86_64-unknown-linux-musl" and unpacked[1].strip == 1)
assert(required[1] == "sd")
assert(#copied == 0)

-- 2. Windows zip unpack + xim:vcruntime app-local DLL copy
unpacked, required, copied = {}, {}, {}
pkginfo = {
    install_file = function() return "C:\\\\cache\\\\sd-v1.1.0-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/sd/1.1.0" end,
    dep_install_dir = function(name)
        assert(name == "xim:vcruntime")
        return "C:/xpkgs/xim-x-vcruntime/14.44.35211"
    end,
}
fs = {
    files = function(dir)
        assert(dir == "C:/xpkgs/xim-x-vcruntime/14.44.35211/bin")
        return {
            "C:/xpkgs/xim-x-vcruntime/14.44.35211/bin/vcruntime140.dll",
            "C:/xpkgs/xim-x-vcruntime/14.44.35211/bin/msvcp140.dll",
        }
    end,
}
assert(install())
assert(unpacked[1].extracted == "sd-v1.1.0-x86_64-pc-windows-msvc" and unpacked[1].strip == 1)
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/sd/1.1.0")
assert(required[1] == "sd.exe")
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
assert(#adds == 1 and adds[1][1] == "sd" and adds[1][2].bindir == "/pkg")

assert(uninstall())
assert(#rms == 1 and rms[1] == "sd")
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
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    def _run_sd(self, *args, input_text=None):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("sd" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return subprocess.run(
            [str(shim), *args],
            input=input_text,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        res = self._run_sd("--version")
        assert res.returncode == 0, res.stdout + res.stderr
        # Upstream v1.1.0 release binary reports `sd 1.0.0`.
        assert res.stdout.strip().startswith("sd "), res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("sd")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_replaces_stdin(self):
        res = self._run_sd("world", "xlings", input_text="hello world\n")
        assert res.returncode == 0, res.stdout + res.stderr
        assert res.stdout == "hello xlings\n", res.stdout

        res_regex = self._run_sd(r"(\w+)-(\d+)", "$2:$1", input_text="item-42\n")
        assert res_regex.returncode == 0, res_regex.stdout + res_regex.stderr
        assert res_regex.stdout == "42:item\n", res_regex.stdout
