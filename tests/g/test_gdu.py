"""Metadata, isolated hooks, and real non-interactive scans for gdu."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_config_registers_package_name,
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
from tests.lib.platform_utils import under_test, xlings_home

PKG = "gdu"
PKG_FILE = "pkgs/g/gdu.lua"
VERSION = "5.39.0"
REPO = Path(__file__).resolve().parents[2]


def _run_lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to evaluate the recipe"
    subprocess.run(
        [lua, "-", PKG_FILE], input=script, text=True, capture_output=True,
        check=True, cwd=REPO,
    )


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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_resources_and_autoupdate_agree(self, meta):
        assert set(meta.platforms) == {"linux", "macosx", "windows"}
        _run_lua(r'''
import = function() end
dofile(arg[1])
local auto = assert(package.extensions.autoupdate)
assert(auto.source == "https://github.com/dundee/gdu/releases")
assert(auto.resources.GLOBAL.required == true)
assert(auto.resources.CN == nil)
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    assert(p.deps == nil)
    local count = 0
    for arch, resource in pairs(entry) do
        assert(arch == "x86_64" or arch == "aarch64")
        assert(#resource.sha256 == 64 and resource.sha256:match("^%x+$"))
        local template = assert(auto.resources.GLOBAL.url[platform][arch])
        assert(template:gsub("%${tag}", "v" .. version) == resource.url)
        count = count + 1
    end
    assert(count == 2)
end
''')

    @pytest.mark.static
    def test_archive_hooks_and_missing_payload(self):
        _run_lua(r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

for _, filename in ipairs({
    "gdu_linux_amd64_static.tgz", "gdu_linux_arm64.tgz",
    "gdu_darwin_amd64.tgz", "gdu_darwin_arm64.tgz",
    "gdu_windows_amd64.exe.zip", "gdu_windows_arm64.exe.zip",
}) do
    local windows = filename:match("%.zip$") ~= nil
    local original = filename:gsub("%.tgz$", ""):gsub("%.zip$", "")
    local root = windows and "C:/gdu test" or "/gdu test"
    local dir = root .. "/installed"
    local archive = root .. "/cache/" .. filename
    local exe = windows and "gdu.exe" or "gdu"
    local files, dirs, calls = {}, {}, {}
    local produce_payload = true
    os.host = function() return windows and "windows" or "linux" end
    os.getenv = function(k) return k == "SystemRoot" and "C:\\Windows" or nil end
    os.isfile = function(p) return files[p] == true end
    os.isdir = function(p) return dirs[p] == true end
    os.tryrm = function(p)
        assert(p == dir, "must only clean our install directory")
        files[dir .. "/" .. original] = nil
        files[dir .. "/" .. exe] = nil
    end
    os.mv = function(src, dst)
        assert(src == dir .. "/" .. original and dst == dir .. "/" .. exe)
        assert(files[src], "cannot rename a missing binary")
        files[src], files[dst] = nil, true
    end
    fs = { mkdir_p = function(p) dirs[p] = true end }
    log = { info = function() end }
    pkginfo = {
        name = function() return "gdu" end,
        install_file = function() return archive end,
        install_dir = function() return dir end,
    }
    system = { exec = function(cmd)
        calls[#calls + 1] = cmd
        if produce_payload then files[dir .. "/" .. original] = true end
    end }
    local registered = false
    xvm = {
        add = function(name, opt)
            assert(name == "gdu" and opt.bindir == dir)
            registered = true
        end,
        remove = function(name) assert(name == "gdu"); registered = false end,
    }
    assert(not installed())
    assert(install() and installed())
    assert(files[dir .. "/" .. exe])
    if windows then
        assert(#calls == 1)
        assert(calls[1]:find("C:\\Windows\\System32\\tar.exe", 1, true) == 1)
    else
        assert(#calls == 2)
        assert(calls[1] == shell.join({"tar", "-xzf", archive, "-C", dir}))
        assert(calls[2] == shell.join({"chmod", "+x", dir .. "/" .. exe}))
    end
    assert(config() and registered)
    assert(uninstall() and not registered)
    assert(install() and installed(), "reinstall must restore the named executable")
    files[dir .. "/" .. exe] = nil
    assert(not installed())
    produce_payload = false
    local ok, err = pcall(install)
    assert(not ok and tostring(err):find(original, 1, true), "must reject a missing payload")
end
''')


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
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    def _run_gdu(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        base = Path(xlings_home()) / "subos"
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = base / subos / "bin"
        if not bindir.is_dir() and subos == "current":
            bindir = base / "default" / "bin"
        shim = bindir / ("gdu" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *map(str, args)], capture_output=True, text=True,
            encoding="utf-8", timeout=15,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert expected in self._run_gdu("--version")

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("gdu")

    @pytest.mark.verify
    def test_noninteractive_size_scan(self, tmp_path):
        fixture = tmp_path / "scan fixture"
        (fixture / "child").mkdir(parents=True)
        (fixture / "a.txt").write_bytes(b"12345")
        (fixture / "child" / "b.txt").write_bytes(b"abcdefg")
        # Apparent sizes are deterministic across filesystems; never scan HOME.
        out = self._run_gdu(
            "--non-interactive", "--no-progress", "--no-color", "--no-prefix",
            "--show-apparent-size", "--depth", "2", fixture,
        )
        sizes = {}
        for line in out.splitlines():
            size, path = line.strip().split(maxsplit=1)
            sizes[Path(path)] = int(size)
        assert sizes == {
            fixture: 12, fixture / "a.txt": 5,
            fixture / "child": 7, fixture / "child" / "b.txt": 7,
        }, out
