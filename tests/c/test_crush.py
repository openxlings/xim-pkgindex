"""Crush package checks; provider-backed AI requests are deliberately excluded."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
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
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "crush"
PKG_FILE = "pkgs/c/crush.lua"
REPO = Path(__file__).resolve().parents[2]


def _run_lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    subprocess.run(
        [lua, "-", PKG_FILE], input=script, text=True,
        capture_output=True, check=True, cwd=REPO,
    )


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert meta.spec == "2"
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_resource_matrix_matches_updater(self):
        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.licenses[1] == "FSL-1.1-MIT")
assert(package.licenses[2] == "MIT")
local auto = package.extensions.autoupdate
assert(auto.resources.GLOBAL.required)
assert(not auto.resources.CN)
local count = 0
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    assert(not p.deps, "portable binaries must not acquire host dependencies")
    for arch, alias in pairs({x86_64 = "x86_64", aarch64 = "arm64"}) do
        assert(entry.arch_alias[arch] == alias)
        local hash = assert(entry.sha256[arch])
        assert(#hash == 64 and hash:match("^%x+$"))
        local url = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        local updater = auto.resources.GLOBAL.url[platform][arch]
            :gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        assert(url == updater, platform .. "/" .. arch)
        count = count + 1
    end
end
assert(count == 6)
''')

    @pytest.mark.static
    @pytest.mark.parametrize("windows", [False, True])
    def test_wrapped_archive_hooks_and_required_license(self, windows):
        _run_lua('local windows = ' + str(windows).lower() + r'''
import = function() end
local base = windows and "C:/cache/" or "/cache/"
local dir = windows and "C:/package home/crush" or "/package home/crush"
local root = windows and "crush_0.103.0_Windows_arm64" or "crush_0.103.0_Linux_x86_64"
local exe = windows and "crush.exe" or "crush"
local files, dirs, adds, removes = {}, {}, {}, {}
pkginfo = {
    name = function() return "crush" end,
    install_file = function() return base .. root .. (windows and ".zip" or ".tar.gz") end,
    install_dir = function() return dir end,
}
os.host = function() return windows and "windows" or "linux" end
os.getenv = function(k) return k == "SystemRoot" and "C:/Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function() files = {} end
os.mv = function(src, dst)
    assert(src == base .. root and dst == dir)
    files[dir .. "/" .. exe] = true
    files[dir .. "/LICENSE.md"] = true
end
fs = {mkdir_p = function() end}
log = {info = function() end}
local commands = 0
system = {exec = function(cmd)
    assert(windows and cmd:find("System32\\tar.exe", 1, true))
    assert(cmd:find("--strip-components=1", 1, true))
    commands = commands + 1
    files[dir .. "/" .. exe] = true
    files[dir .. "/LICENSE.md"] = true
end}
xvm = {
    add = function(name, opts) adds[#adds + 1] = {name, opts} end,
    remove = function(name) removes[#removes + 1] = name end,
}
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
assert(not installed())
-- POSIX uses the framework's extracted root; Windows exercises zip fallback.
dirs[base .. root] = not windows
assert(install() and installed())
assert(commands == (windows and 1 or 0))
files[dir .. "/LICENSE.md"] = nil
assert(not installed(), "license must remain with the redistributed binary")
files[dir .. "/LICENSE.md"] = true
files[dir .. "/" .. exe] = nil
assert(not installed(), "an install directory alone is not an installation")
assert(config() and #adds == 1)
assert(adds[1][1] == "crush" and adds[1][2].bindir == dir)
assert(uninstall() and #removes == 1 and removes[1] == "crush")
-- Successful extraction command without actual files must fail closed.
os.mv = function() end
system.exec = function() end
assert(not pcall(install), "missing executable and license were accepted")
''')


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        subprocess.run(
            ["xlings", "config", "--add-xpkg", str(REPO / PKG_FILE), "--agent"],
            check=True, capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=45,
        )


class TestIsolation:
    @pytest.mark.isolation
    def test_isolation(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        # Use the native CLI: a bare bash on Windows may be WSL, not Git Bash.
        subprocess.run(
            ["xlings", "install", under_test(PKG), "--yes", "--agent"],
            check=True, capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=180,
        )


class TestVerify:
    @pytest.mark.verify
    def test_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_offline_configuration_schema(self, tmp_path):
        # Do not inherit provider tokens, user credentials or configuration.
        env = {
            "PATH": os.environ.get("PATH", ""),
            "XLINGS_HOME": xlings_home(),
            "HOME": str(tmp_path), "USERPROFILE": str(tmp_path),
            "APPDATA": str(tmp_path / "config"),
            "LOCALAPPDATA": str(tmp_path / "local"),
            "XDG_CONFIG_HOME": str(tmp_path / "config"),
            "XDG_DATA_HOME": str(tmp_path / "data"),
            "XDG_CACHE_HOME": str(tmp_path / "cache"),
        }
        if "SystemRoot" in os.environ:
            env["SystemRoot"] = os.environ["SystemRoot"]
        result = subprocess.run(
            ["crush", "schema"], cwd=tmp_path, env=env, text=True,
            capture_output=True, check=True, timeout=30,
        )
        schema = json.loads(result.stdout)
        assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
        definitions = schema["$defs"]
        assert {"models", "providers", "mcp", "permissions"} <= set(
            definitions["Config"]["properties"]
        )
        provider = definitions["ProviderConfig"]["properties"]
        assert "api_key" in provider
        assert {"messages", "responses", "ollama"} <= set(provider["type"]["enum"])
        assert not list(tmp_path.rglob("crush.json"))
        assert not list(tmp_path.rglob("*.db"))
