"""Tests for the nats-server package."""
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "nats-server"
PKG_FILE = "pkgs/n/nats-server.lua"


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
    def test_all_platforms_and_arches_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "nats-server")
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/nats-io/nats-server/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "2.15.3")
    local ver = assert(section["2.15.3"], "missing 2.15.3 in " .. plat)
    assert(ver.arch_alias and ver.arch_alias.x86_64 == "amd64" and ver.arch_alias.aarch64 == "arm64")
    assert(ver.sha256)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local au = assert(global_url[plat] and global_url[plat][arch])
        local resolved_au = au:gsub("%${tag}", "v2.15.3"):gsub("%${version}", "2.15.3")
        local resolved_xpm = section.source:gsub("%${version}", "2.15.3"):gsub("%${arch_alias}", ver.arch_alias[arch])
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_posix(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
dirs["/cache/nats-server-v2.15.3-linux-amd64"] = true

pkginfo = {
    name = function() return "nats-server" end,
    version = function() return "2.15.3" end,
    install_file = function() return "/cache/nats-server-v2.15.3-linux-amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/nats-server/2.15.3" end,
}
os.host = function() return "linux" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/nats-server"] = true
    files[dst .. "/LICENSE"] = true
end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/nats-server-v2.15.3-linux-amd64" and moved[1][2] == "/xpkgs/nats-server/2.15.3")
assert(installed())

files["/xpkgs/nats-server/2.15.3/nats-server"] = nil
assert(not installed(), "accepted missing nats-server binary")
files["/xpkgs/nats-server/2.15.3/nats-server"] = true
files["/xpkgs/nats-server/2.15.3/LICENSE"] = nil
assert(not installed(), "accepted missing LICENSE")
files["/xpkgs/nats-server/2.15.3/LICENSE"] = true

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "nats-server" and xvm_adds[1][2].bindir == "/xpkgs/nats-server/2.15.3")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "nats-server")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "nats-server" end,
    version = function() return "2.15.3" end,
    install_file = function() return "C:/cache/nats-server-v2.15.3-windows-amd64.zip" end,
    install_dir = function() return "C:/xpkgs/nats-server/2.15.3" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/nats-server/2.15.3/nats-server.exe"] = true
        files["C:/xpkgs/nats-server/2.15.3/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\nats%-server%-v2%.15%.3%-windows%-amd64%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\nats%-server\\\\2%.15%.3"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "nats-server" and xvm_adds[1][2].bindir == "C:/xpkgs/nats-server/2.15.3")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "nats-server")
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
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.pkginfo",
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
    def _shim_path(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("nats-server" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_nats(self, *args):
        result = subprocess.run(
            [str(self._shim_path()), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        out = self._run_nats("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "2.15.3")
        assert f"v{expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("nats-server")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_config_validation_and_server_handshake(self):
        with tempfile.TemporaryDirectory() as work:
            conf = Path(work) / "nats.conf"
            conf.write_text('server_name: "xpkg-verify"\nport: 4222\n', encoding="utf-8")
            out = self._run_nats("-t", "-c", str(conf))
            assert "is valid" in out, out

            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
                probe.bind(("127.0.0.1", 0))
                port = probe.getsockname()[1]

            proc = subprocess.Popen(
                [str(self._shim_path()), "-a", "127.0.0.1", "-p", str(port)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
            )
            try:
                banner = ""
                deadline = time.monotonic() + 5.0
                while time.monotonic() < deadline:
                    try:
                        with socket.create_connection(("127.0.0.1", port), timeout=0.5) as conn:
                            banner = conn.recv(4096).decode("utf-8", errors="replace")
                            if banner.startswith("INFO {"):
                                break
                    except OSError:
                        time.sleep(0.05)
                assert banner.startswith("INFO {"), f"Expected NATS INFO banner, got: {banner!r}"
                assert '"version":"2.15.3"' in banner or '"server_id":' in banner, banner
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)
