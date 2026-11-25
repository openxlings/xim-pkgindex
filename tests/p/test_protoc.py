"""Tests for the protoc package (Protocol Buffers compiler)."""
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
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "protoc"
PKG_FILE = "pkgs/p/protoc.lua"
VERSION = "36.2"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    r = subprocess.run([lua, "-", *args], input=script, text=True,
                       capture_output=True)
    assert r.returncode == 0, f"Lua failed:\n{r.stderr}\n{r.stdout}"
    return r.stdout


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
    def test_platforms_urls_and_sha256_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["protoc"]
        assert meta.has_xvm_enable
        assert meta.has_installed
        assert meta.has_install
        assert meta.has_config
        assert meta.has_uninstall
        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
local au = assert(package.extensions and package.extensions.autoupdate)
assert(au.source == "https://github.com/protocolbuffers/protobuf/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "linux-x86_64", aarch64 = "linux-aarch_64" },
    macosx = { x86_64 = "osx-x86_64", aarch64 = "osx-aarch_64" },
    windows = { x86_64 = "win64" },
}
local seen = {}
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "36.2", plat .. " latest must ref 36.2")
    local v = assert(p["36.2"], "missing 36.2 on " .. plat)
    for arch, suffix in pairs(arches) do
        local r = assert(v[arch], "missing " .. plat .. "/" .. arch)
        assert(r.url == "https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protoc-36.2-" .. suffix .. ".zip",
               "unexpected url for " .. plat .. "/" .. arch .. ": " .. tostring(r.url))
        assert(type(r.sha256) == "string" and #r.sha256 == 64 and r.sha256:match("^%x+$"),
               "invalid sha256 for " .. plat .. "/" .. arch)
        assert(not seen[r.sha256], "duplicate sha256 across targets")
        seen[r.sha256] = true
        local au_url = assert(au.resources.GLOBAL.url[plat][arch])
        assert(au_url:find("${tag}", 1, true) and au_url:find("${version}", 1, true),
               "autoupdate template must use ${tag} and ${version}")
        assert(au_url:match("protoc%-${version}%-" .. suffix:gsub("%-", "%%-") .. "%.zip$"),
               "autoupdate template mismatch for " .. plat .. "/" .. arch .. ": " .. au_url)
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_install_posix_and_windows_zip_sandbox(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX zip extraction preserves bin/ and include/ and registers bin/
local files, execs, added, removed = {}, {}, {}, {}
local install_file = "/tmp/cache/protoc-36.2-linux-x86_64.zip"
local install_dir = "/tmp/xpkgs/protoc/36.2"
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function(p)
    for k in pairs(files) do
        if k == p or k:sub(1, #p + 1) == p .. "/" then
            files[k] = nil
        end
    end
end
fs = { mkdir_p = function() end }
system = {
    exec = function(cmd)
        execs[#execs + 1] = cmd
        if cmd:find("unzip ", 1, true) then
            files[install_dir .. "/bin/protoc"] = true
            files[install_dir .. "/include/google/protobuf/timestamp.proto"] = true
        end
    end
}
xvm = {
    add = function(name, cfg) added[#added + 1] = { name = name, cfg = cfg } end,
    remove = function(name) removed[#removed + 1] = name end,
}
pkginfo = {
    name = function() return "protoc" end,
    version = function() return "36.2" end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
}

files[install_file] = true
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1]:find('unzip -q -o "' .. install_file .. '" -d "' .. install_dir .. '"', 1, true))
assert(execs[2]:find("chmod +x", 1, true))
assert(config())
assert(#added == 1 and added[1].name == "protoc" and added[1].cfg.bindir == install_dir .. "/bin")
assert(uninstall())
assert(#removed == 1 and removed[1] == "protoc")

-- Case 2: Windows zip extraction uses System32 tar.exe directly
files, execs = {}, {}
install_file = "C:/cache/protoc-36.2-win64.zip"
install_dir = "C:/xpkgs/protoc/36.2"
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
system.exec = function(cmd)
    execs[#execs + 1] = cmd
    files[install_dir .. "/bin/protoc.exe"] = true
    files[install_dir .. "/include/google/protobuf/timestamp.proto"] = true
end
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1 and execs[1]:find("System32\\\\tar.exe", 1, true))
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
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
            "xim.libxpkg.system", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.winpath",
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
    def test_protoc_version(self):
        assert_command_output("protoc --version", contains=f"libprotoc {VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_protoc_compiles_with_well_known_import(self, tmp_path):
        proto = tmp_path / "event.proto"
        desc = tmp_path / "event.desc"
        proto.write_text(
            'syntax = "proto3";\n'
            'package demo;\n'
            'import "google/protobuf/timestamp.proto";\n'
            'message Event { google.protobuf.Timestamp created_at = 1; }\n',
            encoding="utf-8",
        )
        r = subprocess.run(
            [
                "bash", "-l", "-c",
                f'protoc -I "{tmp_path}" --descriptor_set_out="{desc}" --include_imports "{proto}"',
            ],
            capture_output=True, text=True, timeout=15,
        )
        assert r.returncode == 0, f"protoc compile failed: {r.stdout}\n{r.stderr}"
        assert desc.is_file() and desc.stat().st_size > 0

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_protoc(self):
        assert_xvm_shim_exists("protoc")
