"""Tests for dart-sdk package (Dart SDK)."""
import os
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

PKG = "dart-sdk"
PKG_FILE = "pkgs/d/dart-sdk.lua"
VERSION = "3.14.1"


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
    def test_the_host_lands_the_archive(self):
        # spec "3": the archive's one top-level directory is dropped by the
        # entry's strip as the host lands it; the hook does not land it
        # (payload.unpack is for recipes of spec 1 and 2).
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert "payload.unpack" not in src
        assert re.search(r"\bstrip = 1,", src)

    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)
        assert meta.spec == "3"

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
    def test_platforms_deps_and_sha256_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["dart"]
        assert meta.has_xvm_enable
        _run_lua('''
import = function() end
dofile(arg[1])
local linux = assert(package.xpm.linux)
assert(linux.deps and linux.deps.runtime, "linux must declare runtime deps")
local seen = {}
for _, d in ipairs(linux.deps.runtime) do seen[d] = true end
assert(seen["xim:glibc@>=2.39"], "linux must depend on xim:glibc@>=2.39")

for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "3.14.1", plat .. " latest must ref 3.14.1")
    assert(type(p.source) == "string" and p.source:find("${version}", 1, true),
           plat .. " source must template ${version}")
    local v = assert(p["3.14.1"], "missing 3.14.1 on " .. plat)
    assert(v.arch_alias and v.arch_alias.x86_64 == "x64" and v.arch_alias.aarch64 == "arm64",
           plat .. " arch_alias mismatch")
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(v.sha256 and v.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"),
               "invalid sha256 for " .. plat .. "/" .. arch)
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_install_config_uninstall_sandbox(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX pre-extracted dart-sdk/ beside archive
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
local host = "linux"
local install_file = "/tmp/cache/dartsdk-linux-x64-release.zip"
local install_dir = "/tmp/xpkgs/dart-sdk/3.14.1"
os.host = function() return host end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function() end
os.mv = function(src, dst)
    dirs[src] = nil
    dirs[dst] = true
    local moved = {}
    for k, v in pairs(files) do
        if k:sub(1, #src + 1) == src .. "/" then
            moved[k] = v
        end
    end
    for k, v in pairs(moved) do
        files[dst .. k:sub(#src + 1)] = v
        files[k] = nil
    end
end
fs = { mkdir_p = function() end }
log = { info = function() end }
system = { exec = function(cmd) execs[#execs + 1] = cmd end }
xvm = {
    add = function(name, opts) adds[#adds + 1] = { name, opts } end,
    remove = function(name) rms[#rms + 1] = name end,
}
pkginfo = {
    name = function() return "dart-sdk" end,
    version = function() return "3.14.1" end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
}

-- spec "3": the host has landed the zip in the install directory before
-- install() (the entry's strip = 1 drops its dart-sdk/); install() makes the
-- programs executable and asserts what landed.
assert(not installed())
assert(not pcall(install))
files[install_dir .. "/bin/dart"] = true
files[install_dir .. "/bin/dartaotruntime"] = true
files[install_dir .. "/bin/snapshots/dartdev_aot.dart.snapshot"] = true
files[install_dir .. "/version"] = true
assert(install())
assert(installed())
assert(#execs >= 2 and execs[1]:find("chmod +x", 1, true))
assert(config())
assert(adds[1][1] == "dart-sdk" and adds[1][2].type == "group")
assert(adds[2][1] == "dart" and adds[2][2].bindir == install_dir .. "/bin")
assert(adds[2][2].binding == "dart-sdk@3.14.1")
assert(uninstall())
assert(#rms == 2 and rms[1] == "dart" and rms[2] == "dart-sdk")

-- Case 2: Windows -- the same landing, and nothing to run.
files, dirs, execs = {}, {}, {}
host = "windows"
install_file = "C:/cache/dartsdk-windows-x64-release.zip"
install_dir = "C:/xpkgs/dart-sdk/3.14.1"
files["C:/xpkgs/dart-sdk/3.14.1/bin/dart.exe"] = true
files["C:/xpkgs/dart-sdk/3.14.1/bin/dartaotruntime.exe"] = true
files["C:/xpkgs/dart-sdk/3.14.1/bin/snapshots/dartdev_aot.dart.snapshot"] = true
files["C:/xpkgs/dart-sdk/3.14.1/version"] = true
assert(installed())
assert(install())
assert(#execs == 0)
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
            "xim.libxpkg.pkginfo", "xim.libxpkg.system",
            "xim.libxpkg.xvm", "xim.libxpkg.fs", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_dart_version(self):
        assert_command_output("dart --version", contains=f"Dart SDK version: {VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_dart_run(self, tmp_path):
        script = tmp_path / "hello.dart"
        script.write_text("void main() => print('dart-ok');\n", encoding="utf-8")
        assert_command_output(f'dart run "{script}"', contains="dart-ok")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_dart(self):
        if os.environ.get("XLINGS_TEST_SUBOS"):
            assert_xvm_registered("dart")
            assert_xvm_registered("dart-sdk")
        else:
            assert_xvm_shim_exists("dart")
