"""Tests for the usql package (universal command-line interface for SQL databases)."""
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
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "usql"
PKG_FILE = "pkgs/u/usql.lua"
VERSION = "0.21.6"


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
        """Linux (x86_64/aarch64 static ELF), macOS (x86_64/aarch64), and
        Windows (x86_64 UCRT PE) are covered with pinned sha256s and zero runtime deps."""
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)
        assert meta.programs == ["usql"]
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "usql")

local expected = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
local alias_map = { x86_64 = "amd64", aarch64 = "arm64" }

for plat, arches in pairs(expected) do
    local sec = assert(package.xpm[plat], "missing platform " .. plat)
    assert(sec.latest and sec.latest.ref == ver, "latest mismatch on " .. plat)
    assert(sec.deps == nil, "unexpected runtime deps on " .. plat)
    assert(type(sec.source) == "string" and sec.source:find("${version}", 1, true))
    local entry = assert(sec[ver], "missing version " .. ver .. " on " .. plat)
    for _, arch in ipairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias_map[arch],
               "arch_alias mismatch on " .. plat .. "/" .. arch)
        local h = assert(entry.sha256 and entry.sha256[arch],
                         "missing sha256 on " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"),
               "invalid sha256 on " .. plat .. "/" .. arch)
    end
end

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/xo/usql/releases")
local global = assert(auto.resources and auto.resources.GLOBAL)
assert(global.required == true)
for plat, arches in pairs(expected) do
    for _, arch in ipairs(arches) do
        local tmpl = assert(global.url[plat] and global.url[plat][arch])
        assert(tmpl:find("${tag}", 1, true) and tmpl:find("${version}", 1, true))
    end
end
assert(global.url.linux.x86_64:find("usql_static-", 1, true))
assert(global.url.linux.aarch64:find("usql_static-", 1, true))
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_hooks_in_lua_sandbox(self):
        """Verify install/installed/config/uninstall across Linux static .tar.bz2,
        macOS .tar.bz2, pre-extracted fallback, and Windows .zip."""
        _run_lua('''
import = function() end
dofile(arg[1])

-- Case 1: Linux usql_static .tar.bz2 (extracts usql_static + LICENSE, renames to usql)
local files, execs, xvm_adds, xvm_rms = {}, {}, {}, {}
local install_file = "/tmp/cache/usql_static-0.21.6-linux-amd64.tar.bz2"
local install_dir = "/opt/xpkgs/usql/0.21.6"

os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function() end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("tar -xjf", 1, true) then
            files[install_dir .. "/usql_static"] = true
            files[install_dir .. "/LICENSE"] = true
        end
    end,
}
pkginfo = {
    install_dir = function() return install_dir end,
    install_file = function() return install_file end,
}
payload = {
    unpack = function() error("unexpected payload.unpack on POSIX") end,
    require = function(req)
        for _, f in ipairs(req) do
            assert(files[install_dir .. "/" .. f], "missing required file: " .. f)
        end
        return true
    end,
    present = function(req)
        for _, f in ipairs(req) do
            if not files[install_dir .. "/" .. f] then return false end
        end
        return true
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

files[install_file] = true
assert(not installed())
assert(install())
assert(installed())
assert(files[install_dir .. "/usql"])
assert(files[install_dir .. "/LICENSE"])
assert(not files[install_dir .. "/usql_static"])
assert(#execs == 2 and execs[1]:find("tar -xjf", 1, true) and execs[2]:find("chmod +x", 1, true))
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "usql" and xvm_adds[1][2].bindir == install_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "usql")

-- Case 2: macOS .tar.bz2 (extracts usql + LICENSE directly)
files, execs = {}, {}
install_file = "/tmp/cache/usql-0.21.6-darwin-arm64.tar.bz2"
files[install_file] = true
system.exec = function(cmd)
    table.insert(execs, cmd)
    if cmd:find("tar -xjf", 1, true) then
        files[install_dir .. "/usql"] = true
        files[install_dir .. "/LICENSE"] = true
    end
end
assert(not installed())
assert(install())
assert(installed())
assert(files[install_dir .. "/usql"])
assert(files[install_dir .. "/LICENSE"])
assert(#execs == 2 and execs[1]:find("tar -xjf", 1, true) and execs[2]:find("chmod +x", 1, true))

-- Case 3: POSIX pre-extracted usql_static + LICENSE beside missing archive
files, execs = {}, {}
install_file = "/tmp/cache/usql_static-0.21.6-linux-amd64.tar.bz2"
files["/tmp/cache/usql_static"] = true
files["/tmp/cache/LICENSE"] = true
assert(not installed())
assert(install())
assert(installed())
assert(files[install_dir .. "/usql"])
assert(files[install_dir .. "/LICENSE"])
assert(#execs == 1 and execs[1]:find("chmod +x", 1, true))

-- Case 4: Windows .zip containing usql.exe + LICENSE
files, execs, xvm_adds, xvm_rms = {}, {}, {}, {}
local unpack_calls = {}
install_file = "C:\\\\cache\\\\usql-0.21.6-windows-amd64.zip"
install_dir = "C:/xpkgs/usql/0.21.6"
files[install_file] = true
payload.unpack = function(opt)
    table.insert(unpack_calls, opt)
    files[install_dir .. "/usql.exe"] = true
    files[install_dir .. "/LICENSE"] = true
end
assert(not installed())
assert(install())
assert(installed())
assert(#unpack_calls == 1 and unpack_calls[1].extracted == nil)
assert(files[install_dir .. "/usql.exe"])
assert(files[install_dir .. "/LICENSE"])
assert(#execs == 0)
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "usql" and xvm_adds[1][2].bindir == install_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "usql")
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
            "xim.libxpkg.system",
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
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output("usql --version", contains=f"usql {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            from tests.lib.platform_utils import xlings_home
            subos_dir = Path(xlings_home()) / "subos"
            chosen = "current" if (subos_dir / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", chosen)
        assert_xvm_registered("usql")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_shim_exists(self):
        from tests.lib.platform_utils import xlings_home
        subos_dir = Path(xlings_home()) / "subos"
        subos_name = os.environ.get("XLINGS_TEST_SUBOS") or (
            "current" if (subos_dir / "current" / "bin").is_dir() else "default"
        )
        shim = subos_dir / subos_name / "bin" / "usql"
        assert shim.exists(), f"missing usql shim at {shim}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_sqlite_query_roundtrip(self, tmp_path):
        db = tmp_path / "test.db"
        res = subprocess.run(
            ["bash", "-l", "-c", f'usql "sqlite://{db}" -c "select 1"'],
            check=True, capture_output=True, text=True, timeout=20,
        )
        assert "1" in res.stdout
        assert db.exists()
