"""Portable grex metadata, payload closure, and real-shim semantic tests."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "grex"
PKG_FILE = "pkgs/g/grex.lua"
ROOT = Path(__file__).resolve().parents[2]


def _lua(script):
    interpreter = shutil.which("lua5.4") or shutil.which("lua")
    if not interpreter:
        pytest.skip("Lua interpreter is unavailable")
    subprocess.run(
        [interpreter, "-", PKG_FILE], input=script, text=True,
        capture_output=True, check=True, cwd=ROOT,
    )


def _xlings(*arguments):
    executable = "xlings.exe" if os.name == "nt" else "xlings"
    binary = Path(xlings_home()) / "bin" / executable
    assert binary.is_file(), binary
    return subprocess.run(
        [str(binary), *arguments], capture_output=True, text=True,
        check=True, timeout=120,
    )


def _shim():
    executable = "grex.exe" if os.name == "nt" else "grex"
    names = (os.environ.get("XLINGS_TEST_SUBOS", "current"), "default")
    for name in names:
        candidate = Path(xlings_home()) / "subos" / name / "bin" / executable
        if candidate.is_file():
            return str(candidate)
    pytest.fail("Missing grex shim in the test xlings home")


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert meta.spec == "2"
        assert_valid_type(meta)
        assert_valid_xvm_node_kinds(meta)
        assert_no_typos(PKG_FILE)
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_installer_and_updater_matrix(self):
        _lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.name == "grex" and package.xvm_enable)
assert(package.licenses[1] == "Apache-2.0" and #package.licenses == 1)
assert(package.programs[1] == "grex" and #package.programs == 1)
assert(package.ci.mirror and package.ci.update == nil)
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/pemistahl/grex/releases")
assert(auto.resources.CN == nil and auto.resources.GLOBAL.required)
local count = 0
for platform, entry in pairs(package.xpm) do
    assert(entry.latest.ref == "1.4.6")
    if platform == "windows" then
        assert(entry.deps.runtime[1] == "xim:vcruntime")
        assert(entry["1.4.6"].sha256.aarch64 == nil)
        assert(auto.resources.GLOBAL.url.windows.aarch64 == nil)
    else
        assert(entry.deps == nil)
        assert(entry["1.4.6"].sha256.aarch64)
    end
    for arch, digest in pairs(entry["1.4.6"].sha256) do
        assert(arch == "x86_64" or arch == "aarch64")
        assert(#digest == 64 and digest:match("^[0-9a-f]+$"))
        local actual = entry.source:gsub("%${version}", "1.4.6"):gsub("%${arch}", arch)
        local future = assert(auto.resources.GLOBAL.url[platform][arch])
        future = future:gsub("%${tag}", "v1.4.6"):gsub("%${version}", "1.4.6")
        assert(actual == future, platform .. "/" .. arch)
        count = count + 1
    end
end
assert(count == 5)
''')

    @pytest.mark.static
    def test_payload_and_runtime_checks(self):
        _lua(r'''
function import() end
local files, commands, registrations = {}, {}, {}
local archive, dir, host = "/dl/grex.tar.gz", "/store/grex", "linux"
pkginfo = {
    name = function() return "grex" end,
    install_dir = function() return dir end,
    install_file = function() return archive end,
    dep_install_dir = function(name) assert(name == "xim:vcruntime"); return "/crt" end,
}
os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.host = function() return host end
os.getenv = function() return "C:\\Windows" end
os.tryrm = function() files[dir .. "/grex"] = nil; files[dir .. "/grex.exe"] = nil end
os.mv = function(src, dst) assert(files[src]); files[src] = nil; files[dst] = true end
os.cp = function(src, dst) assert(files[src]); files[dst .. "/vcruntime140.dll"] = true end
fs = { mkdir_p = function() end, files = function() return {"/crt/bin/vcruntime140.dll"} end }
log = {info = function() end}
system = {exec = function(cmd)
    commands[#commands + 1] = cmd
    if cmd:find("tar", 1, true) then files[dir .. (host == "windows" and "/grex.exe" or "/grex")] = true end
end}
xvm = {
    add = function(name, opt) assert(name == "grex" and opt.bindir == dir); registrations[#registrations + 1] = "add" end,
    remove = function(name) assert(name == "grex"); registrations[#registrations + 1] = "remove" end,
}
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
assert(loadfile(arg[1]))()
assert(not installed())
files[archive] = true
assert(install() and installed())
assert(commands[1]:find("'-xzf'", 1, true))
files[archive] = nil
files["/dl/grex"] = true
assert(install() and installed() and not files["/dl/grex"])
files[dir .. "/grex"] = nil
assert(not installed())
local ok, err = pcall(install)
assert(not ok and err:find("pre-extracted executable", 1, true))
archive, host, commands = "C:/dl/grex.zip", "windows", {}
files["/crt/bin/vcruntime140.dll"] = true
assert(install() and installed())
assert(commands[1]:find("C:\\Windows\\System32\\tar.exe", 1, true))
files[dir .. "/vcruntime140.dll"] = nil
assert(not installed())
fs.files = function() return {} end
ok, err = pcall(install)
assert(not ok and err:find("xim:vcruntime payload", 1, true))
assert(config() and uninstall())
assert(table.concat(registrations, ",") == "add,remove")
''')


class TestIsolation:
    @pytest.mark.isolation
    @pytest.mark.parametrize("check", [
        assert_no_exec_xvm, assert_no_bashrc_modification,
        assert_no_direct_path_modification, assert_uses_new_api,
        assert_no_direct_pkg_manager,
    ])
    def test_subos_contract(self, check):
        check(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_hook_api(self):
        source = (ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', source)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|os\.(?:host|arch|exists|curdir)\(|is_host\(|try\s*\{|raise\()', source)


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
        result = subprocess.run([_shim(), "--version"], capture_output=True, text=True, check=True, timeout=15)
        expected = os.environ.get("XLINGS_TEST_VERSION", "1.4.6")
        assert result.stdout.strip() == f"grex {expected}"

    @pytest.mark.verify
    def test_payload_files(self):
        namespace = under_test(PKG).split(":", 1)[0]
        version = os.environ.get("XLINGS_TEST_VERSION", "1.4.6")
        payload = Path(xlings_home()) / "data" / "xpkgs" / f"{namespace}-x-{PKG}" / version
        required = ("grex.exe", "vcruntime140.dll") if os.name == "nt" else ("grex",)
        for filename in required:
            assert (payload / filename).is_file(), payload / filename

    @pytest.mark.verify
    @pytest.mark.parametrize("options,examples,additional,negatives", [
        ([], ["cat", "car", "cart"], [], ["dog", "scar", "carts", "cats", ""]),
        (["--digits"], ["item-123", "item-456", "item-789"], ["item-000"],
         ["item-abc", "ITEM-123", "item-12", "item-1234", "xitem-123", "item-123x"]),
    ])
    def test_generated_regex_semantics(self, options, examples, additional, negatives):
        # ASCII inputs and --digits use syntax shared by Rust regex and stdlib re.
        # No --colorize: verify a plain expression, not optimizer-specific spelling.
        result = subprocess.run(
            [_shim(), *options, *examples], capture_output=True, text=True,
            check=True, timeout=15, env={**os.environ, "NO_COLOR": "1"},
        )
        expression = result.stdout.strip()
        assert "\x1b" not in expression
        pattern = re.compile(expression)
        for example in examples + additional:
            assert pattern.fullmatch(example), (expression, example)
        for negative in negatives:
            assert pattern.search(negative) is None, (expression, negative)
