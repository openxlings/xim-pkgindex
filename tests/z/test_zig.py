"""Zig programming language and toolchain."""
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

PKG = "zig"
PKG_FILE = "pkgs/z/zig.lua"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args], input=script, text=True, capture_output=True, check=True
    ).stdout


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
    def test_platform_arch_hashes_and_sources(self):
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2", "expected spec = 2")
assert(package.ci and package.ci.mirror == true, "expected ci.mirror = true")
local expected_ext = { linux = "tar.xz", macosx = "tar.xz", windows = "zip" }
for plat, ext in pairs(expected_ext) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ver = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    local entry = assert(p[ver], "missing version entry for " .. plat)
    assert(p.source and p.source:find(ext, 1, true), "unexpected source for " .. plat)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = entry.sha256 and entry.sha256[arch]
        assert(h and #h == 64 and h:match("^%x+$"),
               string.format("invalid sha256 for %s/%s", plat, arch))
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    @pytest.mark.parametrize("exe", ["zig", "zig.exe"])
    def test_installed_requires_binary_and_stdlib(self, exe):
        _run_lua(
            '''
import = function() end
dofile(arg[1])
pkginfo = { install_dir = function() return "/pkg" end }
local present = {}
os.isfile = function(p) return present[p] == true end
assert(not installed(), "empty dir must not satisfy installed()")
local req = { "/pkg/" .. arg[2], "/pkg/lib/std/std.zig", "/pkg/lib/zig.h" }
for _, f in ipairs(req) do present[f] = true end
assert(installed(), "complete payload must satisfy installed()")
for _, f in ipairs(req) do
    present[f] = nil
    assert(not installed(), "accepted incomplete payload missing " .. f)
    present[f] = true
end
''',
            PKG_FILE,
            exe,
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
    def test_portable_lua_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
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
        assert_command_output("zig version", contains="0.17.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_env(self):
        assert_command_output("zig env", contains=".std_dir")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("zig")
