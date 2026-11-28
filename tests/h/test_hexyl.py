"""Tests for the hexyl package (`hexyl` CLI)."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

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

PKG = "hexyl"
PKG_FILE = "pkgs/h/hexyl.lua"
VERSION = "0.17.0"


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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["hexyl"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])

assert(package.spec == "2", "spec must be 2")
assert(package.name == "hexyl")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "hexyl")

local expected_assets = {
    linux = {
        x86_64  = "hexyl-v''' + VERSION + '''-x86_64-unknown-linux-musl.tar.gz",
        aarch64 = "hexyl-v''' + VERSION + '''-aarch64-unknown-linux-gnu.tar.gz",
    },
    macosx = {
        x86_64  = "hexyl-v''' + VERSION + '''-x86_64-apple-darwin.tar.gz",
        aarch64 = "hexyl-v''' + VERSION + '''-aarch64-apple-darwin.tar.gz",
    },
    windows = {
        x86_64  = "hexyl-v''' + VERSION + '''-x86_64-pc-windows-msvc.zip",
    },
}

local linux_deps = assert(package.xpm.linux.deps and package.xpm.linux.deps.runtime)
assert(#linux_deps == 2 and linux_deps[1] == "xim:glibc" and linux_deps[2] == "xim:gcc-runtime")
local win_deps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(#win_deps == 1 and win_deps[1] == "xim:vcruntime", "windows must declare xim:vcruntime")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/sharkdp/hexyl/releases")
local global_au = assert(au.resources and au.resources.GLOBAL)
assert(global_au.required == true)
local url_map = assert(global_au.url)

for plat, arches in pairs(expected_assets) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == "''' + VERSION + '''", plat .. " latest should be ''' + VERSION + '''")
    for arch, asset in pairs(arches) do
        local entry = assert(p[ref] and p[ref][arch], "missing arch " .. arch .. " for " .. plat)
        local expected_url = "https://github.com/sharkdp/hexyl/releases/download/v''' + VERSION + '''/" .. asset
        assert(entry.url == expected_url, plat .. "/" .. arch .. " url mismatch: " .. tostring(entry.url))
        assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"),
               plat .. "/" .. arch .. " invalid sha256")
        local tmpl = assert(url_map[plat] and url_map[plat][arch],
                            "missing autoupdate template for " .. plat .. "/" .. arch)
        assert(tmpl:gsub("${tag}", "v''' + VERSION + '''"):gsub("${version}", "''' + VERSION + '''") == expected_url,
               "autoupdate template mismatch for " .. plat .. "/" .. arch)
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_all_five_sha256_unique(self, meta):
        sha_matches = re.findall(r'sha256\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
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
        return files[1] == "hexyl.exe"
    end,
}
assert(installed() == true)
assert(calls[1] == "hexyl" and calls[2] == "hexyl.exe")
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
    install_file = function() return "/cache/hexyl-v''' + VERSION + '''-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/hexyl/''' + VERSION + '''" end,
    dep_install_dir = function() return nil end,
}
payload = {
    unpack = function(opts) table.insert(unpacked, opts) end,
    require = function(files) table.insert(required, files[1]) end,
}
fs = { files = function() return {} end }
os.cp = function(s, d) table.insert(copied, {s, d}) end

assert(install())
assert(unpacked[1].extracted == "hexyl-v''' + VERSION + '''-x86_64-unknown-linux-musl" and unpacked[1].strip == 1)
assert(required[1] == "hexyl")
assert(#copied == 0)

-- 2. Windows zip unpack + xim:vcruntime app-local DLL copy
unpacked, required, copied = {}, {}, {}
pkginfo = {
    install_file = function() return "C:\\\\cache\\\\hexyl-v''' + VERSION + '''-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/hexyl/''' + VERSION + '''" end,
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
assert(unpacked[1].extracted == "hexyl-v''' + VERSION + '''-x86_64-pc-windows-msvc" and unpacked[1].strip == 1)
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/hexyl/''' + VERSION + '''")
assert(required[1] == "hexyl.exe")
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
assert(#adds == 1 and adds[1][1] == "hexyl" and adds[1][2].bindir == "/pkg")

assert(uninstall())
assert(#rms == 1 and rms[1] == "hexyl")
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
    def _run_hexyl(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("hexyl" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        res = self._run_hexyl("--version")
        assert res.returncode == 0, res.stdout + res.stderr
        assert f"hexyl {expected}" in res.stdout, res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("hexyl")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_hexdump_file(self):
        with tempfile.TemporaryDirectory() as work:
            sample = Path(work) / "sample.bin"
            sample.write_bytes(b"hello\n")
            res = self._run_hexyl("--color=never", str(sample))
            assert res.returncode == 0, res.stdout + res.stderr
            assert "68 65 6c 6c 6f 0a" in res.stdout, res.stdout
            assert "hello" in res.stdout, res.stdout
