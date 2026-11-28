"""Tests for the revive package and offline Go-file linting."""
import json
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
    assert_valid_xvm_node_kinds,
    assert_config_registers_package_name,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home

PKG = "revive"
PKG_FILE = "pkgs/r/revive.lua"
VERSION = "1.17.1"
REPO = Path(__file__).resolve().parents[2]


def _run_xlings(*args: str, timeout: int = 180) -> str:
    """Invoke xlings directly so login shells cannot redirect it through WSL."""
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for package index and lifecycle checks"
    result = subprocess.run(
        [command, *args], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=timeout,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args], input=script, text=True, capture_output=True,
        check=True, cwd=REPO,
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
    def test_platform_matrix_and_autoupdate(self, meta):
        assert set(meta.platforms) == {"linux", "macosx", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.repo == "https://github.com/revive-lint/revive")
assert(package.xvm_enable and package.programs[1] == "revive")
local auto = package.extensions.autoupdate
assert(auto.source == package.repo .. "/releases")
assert(auto.resources.GLOBAL.required == true and auto.resources.CN == nil)
local urls = auto.resources.GLOBAL.url
local hashes, count = {}, 0
for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = package.xpm[plat]
    assert(section.latest.ref == arg[2] and section.deps == nil)
    local ver = section[arg[2]]
    local n = 0
    for arch, alias in pairs({x86_64 = "amd64", aarch64 = "arm64"}) do
        assert(ver.arch_alias[arch] == alias)
        local hash = assert(ver.sha256[arch])
        assert(#hash == 64 and hash:match("^%x+$") and not hashes[hash])
        hashes[hash] = true
        local resolved = section.source:gsub("%${version}", arg[2]):gsub("%${arch_alias}", alias)
        assert(resolved == urls[plat][arch]:gsub("%${tag}", "v" .. arg[2]))
        assert(resolved:match("%.tar%.gz$"))
        count = count + 1
    end
    for _ in pairs(ver.sha256) do n = n + 1 end
    assert(n == 2)
end
assert(count == 6)
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_tar_hooks_and_required_payload(self):
        _run_lua(r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local files, commands, adds, removes, moves
local archive, dir, ext
local omit_readme = false
pkginfo = {
    name = function() return "revive" end,
    install_file = function() return archive end,
    install_dir = function() return dir end,
}
os.getenv = function(key) if key == "SystemRoot" then return "C:/Windows" end end
os.isfile = function(p) return files[p] == true end
os.tryrm = function() end
os.mv = function(src, dst)
    assert(files[src], "missing move source " .. src)
    files[src], files[dst] = nil, true
    table.insert(moves, {src, dst})
end
fs = { mkdir_p = function() end }
system = { exec = function(cmd)
    table.insert(commands, cmd)
    if cmd:find(" -xf ", 1, true) then
        files[dir .. "/revive" .. ext], files[dir .. "/LICENSE"] = true, true
        if not omit_readme then files[dir .. "/README.md"] = true end
    end
end }
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(removes, name) end,
}
for _, platform in ipairs({"linux", "darwin", "windows"}) do
    for _, arch in ipairs({"amd64", "arm64"}) do
        files, commands, adds, removes, moves = {}, {}, {}, {}, {}
        local win = platform == "windows"
        ext = win and ".exe" or ""
        archive = (win and "C:/cache/" or "/cache/") .. "revive_" .. platform .. "_" .. arch .. ".tar.gz"
        dir = win and "C:/xpkgs/revive/1.17.1" or "/xpkgs/revive/1.17.1"
        files[archive] = true
        assert(not installed())
        assert(install() and installed())
        assert(#commands == (win and 1 or 2))
        if win then
            assert(commands[1] == 'C:\\Windows\\System32\\tar.exe -xf "' .. winpath.native(archive) .. '" -C "' .. winpath.native(dir) .. '"')
        else
            assert(commands[1] == 'tar -xf "' .. archive .. '" -C "' .. dir .. '"')
            assert(commands[2] == 'chmod +x "' .. dir .. '/revive"')
        end
        assert(config() and adds[1][1] == "revive" and adds[1][2].bindir == dir)
        assert(uninstall() and removes[1] == "revive")
        files[dir .. "/LICENSE"] = nil
        assert(not installed(), "a binary without the license is incomplete")
        files, commands, moves = {}, {}, {}
        local parent = archive:match("^(.*)/[^/]+$")
        for _, f in ipairs({"revive" .. ext, "LICENSE", "README.md"}) do files[parent .. "/" .. f] = true end
        assert(install() and installed() and #moves == 3)
    end
end
files = {}
assert(not pcall(install), "missing archive must fail")
files[archive] = true
omit_readme = true
assert(not pcall(install), "incomplete extraction must fail")
''', PKG_FILE)


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
    def test_portable_api_boundary(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.system",
            "xim.libxpkg.xvm", "xim.pkgindex.payload", "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        _run_xlings("config", "--add-xpkg", str(REPO / PKG_FILE), timeout=45)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _run_xlings("install", under_test(PKG, VERSION), "-y", timeout=180)


class TestVerify:
    def _shim(self):
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / "default" / "bin"
        shim = bindir / (PKG + (".exe" if os.name == "nt" else ""))
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    @pytest.mark.verify
    def test_version(self):
        result = subprocess.run([str(self._shim()), "-version"], capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, result.stderr
        assert os.environ.get("XLINGS_TEST_VERSION", VERSION) in result.stdout

    @pytest.mark.verify
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_offline_named_diagnostic_and_clean_source(self, tmp_path):
        config = tmp_path / "revive.toml"
        config.write_text('confidence = 0.8\n[rule.exported]\n', encoding="utf-8")
        bad = tmp_path / "bad.go"
        bad.write_text("package fixture\n\nfunc Exported() {}\n", encoding="utf-8")
        clean = tmp_path / "clean.go"
        clean.write_text("package fixture\n\n// Exported documents the function.\nfunc Exported() {}\n", encoding="utf-8")
        # An empty PATH proves file-only linting does not invoke the Go SDK.
        empty_path = tmp_path / "empty-bin"
        empty_path.mkdir()
        env = {**os.environ, "PATH": str(empty_path), "GOPROXY": "off", "GOSUMDB": "off",
               "GOTOOLCHAIN": "local", "GOENV": "off", "GOWORK": "off"}
        def lint(source):
            result = subprocess.run(
                [str(self._shim()), "-config", str(config), "-formatter", "json", "-set_exit_status", str(source)],
                cwd=tmp_path, env=env, capture_output=True, text=True, timeout=30,
            )
            assert not result.stderr, result.stderr
            return result.returncode, json.loads(result.stdout)
        code, diagnostics = lint(bad)
        assert code == 1
        assert len(diagnostics) == 1
        diagnostic = diagnostics[0]
        assert diagnostic["RuleName"] == "exported"
        assert diagnostic["Severity"] == "warning"
        assert "Exported should have comment" in diagnostic["Failure"]
        assert diagnostic["Position"]["Start"]["Line"] == 3
        assert Path(diagnostic["Position"]["Start"]["Filename"]) == bad
        code, diagnostics = lint(clean)
        assert code == 0 and diagnostics in (None, [])
