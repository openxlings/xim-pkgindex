"""Tests for the ruff package."""
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
    assert_command_output, assert_xvm_registered, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "ruff"
PKG_FILE = "pkgs/r/ruff.lua"
VERSION = "0.17.6"


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
    def test_platforms_arches_sha256_and_autoupdate(self, meta):
        """All 3 platforms and 2 architectures (x86_64, aarch64) are covered
        with pinned sha256s and zero runtime deps (static musl / static CRT)."""
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "ruff")

for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local sec = assert(package.xpm[plat], "missing platform " .. plat)
    assert(sec.latest and sec.latest.ref == ver, "latest mismatch on " .. plat)
    assert(sec.deps == nil, "unexpected runtime deps on " .. plat)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local entry = assert(sec[ver] and sec[ver][arch], "missing " .. plat .. "/" .. arch)
        assert(type(entry.url) == "string" and entry.url:find("/" .. ver .. "/", 1, true))
        assert(type(entry.sha256) == "string" and #entry.sha256 == 64 and entry.sha256:match("^%x+$"))
    end
end

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/astral-sh/ruff/releases")
local global = assert(auto.resources and auto.resources.GLOBAL)
assert(global.required == true)
for _, plat in ipairs({"linux", "macosx", "windows"}) do
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local tmpl = assert(global.url[plat] and global.url[plat][arch])
        assert(tmpl:find("${tag}", 1, true) or tmpl:find("${version}", 1, true))
    end
end
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_hooks_in_lua_sandbox(self):
        """Verify install/installed/config/uninstall for Unix tarball and Windows flat zip."""
        _run_lua('''
import = function() end
dofile(arg[1])

local unpack_calls, req_calls, present_map = {}, {}, {}
local xvm_adds, xvm_rms = {}, {}

pkginfo = {
    install_dir = function() return "/opt/xpkgs/ruff/0.17.6" end,
    install_file = function() return "/tmp/cache/ruff-x86_64-unknown-linux-musl.tar.gz" end,
}
payload = {
    unpack = function(opt) table.insert(unpack_calls, opt) end,
    require = function(files)
        table.insert(req_calls, files)
        for _, f in ipairs(files) do present_map[f] = true end
    end,
    present = function(files)
        for _, f in ipairs(files) do
            if not present_map[f] then return false end
        end
        return true
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#unpack_calls == 1 and unpack_calls[1].extracted == "ruff-x86_64-unknown-linux-musl")
assert(#req_calls == 1 and req_calls[1][1] == "ruff")
assert(installed())
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "ruff" and xvm_adds[1][2].bindir == "/opt/xpkgs/ruff/0.17.6")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "ruff")

-- Windows flat zip branch
unpack_calls, req_calls, present_map = {}, {}, {}
pkginfo.install_file = function() return "C:\\\\cache\\\\ruff-x86_64-pc-windows-msvc.zip" end
assert(not installed())
assert(install())
assert(#unpack_calls == 1 and unpack_calls[1].extracted == nil)
assert(#req_calls == 1 and req_calls[1][1] == "ruff.exe")
assert(installed())
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
        assert_command_output("ruff --version", contains=f"ruff {VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("ruff")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_shim_exists(self):
        assert_xvm_shim_exists("ruff")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_check_and_format(self, tmp_path):
        sample = tmp_path / "sample.py"
        sample.write_text("import os\nx=1+2\n", encoding="utf-8")
        chk = subprocess.run(
            ["bash", "-l", "-c", f'ruff check "{sample}"'],
            capture_output=True, text=True, timeout=15,
        )
        assert chk.returncode == 1
        assert "F401" in chk.stdout

        fmt = subprocess.run(
            ["bash", "-l", "-c", f'ruff format --check "{sample}"'],
            capture_output=True, text=True, timeout=15,
        )
        assert fmt.returncode == 1
