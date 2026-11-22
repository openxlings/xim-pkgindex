"""redis"""
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

PKG = "redis"
PKG_FILE = "pkgs/r/redis.lua"


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
    def test_all_platforms_pinned_deps_and_sha256(self, meta):
        assert "BUILD_TLS=no" in meta.description
        _run_lua('''
import = function() end
dofile(arg[1])
local ldeps = assert(package.xpm.linux.deps and package.xpm.linux.deps.build)
assert(ldeps[1] == "xim:make@4.3" and ldeps[2] == "xim:musl-gcc@15.1.0",
       "linux build deps must be pinned")

local expected = {
    linux = false,
    macosx = false,
    windows = {"x86_64"},
}
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref)
    local v = assert(p[ref], "missing version " .. ref .. " on " .. plat)
    if arches then
        for _, arch in ipairs(arches) do
            local r = assert(v[arch], "missing " .. plat .. "/" .. arch)
            assert(type(r.url) == "string" and r.url:find(ref, 1, true))
            assert(type(r.sha256) == "string" and #r.sha256 == 64 and r.sha256:match("^%x+$"))
        end
    else
        assert(type(v.url) == "string" and v.url:find(ref, 1, true))
        assert(type(v.sha256) == "string" and #v.sha256 == 64 and v.sha256:match("^%x+$"))
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_nproc_parallelism_and_make_failure_raises_compiler_error(self, tmp_path):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert "-j4" not in src
        assert "nproc" in src and "hw.ncpu" in src

        fake_bin = tmp_path / "musl" / "bin"
        fake_bin.mkdir(parents=True)
        fake_make = fake_bin / "make"
        fake_make.write_text(
            "#!/bin/sh\necho 'zmalloc.c:1:10: fatal error: synthetic_compile_error.h: No such file or directory' >&2\nexit 2\n",
            encoding="utf-8",
        )
        fake_make.chmod(0o755)
        (tmp_path / "redis-8.10.3" / "src").mkdir(parents=True)

        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local root = arg[2]
pkginfo = {
    version = function() return "8.10.3" end,
    install_file = function() return root .. "/redis-8.10.3.tar.gz" end,
    install_dir = function() return root .. "/out" end,
    build_dep = function(name)
        if name == "make" then return { path = root .. "/musl" } end
        if name == "musl-gcc" then return { path = root .. "/musl" } end
    end,
}
os.isdir = function(p) return p == (root .. "/redis-8.10.3") end
os.isfile = function(p) return p == (root .. "/musl/bin/make") end
os.tryrm = function() end

local ok, err = pcall(install)
assert(not ok, "failing make must raise immediately")
assert(tostring(err):find("make failed", 1, true), "unexpected error: " .. tostring(err))
assert(tostring(err):find("synthetic_compile_error.h", 1, true), "compiler stderr lost: " .. tostring(err))
assert(not tostring(err):find("files missing", 1, true), "fell through to payload.require: " .. tostring(err))
''', PKG_FILE, str(tmp_path))

    @pytest.mark.static
    def test_installed_checks_all_programs_and_configs(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
pkginfo = { install_dir = function() return "/pkg" end }
local present = {}
os.isfile = function(p) return present[p] == true end

local posix_files = {
    "/pkg/bin/redis-server", "/pkg/bin/redis-cli", "/pkg/bin/redis-benchmark",
    "/pkg/bin/redis-check-aof", "/pkg/bin/redis-check-rdb", "/pkg/bin/redis-sentinel",
    "/pkg/etc/redis.conf", "/pkg/etc/sentinel.conf",
}
assert(not installed())
for _, f in ipairs(posix_files) do present[f] = true end
assert(installed())
for _, f in ipairs(posix_files) do
    present[f] = nil
    assert(not installed(), "accepted missing " .. f)
    present[f] = true
end

present = {}
local win_files = {
    "/pkg/redis-server.exe", "/pkg/redis-cli.exe", "/pkg/redis-benchmark.exe",
    "/pkg/redis-check-aof.exe", "/pkg/redis-check-rdb.exe", "/pkg/redis-sentinel.exe",
    "/pkg/redis.conf", "/pkg/sentinel.conf",
}
for _, f in ipairs(win_files) do present[f] = true end
assert(installed())
for _, f in ipairs(win_files) do
    present[f] = nil
    assert(not installed(), "accepted missing " .. f)
    present[f] = true
end
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
            "xim.libxpkg.xvm", "xim.pkgindex.payload",
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
    def test_server_version(self):
        assert_command_output("redis-server --version", contains="v=8.10.3")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_cli_version(self):
        assert_command_output("redis-cli --version", contains="8.10.3")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("redis-server")
        assert_xvm_registered("redis-cli")
