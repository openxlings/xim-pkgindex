"""Tests for fq's portable binaries and offline binary/JSON queries."""
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import zlib

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
    assert_valid_xvm_node_kinds, assert_config_registers_package_name,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager, assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home

PKG = "fq"
PKG_FILE = "pkgs/f/fq.lua"
VERSION = "0.18.0"
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


def _run_lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", PKG_FILE], input=script, text=True,
        capture_output=True, check=True, cwd=REPO,
    ).stdout


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
        assert_valid_xvm_node_kinds(meta)
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_all_six_targets_and_update_urls(self, meta):
        assert set(meta.platforms) == {"linux", "macosx", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.licenses[1] == "MIT")
assert(package.ci.mirror and package.xvm_enable)
assert(#package.programs == 1 and package.programs[1] == "fq")
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/wader/fq/releases")
assert(auto.resources.GLOBAL.required == true)
local hashes = {
 linux = {
  x86_64 = "07d9407c0cde116f6d9244b5d477a4570c917fef33d6e77c46ed58a38bf5e2b3",
  aarch64 = "761f857a583c404646701272baa3e7b67ffa961bafd7e325fec184990eeb024f",
 },
 macosx = {
  x86_64 = "743cd7527691cd7ab1bdb536b397d226e2775416771f17594075540acd2c017c",
  aarch64 = "93fc660e455d2f4a64a82555b0b9406fd7bc177a5f9fe3cd638d03e883078cdd",
 },
 windows = {
  x86_64 = "b255a2f2716a25132607f235e6cb564659ad037eb8bf48d60815edd82f21758d",
  aarch64 = "420ea5bec0d9e6a5edffbc3d87a3763aa3ac71b756aa5e66a39e8d460a028f12",
 },
}
local count = 0
for plat, arches in pairs(hashes) do
 local section = assert(package.xpm[plat])
 assert(section.latest.ref == "0.18.0")
 local ver = section["0.18.0"]
 for arch, hash in pairs(arches) do
  assert(ver.sha256[arch] == hash)
  local alias = arch == "x86_64" and "amd64" or "arm64"
  assert(ver.arch_alias[arch] == alias)
  local osname = plat == "macosx" and "macos" or plat
  local ext = plat == "linux" and ".tar.gz" or ".zip"
  local expected = "https://github.com/wader/fq/releases/download/v0.18.0/fq_0.18.0_" .. osname .. "_" .. alias .. ext
  local url = section.source:gsub("%${version}", "0.18.0"):gsub("%${arch_alias}", alias)
  local update = auto.resources.GLOBAL.url[plat][arch]:gsub("%${tag}", "v0.18.0"):gsub("%${version}", "0.18.0")
  assert(url == expected and update == expected)
  count = count + 1
 end
 for arch in pairs(ver.sha256) do assert(arches[arch]) end
end
assert(count == 6)
''')

    @pytest.mark.static
    def test_flat_archives_and_missing_payload(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local files, commands, moves, adds, removes
local dir = "/installed/fq"
local host, archive, exe
pkginfo = {
 name = function() return "fq" end,
 install_file = function() return archive end,
 install_dir = function() return dir end,
}
os.host = function() return host end
os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function() files[dir .. "/fq"] = nil; files[dir .. "/fq.exe"] = nil end
os.mv = function(src, dst) moves[#moves+1] = {src, dst}; files[dst] = files[src]; files[src] = nil end
fs = { mkdir_p = function() end }
log = { info = function() end }
system = { exec = function(cmd)
 commands[#commands+1] = cmd
 if not cmd:find("chmod", 1, true) then files[dir .. "/" .. exe] = true end
end }
xvm = {
 add = function(name, opts) adds[#adds+1] = {name, opts} end,
 remove = function(name) removes[#removes+1] = name end,
}
for _, platform in ipairs({"linux", "macos", "windows"}) do
 host = platform == "macos" and "macosx" or platform
 exe = platform == "windows" and "fq.exe" or "fq"
 archive = "/cache/fq_0.18.0_" .. platform .. "_amd64" .. (platform == "linux" and ".tar.gz" or ".zip")
 files, commands, moves, adds, removes = {[archive] = true}, {}, {}, {}, {}
 assert(not installed())
 assert(install() and installed())
 local needle = platform == "windows" and "System32\\\\tar.exe" or (platform == "macos" and "unzip -q" or "tar -xzf")
 assert(commands[1]:find(needle, 1, true), commands[1])
 assert(#commands == (platform == "windows" and 1 or 2))
 assert(config() and adds[1][1] == "fq" and adds[1][2].bindir == dir)
 assert(uninstall() and removes[1] == "fq")
 -- Framework may have removed the archive after extracting its flat binary.
 files, commands, moves = {["/cache/" .. exe] = true}, {}, {}
 assert(install() and installed())
 assert(moves[1][1] == "/cache/" .. exe and moves[1][2] == dir .. "/" .. exe)
 files = {}
 assert(not pcall(install), "missing payload must fail")
 -- A decompressor that produces nothing must not count as installation.
 files = {[archive] = true}
 system.exec = function() end
 assert(not pcall(install), "empty extraction must fail")
 system.exec = function(cmd)
  commands[#commands+1] = cmd
  if not cmd:find("chmod", 1, true) then files[dir .. "/" .. exe] = true end
 end
end
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_isolation(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        src = (REPO / PKG_FILE).read_text()
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.system",
            "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestIndex:
    @pytest.mark.index
    def test_register(self):
        _run_xlings("config", "--add-xpkg", str(REPO / PKG_FILE), timeout=45)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _run_xlings(
            "install",
            under_test(PKG, os.environ.get("XLINGS_TEST_VERSION", VERSION)),
            "-y",
            timeout=180,
        )


class TestVerify:
    def _run_fq(self, *args, stdin_text=None):
        suffix = ".exe" if os.name == "nt" else ""
        root = Path(xlings_home()) / "subos"
        bindir = root / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = root / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / (PKG + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run([str(shim), *args], input=stdin_text,
                                capture_output=True, text=True, encoding="utf-8", timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    @pytest.mark.verify
    def test_version(self):
        assert os.environ.get("XLINGS_TEST_VERSION", VERSION) in self._run_fq("--version")

    @pytest.mark.verify
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_decode_png_dimensions(self, tmp_path):
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        png = tmp_path / "two-pixels.png"
        png.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\0\xff\0\0\0\xff\0"))
            + chunk(b"IEND", b"")
        )
        out = self._run_fq("-c", "-V", "-d", "png",
                           '[.chunks[] | select(.type == "IHDR") | {width, height, bit_depth, color_type}]',
                           str(png))
        assert json.loads(out) == [{"width": 2, "height": 1, "bit_depth": 8, "color_type": "rgb"}]

    @pytest.mark.verify
    def test_json_filter_and_transform(self):
        out = self._run_fq(
            "-c", "-d", "json", '[.items[] | select(.enabled) | .value * 2] | add',
            stdin_text='{"items":[{"enabled":true,"value":3},{"enabled":false,"value":100},{"enabled":true,"value":4}]}\n',
        )
        assert json.loads(out) == 14
