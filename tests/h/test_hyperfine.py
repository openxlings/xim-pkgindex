"""hyperfine"""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_valid_xvm_node_kinds,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "hyperfine"
PKG_FILE = "pkgs/h/hyperfine.lua"


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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])

assert(package.spec == "2", "spec must be 2")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "hyperfine")

local expected_assets = {
    linux = {
        x86_64  = "hyperfine-v2.0.0-x86_64-unknown-linux-musl.tar.gz",
        aarch64 = "hyperfine-v2.0.0-aarch64-unknown-linux-musl.tar.gz",
    },
    macosx = {
        x86_64  = "hyperfine-v2.0.0-x86_64-apple-darwin.tar.gz",
        aarch64 = "hyperfine-v2.0.0-aarch64-apple-darwin.tar.gz",
    },
    windows = {
        x86_64  = "hyperfine-v2.0.0-x86_64-pc-windows-msvc.zip",
    },
}

assert(package.xpm.linux.deps == nil, "static musl linux binaries need no runtime deps")
local win_deps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(#win_deps == 1 and win_deps[1] == "xim:vcruntime", "windows must declare xim:vcruntime")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/sharkdp/hyperfine/releases")
local global_au = assert(au.resources and au.resources.GLOBAL)
assert(global_au.required == true)
local url_map = assert(global_au.url)

for plat, arches in pairs(expected_assets) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == "2.0.0", plat .. " latest should be 2.0.0")
    for arch, asset in pairs(arches) do
        local entry = assert(p[ref] and p[ref][arch], "missing arch " .. arch .. " for " .. plat)
        local expected_url = "https://github.com/sharkdp/hyperfine/releases/download/v2.0.0/" .. asset
        assert(entry.url == expected_url, plat .. "/" .. arch .. " url mismatch: " .. tostring(entry.url))
        assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"),
               plat .. "/" .. arch .. " invalid sha256")
        local tmpl = assert(url_map[plat] and url_map[plat][arch],
                            "missing autoupdate template for " .. plat .. "/" .. arch)
        assert(tmpl:gsub("${tag}", "v2.0.0"):gsub("${version}", "2.0.0") == expected_url,
               "autoupdate template mismatch for " .. plat .. "/" .. arch)
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_checks_binary(self):
        _run_lua('''
local calls = {}
import = function() end
dofile(arg[1])
payload = {
    present = function(files)
        table.insert(calls, files[1])
        return files[1] == "hyperfine.exe"
    end,
}
assert(installed() == true)
assert(calls[1] == "hyperfine" and calls[2] == "hyperfine.exe")
''', PKG_FILE)

    @pytest.mark.static
    def test_install_unpacks_and_copies_vcruntime_on_windows(self):
        _run_lua('''
import = function() end
dofile(arg[1])

-- 1. Linux tarball unpack
local unpacked, required, copied = {}, {}, {}
pkginfo = {
    install_file = function() return "/cache/hyperfine-v2.0.0-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/hyperfine/2.0.0" end,
    dep_install_dir = function() return nil end,
}
payload = {
    unpack = function(opts) table.insert(unpacked, opts) end,
    require = function(files) table.insert(required, files[1]) end,
}
fs = { files = function() return {} end }
os.cp = function(s, d) table.insert(copied, {s, d}) end

assert(install())
assert(unpacked[1].extracted == "hyperfine-v2.0.0-x86_64-unknown-linux-musl" and unpacked[1].strip == 1)
assert(required[1] == "hyperfine")
assert(#copied == 0)

-- 2. Windows zip unpack + xim:vcruntime app-local DLL copy
unpacked, required, copied = {}, {}, {}
pkginfo = {
    install_file = function() return "C:\\\\cache\\\\hyperfine-v2.0.0-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/hyperfine/2.0.0" end,
    dep_install_dir = function(name)
        assert(name == "xim:vcruntime")
        return "C:/xpkgs/xim-x-vcruntime/14.44.35211"
    end,
}
fs = {
    files = function(dir)
        assert(dir == "C:/xpkgs/xim-x-vcruntime/14.44.35211/bin")
        return { "C:/xpkgs/xim-x-vcruntime/14.44.35211/bin/vcruntime140.dll" }
    end,
}
assert(install())
assert(unpacked[1].extracted == "hyperfine-v2.0.0-x86_64-pc-windows-msvc" and unpacked[1].strip == 1)
assert(#copied == 1 and copied[1][2] == "C:/xpkgs/hyperfine/2.0.0")
assert(required[1] == "hyperfine.exe")
''', PKG_FILE)

    @pytest.mark.static
    def test_config_and_uninstall(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local adds, rms = {}, {}
pkginfo = { install_dir = function() return "/pkg" end }
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(config())
assert(#adds == 1 and adds[1][1] == "hyperfine" and adds[1][2].bindir == "/pkg")

assert(uninstall())
assert(#rms == 1 and rms[1] == "hyperfine")
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
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("hyperfine --version", contains="hyperfine 2.0.0")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("hyperfine")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_benchmark_runs(self):
        proc = subprocess.run(
            ["bash", "-l", "-c", "hyperfine --runs 2 --warmup 0 'true'"],
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert "Benchmark 1: true" in proc.stdout
