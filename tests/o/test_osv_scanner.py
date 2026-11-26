"""Tests for the osv-scanner package."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_platform_supported,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "osv-scanner"
PKG_FILE = "pkgs/o/osv-scanner.lua"
VERSION = "2.7.1"
REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        check=True,
        cwd=REPO_ROOT,
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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_platforms_archs_checksums_and_autoupdate(self):
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "osv-scanner")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/google/osv-scanner/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
local seen_filenames = {}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    assert(p.deps == nil, platform .. " binaries need no runtime deps")
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == "2.7.1", platform .. " latest should be 2.7.1")
    local entry = assert(p[version], "missing version entry: " .. platform)
    local tag = "v" .. version
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^[0-9a-f]+$"), platform .. "/" .. arch)
        local resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        local auto = assert(au.resources.GLOBAL.url[platform][arch], "missing autoupdate url: " .. platform .. "/" .. arch)
        local expanded_auto = auto:gsub("%${tag}", tag):gsub("%${version}", version)
        assert(expanded_auto == resolved, "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        local filename = resolved:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unexpected arch: " .. arch) end
end
assert(count == 6)
''', PKG_FILE)

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        _run_lua('''
local files = {}
local execs = {}
local xvm_calls = {}
local cur_install_file = ""
local cur_install_dir = ""

local mods = {
    ["xim.libxpkg.fs"] = function()
        fs = { mkdir_p = function(d) end }
    end,
    ["xim.libxpkg.pkginfo"] = function()
        pkginfo = {
            install_file = function() return cur_install_file end,
            install_dir = function() return cur_install_dir end,
        }
    end,
    ["xim.libxpkg.xvm"] = function()
        xvm = {
            add = function(name, opts) table.insert(xvm_calls, {"add", name, opts}) end,
            remove = function(name) table.insert(xvm_calls, {"remove", name}) end,
        }
    end,
    ["xim.libxpkg.system"] = function()
        system = {
            exec = function(cmd) table.insert(execs, cmd) end,
        }
    end,
}

function import(name)
    assert(mods[name], "unexpected import: " .. name)()
end

os.isfile = function(p) return files[p] == true end
os.tryrm = function(d)
    for k in pairs(files) do
        if k:sub(1, #d) == d then files[k] = nil end
    end
end
os.mv = function(src, dst)
    assert(files[src], "missing src: " .. src)
    files[src] = nil
    files[dst] = true
end

assert(loadfile(arg[1]))()

-- Unix case
cur_install_file = "/tmp/dl/osv-scanner_linux_amd64"
cur_install_dir = "/store/xpkgs/xim-x-osv-scanner/2.7.1"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(files["/store/xpkgs/xim-x-osv-scanner/2.7.1/osv-scanner"] == true)
assert(#execs == 1 and execs[1]:match('chmod %+x "/store/xpkgs/xim%-x%-osv%-scanner/2%.7%.1/osv%-scanner"'))
assert(installed() == true)

-- Windows case
files = {}
execs = {}
cur_install_file = "C:\\\\dl\\\\osv-scanner_windows_amd64.exe"
cur_install_dir = "C:\\\\store\\\\xpkgs\\\\xim-x-osv-scanner\\\\2.7.1"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(files["C:\\\\store\\\\xpkgs\\\\xim-x-osv-scanner\\\\2.7.1/osv-scanner.exe"] == true)
assert(#execs == 0, "must not run chmod on Windows")
assert(installed() == true)

-- config & uninstall
assert(config() == true)
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "osv-scanner" and xvm_calls[1][3].bindir == cur_install_dir)
assert(uninstall() == true)
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "osv-scanner")
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
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


@skip_if_not("linux")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=180)


def _active_subos() -> str:
    if subos := os.environ.get("XLINGS_TEST_SUBOS"):
        return subos
    subos_dir = Path(xlings_home()) / "subos"
    for candidate in ("current", "default"):
        if (subos_dir / candidate / ".xlings.json").is_file():
            return candidate
    return "default"


def _osv_scanner_bin() -> str:
    shim = Path(xlings_home()) / "subos" / _active_subos() / "bin" / "osv-scanner"
    if shim.is_file():
        return str(shim)
    found = shutil.which("osv-scanner")
    assert found, f"osv-scanner binary not found at {shim} or in PATH"
    return found


@skip_if_not("linux")
class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        proc = subprocess.run(
            [_osv_scanner_bin(), "--version"],
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert f"osv-scanner version: {expected}" in (proc.stdout + proc.stderr)

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", _active_subos())
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_xvm_shim_exists(self):
        shim = Path(xlings_home()) / "subos" / _active_subos() / "bin" / "osv-scanner"
        assert shim.is_file() or shim.is_symlink(), f"shim missing: {shim}"

    @pytest.mark.verify
    def test_offline_scan_empty_lockfile_json(self, tmp_path):
        lockfile = tmp_path / "package-lock.json"
        lockfile.write_text(
            json.dumps({
                "name": "empty-test",
                "version": "1.0.0",
                "lockfileVersion": 3,
                "packages": {},
            }),
            encoding="utf-8",
        )
        proc = subprocess.run(
            [
                _osv_scanner_bin(),
                "scan",
                "source",
                "--offline",
                "--no-ignore",
                "--allow-no-lockfiles",
                "-L",
                str(lockfile),
                "--format",
                "json",
            ],
            capture_output=True,
            text=True,
            timeout=30,
            check=True,
        )
        payload = json.loads(proc.stdout)
        assert payload.get("results") == []
