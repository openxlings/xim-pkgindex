"""Tests for the trufflehog package."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "trufflehog"
PKG_FILE = "pkgs/t/trufflehog.lua"
VERSION = "3.100.1"
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
    def test_platforms_arches_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "trufflehog")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/trufflesecurity/trufflehog/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}

local count = 0
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == ver, "latest.ref mismatch in " .. plat)
    local entry = assert(section[ver], "missing " .. ver .. " in " .. plat)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, plat .. "/" .. arch .. " alias mismatch")
        local h = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        assert(tmpl:find("${tag}", 1, true), "autoupdate must use ${tag}: " .. plat .. "/" .. arch)
        local resolved_au = tmpl:gsub("%${tag}", "v" .. ver):gsub("%${version}", ver)
        local resolved_xpm = section.source:gsub("%${version}", ver):gsub("%${arch_alias}", alias)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch " .. arch .. " in " .. plat)
    end
end
assert(count == 6)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local ver = arg[2]

-- 1. POSIX flat .tar.gz extracted directly into install_dir
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
local function populate(root, exe)
    files[root .. "/" .. exe] = true
    files[root .. "/LICENSE"] = true
    files[root .. "/README.md"] = true
    files[root .. "/docs/man/trufflehog.1"] = true
end

pkginfo = {
    name = function() return "trufflehog" end,
    version = function() return ver end,
    install_file = function() return "/cache/trufflehog_" .. ver .. "_linux_amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/trufflehog/" .. ver end,
}
files["/cache/trufflehog_" .. ver .. "_linux_amd64.tar.gz"] = true
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k:sub(1, #p) == p then files[k] = nil end
    end
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xzf") then
            populate("/xpkgs/trufflehog/" .. ver, "trufflehog")
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/trufflehog_' .. ver .. '_linux_amd64.tar.gz" -C "/xpkgs/trufflehog/' .. ver .. '"')
assert(execs[2] == 'chmod +x "/xpkgs/trufflehog/' .. ver .. '/trufflehog"')
assert(installed())

files["/xpkgs/trufflehog/" .. ver .. "/docs/man/trufflehog.1"] = nil
assert(not installed(), "accepted missing docs/man/trufflehog.1")
files["/xpkgs/trufflehog/" .. ver .. "/docs/man/trufflehog.1"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "trufflehog" and adds[1][2].bindir == "/xpkgs/trufflehog/" .. ver)
assert(uninstall())
assert(#rms == 1 and rms[1] == "trufflehog")

-- 2. Windows flat .tar.gz extracted via System32\\tar.exe
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "trufflehog" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/trufflehog_" .. ver .. "_windows_amd64.tar.gz" end,
    install_dir = function() return "C:/xpkgs/trufflehog/" .. ver end,
}
files["C:/cache/trufflehog_" .. ver .. "_windows_amd64.tar.gz"] = true
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        populate("C:/xpkgs/trufflehog/" .. ver, "trufflehog.exe")
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\trufflehog_' .. ver .. '_windows_amd64.tar.gz" -C "C:\\\\xpkgs\\\\trufflehog\\\\' .. ver .. '"')
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "trufflehog" and adds[1][2].bindir == "C:/xpkgs/trufflehog/" .. ver)
assert(uninstall())
assert(#rms == 1 and rms[1] == "trufflehog")
''',
            PKG_FILE,
            VERSION,
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
            "xim.pkgindex.payload",
            "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


@skip_if_not("linux")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


@skip_if_not("linux")
class TestVerify:
    def _run_trufflehog(self, *args, check_rc=0):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("trufflehog" + suffix)
        if not shim.is_file():
            found = shutil.which("trufflehog")
            assert found, f"Missing installed shim: {shim}"
            shim = Path(found)
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        if check_rc is not None:
            assert result.returncode == check_rc, (
                f"rc={result.returncode}: {result.stdout + result.stderr}"
            )
        return result.returncode, result.stdout, result.stderr

    @pytest.mark.verify
    def test_version(self):
        _, stdout, stderr = self._run_trufflehog("--version")
        out = stdout + stderr
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert f"trufflehog {expected}" in out, out

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos_name = "current" if (subos_dir / "current").is_dir() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos_name)
        assert_xvm_registered("trufflehog")

    @pytest.mark.verify
    def test_dir_scan_offline(self):
        with tempfile.TemporaryDirectory() as work:
            clean = Path(work) / "clean.txt"
            clean.write_text("hello world\n", encoding="utf-8")
            _, out_clean, err_clean = self._run_trufflehog(
                "filesystem", str(work), "--no-update", "--no-verification", "--fail", "--json"
            )
            assert out_clean.strip() == "", out_clean + err_clean

            # Assemble synthetic token dynamically so the test file contains no literal secret.
            secret_file = Path(work) / "sample.env"
            token = "ghp_" + ("Z9x8Y7w6V5u4T3s2R1q0P9o8N7m6L5k4J3i2")
            secret_file.write_text(f"GITHUB_TOKEN={token}\n", encoding="utf-8")
            rc, out_leak, err_leak = self._run_trufflehog(
                "filesystem",
                str(work),
                "--no-update",
                "--no-verification",
                "--fail",
                "--json",
                check_rc=None,
            )
            assert rc == 183, f"expected exit 183 on detected secret, got {rc}: {out_leak + err_leak}"
            finding = json.loads(out_leak.strip().splitlines()[0])
            assert finding["DetectorName"] == "Github", finding
            assert finding["Raw"] == token, finding
