"""Tests for the httpx package."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import threading

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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "httpx"
PKG_FILE = "pkgs/h/httpx.lua"
VERSION = "1.12.0"
REPO = Path(__file__).resolve().parents[2]


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
    def test_platforms_arches_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["httpx"]
        _run_lua(
            r'''
import = function() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.name == "httpx", "name must be httpx")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "httpx")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/projectdiscovery/httpx/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)
local global_url = assert(au.resources.GLOBAL.url)

assert(package.xpm.linux.deps == nil, "static linux binaries must declare no runtime deps")
assert(package.xpm.macosx.deps == nil, "macosx binaries must declare no runtime deps")
assert(package.xpm.windows.deps == nil, "static Go windows binary must declare no runtime deps")

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64" },
}
local seen_filenames = {}
local seen_sha = {}
local count = 0
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    local version = assert(section.latest and section.latest.ref, "missing latest.ref: " .. plat)
    assert(version == "1.12.0")
    local entry = assert(section[version], "missing version entry: " .. plat)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias, plat .. "/" .. arch)
        local digest = assert(entry.sha256 and entry.sha256[arch], "missing sha256: " .. plat .. "/" .. arch)
        assert(type(digest) == "string" and #digest == 64 and digest:match("^[0-9a-f]+$"), plat .. "/" .. arch)
        assert(not seen_sha[digest], "duplicate sha256: " .. digest)
        seen_sha[digest] = true
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        assert(tmpl:find("${tag}", 1, true), "autoupdate template must use ${tag}")
        assert(not tmpl:find("${arch_alias}", 1, true), "autoupdate template must not use ${arch_alias}")
        local resolved_au = tmpl:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local resolved_xpm = section.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
        local filename = resolved_xpm:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch " .. arch .. " in " .. plat)
    end
end
assert(count == 5)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    @pytest.mark.skipif(shutil.which("luac") is None, reason="no luac on this machine")
    def test_lua_syntax(self):
        r = subprocess.run(["luac", "-p", str(REPO / PKG_FILE)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        _run_lua(
            r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
assert(loadfile(arg[1]))()

local files, dirs, execs, mvs, adds, rms = {}, {}, {}, {}, {}, {}
local function populate(root, exe)
    files[root .. "/" .. exe] = true
    files[root .. "/LICENSE.md"] = true
    files[root .. "/README.md"] = true
end

-- 1. POSIX flat .zip extracted directly into install_dir via shell.exec (unzip)
pkginfo = {
    name = function() return "httpx" end,
    version = function() return "1.12.0" end,
    install_file = function() return "/cache/httpx_1.12.0_linux_amd64.zip" end,
    install_dir = function() return "/xpkgs/httpx/1.12.0" end,
}
files["/cache/httpx_1.12.0_linux_amd64.zip"] = true
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(mvs, {src, dst})
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^'unzip'") then
            populate("/xpkgs/httpx/1.12.0", "httpx")
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
assert(execs[1] == "'unzip' '-q' '-o' '/cache/httpx_1.12.0_linux_amd64.zip' '-d' '/xpkgs/httpx/1.12.0'")
assert(execs[2] == "'chmod' '+x' '/xpkgs/httpx/1.12.0/httpx'")
assert(installed())

files["/xpkgs/httpx/1.12.0/LICENSE.md"] = nil
assert(not installed(), "must return false when LICENSE.md is missing")
files["/xpkgs/httpx/1.12.0/LICENSE.md"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "httpx" and adds[1][2].bindir == "/xpkgs/httpx/1.12.0")
assert(uninstall())
assert(#rms == 1 and rms[1] == "httpx")

-- 2. Windows flat .zip extracted via libs/payload.lua (System32\tar.exe)
files, dirs, execs, mvs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "httpx" end,
    version = function() return "1.12.0" end,
    install_file = function() return "C:/cache/httpx_1.12.0_windows_amd64.zip" end,
    install_dir = function() return "C:/xpkgs/httpx/1.12.0" end,
}
files["C:/cache/httpx_1.12.0_windows_amd64.zip"] = true
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "OS" then return "Windows_NT" end
    if k == "SystemRoot" then return "C:\\Windows" end
    return nil
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        populate("C:/xpkgs/httpx/1.12.0", "httpx.exe")
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\Windows\\System32\\tar.exe -xf "C:\\cache\\httpx_1.12.0_windows_amd64.zip" -C "C:\\xpkgs\\httpx\\1.12.0"')
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "httpx" and adds[1][2].bindir == "C:/xpkgs/httpx/1.12.0")
assert(uninstall())
assert(#rms == 1 and rms[1] == "httpx")

-- 3. Missing archive and pre-extracted binary must fail
files = {}
os.host = function() return "linux" end
os.getenv = function() return nil end
pkginfo = {
    name = function() return "httpx" end,
    version = function() return "1.12.0" end,
    install_file = function() return "/cache/httpx_1.12.0_linux_amd64.zip" end,
    install_dir = function() return "/xpkgs/httpx/1.12.0" end,
}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
''',
            PKG_FILE,
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
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=120)


@skip_if_not("linux")
class TestVerify:
    def _httpx_bin(self) -> str:
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("httpx" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("httpx")
        assert found, f"Missing installed httpx shim at {shim} or in PATH"
        return found

    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        proc = subprocess.run(
            [self._httpx_bin(), "-version"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert f"v{expected}" in out or expected in out, out

    @pytest.mark.verify
    def test_help(self):
        proc = subprocess.run(
            [self._httpx_bin(), "-h"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert "Usage:" in out and "PROBES:" in out, out

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = "current" if (Path(xlings_home()) / "subos" / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_shim(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS")
        if subos:
            shim = Path(xlings_home()) / "subos" / subos / "bin" / ("httpx" + suffix)
            assert shim.is_file(), f"shim not found at {shim}"
        else:
            assert_xvm_shim_exists(PKG)

    @pytest.mark.verify
    def test_http_probe_loopback(self):
        class _Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(b"<html><head><title>Httpx Loopback</title></head><body>ok</body></html>")

            def log_message(self, format, *args):
                return

        srv = HTTPServer(("127.0.0.1", 0), _Handler)
        port = srv.server_address[1]
        thread = threading.Thread(target=srv.serve_forever, daemon=True)
        thread.start()
        try:
            proc = subprocess.run(
                [
                    self._httpx_bin(),
                    "-u", f"http://127.0.0.1:{port}/",
                    "-sc", "-title", "-silent", "-nc", "-duc", "-json",
                ],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                encoding="utf-8",
                check=True,
                timeout=15,
            )
            record = json.loads(proc.stdout.strip().splitlines()[0])
            assert record["status_code"] == 200, record
            assert record["title"] == "Httpx Loopback", record
        finally:
            srv.shutdown()
            srv.server_close()
