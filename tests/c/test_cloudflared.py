"""Tests for the cloudflared package."""
import os
from pathlib import Path
import re
import shutil
import subprocess

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
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "cloudflared"
PKG_FILE = "pkgs/c/cloudflared.lua"
VERSION = "2026.11.2"
REPO = Path(__file__).resolve().parents[2]


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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["cloudflared"]
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "cloudflared")

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == ver, platform .. " latest should be " .. ver)
    local entry = assert(p[version], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), platform .. "/" .. arch)
        local auto = package.extensions.autoupdate.resources.GLOBAL.url[platform][arch]
        local resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        local expanded_auto = auto:gsub("%${tag}", version):gsub("%${version}", version)
        assert(expanded_auto == resolved, "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 5)
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_installed_install_config_uninstall_linux_macos_and_windows(self):
        _run_lua('''
import = function() end
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local ver = arg[2]

-- Case 1: Linux raw binary -> install_dir/cloudflared + chmod +x
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "cloudflared" end,
    version = function() return ver end,
    install_file = function() return "/cache/cloudflared-linux-amd64" end,
    install_dir = function() return "/xpkgs/cloudflared/" .. ver end,
}
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k == p or k:sub(1, #p + 1) == p .. "/" then files[k] = nil end
    end
end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
files["/cache/cloudflared-linux-amd64"] = true
assert(install())
assert(installed())
assert(files["/xpkgs/cloudflared/" .. ver .. "/cloudflared"])
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/cloudflared/' .. ver .. '/cloudflared"')
assert(config())
assert(#adds == 1 and adds[1][1] == "cloudflared" and adds[1][2].bindir == "/xpkgs/cloudflared/" .. ver and adds[1][2].alias == nil)
assert(uninstall())
assert(#rms == 1 and rms[1] == "cloudflared")

-- Case 2: macOS install (pkgutil --expand-full cloudflared-arm64.pkg -> Payload/cloudflared)
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "cloudflared" end,
    version = function() return ver end,
    install_file = function() return "/cache/cloudflared-arm64.pkg" end,
    install_dir = function() return "/xpkgs/cloudflared/" .. ver end,
}
files["/cache/cloudflared-arm64.pkg"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^pkgutil %-%-expand%-full") then
            files["/xpkgs/cloudflared/" .. ver .. "/._pkg/Payload/cloudflared"] = true
        end
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(files["/xpkgs/cloudflared/" .. ver .. "/cloudflared"])
assert(not files["/xpkgs/cloudflared/" .. ver .. "/._pkg/Payload/cloudflared"])
assert(#execs == 2)
assert(execs[1] == 'pkgutil --expand-full "/cache/cloudflared-arm64.pkg" "/xpkgs/cloudflared/' .. ver .. '/._pkg"')
assert(execs[2] == 'chmod +x "/xpkgs/cloudflared/' .. ver .. '/cloudflared"')
assert(config())
assert(#adds == 1 and adds[1][1] == "cloudflared" and adds[1][2].bindir == "/xpkgs/cloudflared/" .. ver and adds[1][2].alias == nil)

-- Case 3: Windows raw .exe -> install_dir/cloudflared.exe + alias = cloudflared.exe
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "cloudflared" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/cloudflared-windows-amd64.exe" end,
    install_dir = function() return "C:/xpkgs/cloudflared/" .. ver end,
}
files["C:/cache/cloudflared-windows-amd64.exe"] = true
assert(not installed())
assert(install())
assert(installed())
assert(files["C:/xpkgs/cloudflared/" .. ver .. "/cloudflared.exe"])
assert(#execs == 0)
assert(config())
assert(#adds == 1 and adds[1][1] == "cloudflared" and adds[1][2].bindir == "C:/xpkgs/cloudflared/" .. ver and adds[1][2].alias == "cloudflared.exe")
assert(uninstall())
assert(#rms == 1 and rms[1] == "cloudflared")

-- Case 4: Missing binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
''', PKG_FILE, VERSION)


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
    def _shim(self, prog: str) -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        candidates = []
        if os.environ.get("XLINGS_TEST_SUBOS"):
            candidates.append(os.environ["XLINGS_TEST_SUBOS"])
        candidates.extend(["current", "default"])
        for subos in candidates:
            shim = Path(xlings_home()) / "subos" / subos / "bin" / (prog + suffix)
            if shim.is_file():
                return shim
        found = shutil.which(prog)
        assert found, f"Missing installed shim for {prog} in {xlings_home()}/subos or PATH"
        return Path(found)

    def _run_prog(self, prog: str, *args: str) -> str:
        shim = self._shim(prog)
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_cloudflared_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        out = self._run_prog("cloudflared", "--version")
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_cloudflared_help(self):
        out = self._run_prog("cloudflared", "--help")
        assert "Cloudflare's command-line tool" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            for candidate in ("current", "default"):
                if (Path(xlings_home()) / "subos" / candidate / ".xlings.json").is_file():
                    monkeypatch.setenv("XLINGS_TEST_SUBOS", candidate)
                    break
        assert_xvm_registered("cloudflared")
