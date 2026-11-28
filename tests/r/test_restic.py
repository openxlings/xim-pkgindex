"""Tests for the restic package (fast, secure, efficient backup program)."""
import json
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

PKG = "restic"
PKG_FILE = "pkgs/r/restic.lua"
VERSION = "0.20.0"


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
        """Linux (x86_64/aarch64), macOS (x86_64/aarch64), and Windows (x86_64)
        are covered with pinned sha256s and zero runtime deps (static Go ELF / kernel32 PE)."""
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)
        assert meta.programs == ["restic"]
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "restic")

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
assert(auto.source == "https://github.com/restic/restic/releases")
local global = assert(auto.resources and auto.resources.GLOBAL)
assert(global.required == true)
for plat, arches in pairs(expected) do
    for _, arch in ipairs(arches) do
        local tmpl = assert(global.url[plat] and global.url[plat][arch])
        assert(tmpl:find("${tag}", 1, true) and tmpl:find("${version}", 1, true))
    end
end
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_hooks_in_lua_sandbox(self):
        """Verify install/installed/config/uninstall for POSIX .bz2 and Windows .zip."""
        _run_lua('''
import = function() end
dofile(arg[1])

-- Case 1: POSIX .bz2 archive decompressed via bunzip2 -c
local files, execs, xvm_adds, xvm_rms = {}, {}, {}, {}
local install_file = "/tmp/cache/restic_0.20.0_linux_amd64.bz2"
local install_dir = "/opt/xpkgs/restic/0.20.0"

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
        if cmd:find("bunzip2 -c", 1, true) then
            files[install_dir .. "/restic"] = true
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
assert(files[install_dir .. "/restic"])
assert(#execs == 2 and execs[1]:find("bunzip2 -c", 1, true) and execs[2]:find("chmod +x", 1, true))
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "restic" and xvm_adds[1][2].bindir == install_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "restic")

-- Case 2: POSIX pre-extracted binary beside archive
files, execs = {}, {}
files["/tmp/cache/restic_0.20.0_linux_amd64"] = true
assert(not installed())
assert(install())
assert(installed())
assert(files[install_dir .. "/restic"])
assert(#execs == 1 and execs[1]:find("chmod +x", 1, true))

-- Case 3: Windows .zip containing restic_<ver>_windows_amd64.exe
files, execs, xvm_adds, xvm_rms = {}, {}, {}, {}
local unpack_calls = {}
install_file = "C:\\\\cache\\\\restic_0.20.0_windows_amd64.zip"
install_dir = "C:/xpkgs/restic/0.20.0"
files[install_file] = true
payload.unpack = function(opt)
    table.insert(unpack_calls, opt)
    files[install_dir .. "/restic_0.20.0_windows_amd64.exe"] = true
end
assert(not installed())
assert(install())
assert(installed())
assert(#unpack_calls == 1 and unpack_calls[1].extracted == nil)
assert(files[install_dir .. "/restic.exe"])
assert(not files[install_dir .. "/restic_0.20.0_windows_amd64.exe"])
assert(#execs == 0)
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "restic" and xvm_adds[1][2].bindir == install_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "restic")
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
        assert_command_output("restic version", contains=f"restic {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            from tests.lib.platform_utils import xlings_home
            subos_dir = Path(xlings_home()) / "subos"
            chosen = "current" if (subos_dir / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", chosen)
        assert_xvm_registered("restic")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_shim_exists(self):
        from tests.lib.platform_utils import xlings_home
        subos_dir = Path(xlings_home()) / "subos"
        subos_name = os.environ.get("XLINGS_TEST_SUBOS") or (
            "current" if (subos_dir / "current" / "bin").is_dir() else "default"
        )
        shim = subos_dir / subos_name / "bin" / "restic"
        assert shim.exists(), f"missing restic shim at {shim}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_backup_and_restore_roundtrip(self, tmp_path):
        repo = tmp_path / "repo"
        src = tmp_path / "src"
        dst = tmp_path / "dst"
        src.mkdir()
        (src / "hello.txt").write_text("restic-smoke-ok\n", encoding="utf-8")

        env = {**os.environ, "RESTIC_PASSWORD": "test-password-123"}
        subprocess.run(
            ["bash", "-l", "-c", f'restic -r "{repo}" init'],
            env=env, check=True, capture_output=True, text=True, timeout=20,
        )
        subprocess.run(
            ["bash", "-l", "-c", f'restic -r "{repo}" backup "{src}"'],
            env=env, check=True, capture_output=True, text=True, timeout=20,
        )
        snaps = subprocess.run(
            ["bash", "-l", "-c", f'restic -r "{repo}" snapshots --json'],
            env=env, check=True, capture_output=True, text=True, timeout=20,
        )
        assert len(json.loads(snaps.stdout)) == 1
        subprocess.run(
            ["bash", "-l", "-c", f'restic -r "{repo}" restore latest --target "{dst}"'],
            env=env, check=True, capture_output=True, text=True, timeout=20,
        )
        restored = list(dst.rglob("hello.txt"))
        assert restored and restored[0].read_text(encoding="utf-8") == "restic-smoke-ok\n"
