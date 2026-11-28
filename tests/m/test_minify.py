"""Portable package checks and bounded, offline minify CLI proofs."""
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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "minify"
PKG_FILE = "pkgs/m/minify.lua"
ROOT = Path(__file__).resolve().parents[2]


def _lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter unavailable")
    subprocess.run(
        [lua, "-", PKG_FILE], input=script, text=True,
        capture_output=True, check=True, cwd=ROOT, timeout=10,
    )


def _xlings(*args):
    name = "xlings.exe" if os.name == "nt" else "xlings"
    native = Path(xlings_home()) / "bin" / name
    executable = str(native) if native.is_file() else shutil.which(name)
    assert executable, f"Native {name} executable unavailable"
    result = subprocess.run(
        [executable, *args], capture_output=True, text=True, timeout=180,
        cwd=ROOT, env=os.environ.copy(),
    )
    assert result.returncode == 0, result.stdout + result.stderr


def _minify(*args, source=None):
    exe = "minify.exe" if os.name == "nt" else "minify"
    for subos in ("current", "default"):
        shim = Path(xlings_home()) / "subos" / subos / "bin" / exe
        if shim.is_file():
            result = subprocess.run(
                [str(shim), *args], input=source, text=True,
                capture_output=True, timeout=10,
            )
            assert result.returncode == 0, result.stdout + result.stderr
            return result.stdout
    pytest.fail(f"No installed minify shim under {xlings_home()}")


class TestStatic:
    @pytest.mark.static
    @pytest.mark.parametrize("check", [
        assert_required_fields, assert_valid_spec, assert_valid_type,
        assert_valid_xvm_node_kinds, assert_config_registers_package_name,
    ])
    def test_metadata(self, check):
        check(parse_xpkg(PKG_FILE))

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_exact_matrix_and_updater_urls(self):
        _lua('''
import = function() end
dofile(arg[1])
assert(package.spec == "2" and package.name == "minify")
assert(package.licenses[1] == "MIT" and package.xvm_enable)
assert(#package.programs == 1 and package.programs[1] == "minify")
local au = package.extensions.autoupdate
assert(au.source == "https://github.com/tdewolff/minify/releases")
assert(au.resources.GLOBAL.required == true and au.resources.CN == nil)
local expected = {
    linux = {x86_64 = "amd64", aarch64 = "arm64"},
    macosx = {x86_64 = "amd64", aarch64 = "arm64"},
    windows = {x86_64 = "amd64"},
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    assert(p.latest.ref == "2.25.0")
    local entry = assert(p["2.25.0"])
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias)
        local sha = assert(entry.sha256[arch])
        assert(#sha == 64 and sha:match("^%x+$"))
        local url = p.source:gsub("%${version}", "2.25.0"):gsub("%${arch_alias}", alias)
        local update = au.resources.GLOBAL.url[platform][arch]:gsub("%${tag}", "v2.25.0")
        assert(url == update, platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch]) end
    for arch in pairs(au.resources.GLOBAL.url[platform]) do assert(arches[arch]) end
end
assert(count == 5)
assert(package.xpm.windows["2.25.0"].sha256.aarch64 == nil)
''')

    @pytest.mark.static
    def test_payload_hooks_and_missing_file_failures(self):
        _lua('''
import = function() end
winpath = dofile("libs/winpath.lua")
payload = dofile("libs/payload.lua")
dofile(arg[1])
local files, dirs, commands, moved, adds, removes = {}, {}, {}, {}, {}, {}
local archive = "/cache/minify_linux_amd64.tar.gz"
local dir = "/packages/minify/2.25.0"
pkginfo = {
    name = function() return "minify" end,
    install_file = function() return archive end,
    install_dir = function() return dir end,
}
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
os.tryrm = function(p)
    for name in pairs(files) do
        if name:sub(1, #p + 1) == p .. "/" then files[name] = nil end
    end
end
os.mv = function(src, dst)
    assert(files[src], src)
    files[src], files[dst] = nil, true
    moved[#moved + 1] = src
end
fs = {mkdir_p = function(p) dirs[p] = true end}
log = {info = function() end}
system = {exec = function(cmd)
    commands[#commands + 1] = cmd
    if cmd:find(" %-xzf ") or cmd:find(" %-xf ") then
        files[dir .. (archive:match("%.zip$") and "/minify.exe" or "/minify")] = true
        files[dir .. "/LICENSE"] = true
    end
end}
xvm = {
    add = function(name, opt) adds[#adds + 1] = {name, opt.bindir} end,
    remove = function(name) removes[#removes + 1] = name end,
}
assert(not installed())
files[archive] = true
assert(install() and installed())
assert(commands[1] == 'tar -xzf "' .. archive .. '" -C "' .. dir .. '"')
assert(commands[2] == 'chmod +x "' .. dir .. '/minify"')
files[dir .. "/LICENSE"] = nil
assert(not installed(), "binary without license is incomplete")
files, commands = {}, {}
files["/cache/minify"], files["/cache/LICENSE"] = true, true
assert(install() and installed() and #moved == 2)
files, commands = {}, {}
archive = "/cache/minify_windows_amd64.zip"
files[archive] = true
assert(install() and installed())
assert(#commands == 1 and commands[1]:find("System32\\\\tar.exe", 1, true))
files = {[archive] = true}
system.exec = function() files[dir .. "/minify.exe"] = true end
local ok, err = pcall(install)
assert(not ok and err:find("LICENSE", 1, true), "missing license must fail install")
files = {}
ok = pcall(install)
assert(not ok, "empty payload must fail install")
assert(config() and adds[1][1] == "minify" and adds[1][2] == dir)
assert(uninstall() and removes[1] == "minify")
''')


class TestIsolation:
    @pytest.mark.isolation
    @pytest.mark.parametrize("check", [
        assert_no_exec_xvm, assert_no_bashrc_modification,
        assert_no_direct_path_modification, assert_uses_new_api,
        assert_no_direct_pkg_manager,
    ])
    def test_isolation(self, check):
        check(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_api_boundary(self):
        source = (ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', source)) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.system",
            "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|raise\(|os\.(?:arch|host|exists|curdir)\()', source)


class TestIndex:
    @pytest.mark.index
    def test_register(self):
        _xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _xlings("install", under_test(PKG), "-y")


class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "2.25.0")
        assert f"minify v{expected}" in _minify("--version")

    @pytest.mark.verify
    def test_json_stdin_preserves_semantics(self):
        data = {"message": "keep these spaces", "values": [1, True, None], "nested": {"count": 2}}
        source = json.dumps(data, indent=4) + "\n"
        compact = _minify("--type", "json", source=source)
        assert json.loads(compact) == data
        assert compact == json.dumps(data, separators=(",", ":"))
        assert len(compact) < len(source)

    @pytest.mark.verify
    def test_css_stdin_removes_comment_and_whitespace(self):
        source = "/* remove this comment */\n.notice { color: red; margin: 0px; }\n"
        compact = _minify("--type", "css", source=source)
        assert compact == ".notice{color:red;margin:0}"
        assert "/*" not in compact and len(compact) < len(source)
