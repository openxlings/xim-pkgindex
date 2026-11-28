"""Portable gron recipe, isolation, and offline native JSON behavior tests."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import struct
import sys
import tempfile

import pytest

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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "gron"
PKG_FILE = "pkgs/g/gron.lua"
ROOT = Path(__file__).resolve().parents[2]


def _xlings(*args):
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for native package checks"
    proc = subprocess.run(
        [command, *args], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=180,
    )
    output = proc.stdout + proc.stderr
    assert proc.returncode == 0 and "[error]" not in output.lower(), output
    return output


def _gron(*args, input=None):
    suffix = ".exe" if os.name == "nt" else ""
    home = Path(xlings_home())
    subos = os.environ.get("XLINGS_TEST_SUBOS", "default")
    binary = home / "subos" / subos / "bin" / ("gron" + suffix)
    assert binary.is_file(), f"Missing installed gron shim: {binary}"
    return subprocess.run(
        [str(binary), *args], input=input, capture_output=True,
        text=True, encoding="utf-8", check=True, timeout=15,
    ).stdout


def _lua(script, *args):
    command = shutil.which("lua5.4") or shutil.which("lua")
    if not command:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [command, "-", *map(str, args)], input=script,
        capture_output=True, text=True, check=True, cwd=ROOT,
    ).stdout


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_config_registers_package_name(meta)
        assert_no_typos(PKG_FILE)
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_six_target_resources_and_updater(self):
        _lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2")
assert(package.licenses[1] == "MIT")
assert(package.xvm_enable)
assert(#package.programs == 1 and package.programs[1] == "gron")
assert(#package.archs == 2 and package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
assert(#package.xpm.linux.deps.runtime == 1)
assert(package.xpm.linux.deps.runtime[1] == "xim:glibc@>=2.44.3")
assert(package.xpm.macosx.deps == nil and package.xpm.windows.deps == nil)
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/tomnomnom/gron/releases")
assert(auto.resources.GLOBAL.required == true and auto.resources.CN == nil)
local count = 0
local platforms = {linux = "linux", macosx = "darwin", windows = "windows"}
for platform, upstream in pairs(platforms) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    assert(version == "0.7.1")
    for arch, alias in pairs({x86_64 = "amd64", aarch64 = "arm64"}) do
        assert(entry.arch_alias[arch] == alias)
        local hash = assert(entry.sha256[arch])
        assert(#hash == 64 and hash:match("^[0-9a-f]+$"))
        local resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        local extension = platform == "windows" and ".zip" or ".tgz"
        local expected = "https://github.com/tomnomnom/gron/releases/download/v" .. version
            .. "/gron-" .. upstream .. "-" .. alias .. "-" .. version .. extension
        assert(resolved == expected)
        local template = assert(auto.resources.GLOBAL.url[platform][arch])
        assert(template:gsub("%${tag}", "v" .. version):gsub("%${version}", version) == resolved)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arch == "x86_64" or arch == "aarch64") end
end
for platform in pairs(package.xpm) do assert(platforms[platform]) end
assert(count == 6)
''', PKG_FILE)

    @pytest.mark.static
    def test_hooks_flat_archives_license_and_missing_payload(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("downloads", "install"):
                (Path(tmp) / name).mkdir()
            _lua(r'''
function import() end
local root = arg[2]
local src, dst = root .. "/downloads", root .. "/install"
local archive, host = "", "linux"
local calls = {}
local patched, skipped = 0, 0
local function write(path, value)
    local f = assert(io.open(path, "wb")); assert(f:write(value)); assert(f:close())
end
local function read(path)
    local f = assert(io.open(path, "rb")); local data = f:read("*a"); f:close(); return data
end
local loader = root .. "/managed-loader"
write(loader, "managed runtime")
_RUNTIME = {deps_exports = {["xim:glibc@>=2.44.3"] = {loader = loader}}}
elfpatch = {
    skip = function() skipped = skipped + 1 end,
    set_interpreter = function(file, selected)
        assert(file == dst .. "/gron" and selected == loader)
        assert(read(file) == "linux-amd64")
        patched = patched + 1
        return {patched = 1, failed = 0}
    end,
}
os.isfile = function(path) local f = io.open(path, "rb"); if f then f:close(); return true end; return false end
os.isdir = function() return false end
os.host = function() return host end
os.tryrm = function(dir)
    assert(dir == dst)
    for _, file in ipairs({"gron", "gron.exe", "LICENSE"}) do os.remove(dir .. "/" .. file) end
end
os.mv = function(from, to) assert(os.rename(from, to)) end
fs = {mkdir_p = function(dir) assert(dir == dst) end}
log = {info = function() end}
pkginfo = {
    install_file = function() return archive end,
    install_dir = function() return dst end,
    name = function() return "gron" end,
}
system = {exec = function(command)
    calls[#calls + 1] = command
    if host == "windows" then
        assert(command:find("\\System32\\tar.exe", 1, true))
        write(dst .. "/gron.exe", "windows zip payload")
    else
        assert(command == 'chmod +x "' .. dst .. '/gron"')
    end
end}
xvm = {
    add = function(name, opt) assert(name == "gron" and opt.bindir == dst); calls[#calls + 1] = "add" end,
    remove = function(name) assert(name == "gron"); calls[#calls + 1] = "remove" end,
}
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
assert(loadfile(arg[1]))()
for _, target in ipairs({"linux-amd64", "linux-arm64", "darwin-amd64", "darwin-arm64", "windows-amd64", "windows-arm64"}) do
    host = target:match("^windows") and "windows" or "linux"
    local exe = host == "windows" and "gron.exe" or "gron"
    archive = src .. "/gron-" .. target .. "-0.7.1" .. (host == "windows" and ".zip" or ".tgz")
    write(src .. "/" .. exe, target)
    assert(install() and installed())
    assert(read(dst .. "/" .. exe) == target)
    local license = read(dst .. "/LICENSE")
    assert(license:find("Copyright (c) 2016 Tom Hudson", 1, true))
    assert(license:find('THE SOFTWARE IS PROVIDED "AS IS"', 1, true))
    os.remove(dst .. "/LICENSE")
    assert(not installed(), "binary without license is incomplete")
    os.remove(dst .. "/" .. exe)
end
assert(patched == 1 and skipped == 2, "only dynamic Linux gets an interpreter; static Linux skips auto patching")
archive = src .. "/gron-linux-amd64-0.7.1.tgz"
host = "linux"
write(src .. "/gron", "linux-amd64")
local exports = _RUNTIME
_RUNTIME = {}
local sealed, reason = pcall(install)
assert(not sealed and tostring(reason):find("no resolved runtime exports", 1, true))
_RUNTIME = exports
-- Unextracted Windows ZIP must use the shared pinned-system-tar path.
archive = src .. "/gron-windows-arm64-0.7.1.zip"
host = "windows"
assert(install() and installed())
os.remove(dst .. "/gron.exe")
assert(not installed(), "license alone is incomplete")
archive = src .. "/gron-linux-amd64-0.7.1.tgz"
host = "linux"
local ok, err = pcall(install)
assert(not ok and tostring(err):find("extracted binary not found", 1, true))
payload = {present = {}, require = {}}
assert(not pcall(installed), "unknown-module proxies must not report installed")
assert(not pcall(install), "unknown-module proxies must not report installation success")
assert(config() and uninstall())
assert(calls[#calls - 1] == "add" and calls[#calls] == "remove")
''', PKG_FILE, tmp)


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
            "xim.libxpkg.xvm", "xim.libxpkg.elfpatch", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|try\s*\{|raise\()', source)


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        _xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        local_index = Path(xlings_home()) / "data" / "xim-pkgindex-local"
        shutil.copytree(ROOT / "libs", local_index / "libs", dirs_exist_ok=True)
        output = _xlings("search", PKG)
        assert "local:gron" in output, output


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _xlings("install", under_test(PKG, "0.7.1"), "-y")


class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        version = os.environ.get("XLINGS_TEST_VERSION", "0.7.1")
        expected = {f"gron version {version}", f"gron version v{version}"}
        # Official v0.7.1 builds omit linker version metadata; do not patch binaries.
        if version == "0.7.1":
            expected.add("gron version dev")
        assert _gron("--version").strip() in expected

    @pytest.mark.verify
    def test_nested_json_assignment_round_trip(self):
        value = {
            "project": {"name": "gron", "active": True},
            "items": [{"id": 7}, {"id": 9}], "empty": None, "tags": [],
        }
        assignments = _gron(input=json.dumps(value))
        assert assignments.splitlines() == [
            "json = {};", "json.empty = null;", "json.items = [];",
            "json.items[0] = {};", "json.items[0].id = 7;",
            "json.items[1] = {};", "json.items[1].id = 9;",
            "json.project = {};", "json.project.active = true;",
            'json.project.name = "gron";', "json.tags = [];",
        ]
        assert json.loads(_gron("--ungron", input=assignments)) == value

    @pytest.mark.verify
    def test_filter_then_ungron_selects_only_intended_field(self):
        source = {"project": {"name": "gron", "active": True}, "other": {"name": "excluded"}}
        assignments = _gron(input=json.dumps(source))
        filtered = "\n".join(
            line for line in assignments.splitlines()
            if line.startswith("json.project.name = ")
        ) + "\n"
        assert filtered == 'json.project.name = "gron";\n'
        assert json.loads(_gron("--ungron", input=filtered)) == {"project": {"name": "gron"}}

    @pytest.mark.verify
    def test_linux_managed_runtime_closure(self):
        if sys.platform != "linux":
            pytest.skip("ELF runtime closure applies only to Linux")
        home = Path(xlings_home()).resolve()
        binaries = list((home / "data" / "xpkgs").glob("*-x-gron/0.7.1/gron"))
        assert len(binaries) == 1, binaries
        binary = binaries[0]
        data = binary.read_bytes()
        assert data[:6] == b"\x7fELF\x02\x01", "Expected little-endian ELF64"
        machine = struct.unpack_from("<H", data, 18)[0]
        offset = struct.unpack_from("<Q", data, 32)[0]
        size, count = struct.unpack_from("<HH", data, 54)
        loaders = []
        for index in range(count):
            segment = offset + index * size
            if struct.unpack_from("<I", data, segment)[0] == 3:  # PT_INTERP
                start = struct.unpack_from("<Q", data, segment + 8)[0]
                length = struct.unpack_from("<Q", data, segment + 32)[0]
                loaders.append(Path(data[start:start + length].rstrip(b"\0").decode()))
        if machine == 183:  # Official Linux aarch64 binary is static.
            assert not loaders
            return
        assert machine == 62 and len(loaders) == 1, loaders
        loader = loaders[0].resolve()
        assert loader.is_file() and loader.is_relative_to(home), loader
        env = {key: value for key, value in os.environ.items() if key != "LD_LIBRARY_PATH"}
        output = subprocess.run(
            [str(loader), "--inhibit-cache", "--list", str(binary)],
            capture_output=True, text=True, check=True, timeout=15, env=env,
        ).stdout
        resolved = {}
        for line in output.splitlines():
            name, separator, location = line.strip().partition(" => ")
            if separator and name in {"libc.so.6", "libpthread.so.0"}:
                resolved[name] = Path(location.rsplit(" (", 1)[0]).resolve()
        assert set(resolved) == {"libc.so.6", "libpthread.so.0"}, output
        for library in resolved.values():
            assert library.is_file() and library.is_relative_to(home), output

    @pytest.mark.verify
    def test_license_installed(self):
        licenses = list((Path(xlings_home()) / "data" / "xpkgs").glob("*-x-gron/0.7.1/LICENSE"))
        assert licenses, "No installed gron MIT license"
        for license_file in licenses:
            assert "Copyright (c) 2016 Tom Hudson" in license_file.read_text(encoding="utf-8")


class TestUninstall:
    @pytest.mark.lifecycle
    def test_remove(self):
        _xlings("remove", under_test(PKG, "0.7.1"), "-y")
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "default")
        shim = Path(xlings_home()) / "subos" / subos / "bin" / ("gron" + suffix)
        assert not shim.exists() and not shim.is_symlink(), f"Leftover gron shim: {shim}"
