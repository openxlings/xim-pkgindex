"""测试 gost 包"""
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import threading
import time

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home

PKG = "gost"
PKG_FILE = "pkgs/g/gost.lua"


@pytest.fixture(scope='module')
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
    def test_resource_architecture_mapping(self):
        lua = shutil.which("lua5.4") or shutil.which("lua")
        assert lua, "Lua is required to evaluate the resource matrix"
        source = r'''
function import() end
assert(loadfile(arg[1]))()
local expected = {
    linux = {x86_64="amd64", aarch64="arm64"},
    macosx = {x86_64="amd64", aarch64="arm64"},
    windows = {x86_64="amd64", aarch64="arm64"},
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        assert(#entry.sha256[arch] == 64, platform .. "/" .. arch)
        local auto = package.extensions.autoupdate.resources.GLOBAL.url[platform][arch]
        local resolved = p.source:gsub("%${arch_alias}", alias)
        assert(auto == resolved, "installer/updater URLs disagree")
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unexpected arch") end
end
assert(count == 6)
assert(package.xpm.windows[package.xpm.windows.latest.ref].sha256.armv7 == nil)
'''
        subprocess.run([lua, "-", PKG_FILE], input=source, text=True, check=True,
                       cwd=Path(__file__).resolve().parents[2], capture_output=True)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        recipe = Path(__file__).resolve().parents[2] / PKG_FILE
        run_xlings("config", "--add-xpkg", str(recipe))


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


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        run_xlings("install", under_test(PKG), "--yes", "--agent")


def run_xlings(*args):
    # Native argv avoids Windows' WSL bash.exe and shell-profile PATH changes.
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for package lifecycle checks"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def executable():
    suffix = ".exe" if os.name == "nt" else ""
    bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
    if not bindir.is_dir():
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
    shim = bindir / ("gost" + suffix)
    assert shim.is_file(), f"Missing installed GOST shim: {shim}"
    return str(shim)


class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        result = subprocess.run([executable(), "-V"], capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        assert re.match(r"gost \d+\.\d+\.\d+\b", result.stdout), result.stdout
        if os.environ.get("XLINGS_TEST_VERSION"):
            assert result.stdout.split()[1] == os.environ["XLINGS_TEST_VERSION"]

    @pytest.mark.verify
    def test_registration(self):
        assert_xvm_registered("gost")

    @pytest.mark.verify
    def test_local_http_proxy(self, tmp_path):
        # Exercise an actual request, with no external host or proxy bypass.
        body = b"gost isolated proxy smoke test"

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        origin = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=origin.serve_forever, daemon=True)
        thread.start()
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        with (tmp_path / "gost.log").open("w+") as log:
            process = subprocess.Popen([executable(), "-L", f"http://127.0.0.1:{port}"],
                                       cwd=tmp_path, stdout=log, stderr=log)
            connection = None
            try:
                deadline = time.monotonic() + 15
                while True:
                    if process.poll() is not None:
                        log.seek(0)
                        pytest.fail("GOST exited before listening: " + log.read())
                    try:
                        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                            break
                    except OSError:
                        assert time.monotonic() < deadline, "GOST did not start listening"
                        time.sleep(0.05)
                connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                connection.request("GET", f"http://127.0.0.1:{origin.server_port}/gost-test")
                response = connection.getresponse()
                assert response.status == 200
                assert response.read() == body
            finally:
                if connection:
                    connection.close()
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                origin.shutdown()
                origin.server_close()
                thread.join(timeout=5)
