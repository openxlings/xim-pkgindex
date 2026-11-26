"""Tests for the q package."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_config_registers_package_name,
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
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "q"
PKG_FILE = "pkgs/q/q.lua"
REPO = Path(__file__).resolve().parents[2]


def _run_xlings(*args: str, timeout: int = 180) -> str:
    """Invoke xlings directly so XLINGS_HOME is never overwritten by login profiles."""
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for package index and lifecycle checks"
    result = subprocess.run(
        [command, *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def _run_lua(script: str, *args: str) -> str:
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        check=True,
        cwd=REPO,
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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping(self):
        _run_lua(r'''
import = function() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "q")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/natesales/q/releases")
local global_res = assert(au.resources and au.resources.GLOBAL)
assert(global_res.required == true)

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64", "aarch64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing xpm." .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest.ref for " .. platform)
    assert(version == "0.19.12", platform .. " latest should be 0.19.12")
    local entry = assert(p[version], "missing version entry for " .. platform)
    assert(entry.arch_alias, "missing arch_alias for " .. platform)
    local allowed = {}
    for _, arch in ipairs(arches) do
        allowed[arch] = true
        local alias = assert(entry.arch_alias[arch], "missing arch_alias for " .. platform .. "/" .. arch)
        local digest = assert(entry.sha256[arch], "missing sha256 for " .. platform .. "/" .. arch)
        assert(type(digest) == "string" and #digest == 64 and digest:match("^[0-9a-f]+$"), platform .. "/" .. arch)
        local auto_tmpl = assert(global_res.url[platform] and global_res.url[platform][arch])
        assert(auto_tmpl:find("${tag}", 1, true), "autoupdate URL must use ${tag}")
        local auto_resolved = auto_tmpl:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local xpm_resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved, "installer/updater URLs disagree for " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(allowed[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_install_config_uninstall_posix_and_windows(self):
        _run_lua(r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
assert(loadfile(arg[1]))()

-- POSIX install: extract flat .tar.gz directly into install_dir + chmod +x
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "q" end,
    version = function() return "0.19.12" end,
    install_file = function() return "/cache/q_0.19.12_linux_amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/q/0.19.12" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^tar %-xzf") then
            files["/xpkgs/q/0.19.12/q"] = true
            files["/xpkgs/q/0.19.12/LICENSE"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
files["/cache/q_0.19.12_linux_amd64.tar.gz"] = true
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/q_0.19.12_linux_amd64.tar.gz" -C "/xpkgs/q/0.19.12"')
assert(execs[2] == 'chmod +x "/xpkgs/q/0.19.12/q"')
assert(config())
assert(#adds == 1 and adds[1][1] == "q" and adds[1][2].bindir == "/xpkgs/q/0.19.12")
assert(uninstall())
assert(#rms == 1 and rms[1] == "q")

-- Windows install via libs/payload.lua (.zip -> System32\tar.exe)
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "q" end,
    version = function() return "0.19.12" end,
    install_file = function() return "C:/cache/q_0.19.12_windows_amd64.zip" end,
    install_dir = function() return "C:/xpkgs/q/0.19.12" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\Windows" or nil end
files["C:/cache/q_0.19.12_windows_amd64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/q/0.19.12/q.exe"] = true
        files["C:/xpkgs/q/0.19.12/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\Windows\\System32\\tar.exe -xf "C:\\cache\\q_0.19.12_windows_amd64.zip" -C "C:\\xpkgs\\q\\0.19.12"')

-- Missing archive and extracted binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
''', PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        _run_xlings("config", "--add-xpkg", str(REPO / PKG_FILE), timeout=45)


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


@skip_if_not("linux")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _run_xlings("install", under_test(PKG), "-y", timeout=180)


@skip_if_not("linux")
class TestVerify:
    @staticmethod
    def _q_bin() -> str:
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("q" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("q")
        assert found, f"Missing q shim ({shim}) and not found on PATH"
        return found

    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "0.19.12")
        proc = subprocess.run(
            [self._q_bin(), "--version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert f"version {expected}" in out, out

    @pytest.mark.verify
    def test_help(self):
        proc = subprocess.run(
            [self._q_bin(), "--help"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert proc.returncode in (0, 1), out
        assert "Usage:" in out, out

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos_name = "current" if (subos_dir / "current").is_dir() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos_name)
        assert_xvm_registered("q")
