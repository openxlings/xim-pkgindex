"""xh"""
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

PKG = "xh"
PKG_FILE = "pkgs/x/xh.lua"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args], input=script, text=True, capture_output=True, check=True
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
    def test_expected_platforms(self, meta):
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)

    @pytest.mark.static
    def test_platforms_archs_sha256_and_autoupdate_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])

assert(package.spec == "2", "spec must be 2")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "xh")

local expected_assets = {
    linux = {
        x86_64  = "xh-v0.26.3-x86_64-unknown-linux-musl.tar.gz",
        aarch64 = "xh-v0.26.3-aarch64-unknown-linux-musl.tar.gz",
    },
    macosx = {
        x86_64  = "xh-v0.26.3-x86_64-apple-darwin.tar.gz",
        aarch64 = "xh-v0.26.3-aarch64-apple-darwin.tar.gz",
    },
    windows = {
        x86_64  = "xh-v0.26.3-x86_64-pc-windows-msvc.zip",
    },
}

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/ducaale/xh/releases")
local global_au = assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.url)

for plat, arches in pairs(expected_assets) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == "0.26.3", plat .. " latest should be 0.26.3")
    for arch, asset in pairs(arches) do
        local entry = assert(p[ref] and p[ref][arch], "missing arch " .. arch .. " for " .. plat)
        local expected_url = "https://github.com/ducaale/xh/releases/download/v0.26.3/" .. asset
        assert(entry.url == expected_url, plat .. "/" .. arch .. " url mismatch: " .. tostring(entry.url))
        assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"),
               plat .. "/" .. arch .. " invalid sha256")
        local tmpl = assert(global_au[plat] and global_au[plat][arch],
                            "missing autoupdate template for " .. plat .. "/" .. arch)
        local rendered = tmpl:gsub("${tag}", "v0.26.3"):gsub("${version}", "0.26.3")
        assert(rendered == expected_url, "autoupdate template mismatch for " .. plat .. "/" .. arch)
    end
end
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
assert(#adds == 1 and adds[1][1] == "xh" and adds[1][2].bindir == "/pkg")

assert(uninstall())
assert(#rms == 1 and rms[1] == "xh")
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
        assert_command_output("xh --version", contains="xh 0.26.3")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("xh")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_offline_http_formatting(self):
        proc = subprocess.run(
            [
                "bash", "-l", "-c",
                "xh --ignore-stdin --offline --pretty=format POST https://example.com/api hello=world",
            ],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert proc.returncode == 0, f"xh --offline failed: {proc.stderr}"
        assert "POST /api HTTP/1.1" in proc.stdout
        assert '"hello": "world"' in proc.stdout
