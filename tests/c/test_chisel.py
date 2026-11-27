"""Portable recipe checks and a real loopback-only chisel forward tunnel."""
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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "chisel"
VERSION = "1.12.0"
PKG_FILE = "pkgs/c/chisel.lua"
ROOT = Path(__file__).resolve().parents[2]


def _lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua is required for recipe hook regression tests")
    return subprocess.run(
        [lua, "-", str(ROOT / PKG_FILE), *args], input=script,
        text=True, capture_output=True, check=True, timeout=15,
    ).stdout


@pytest.mark.static
def test_metadata_and_complete_official_matrix():
    meta = parse_xpkg(PKG_FILE)
    for check in (assert_required_fields, assert_valid_spec, assert_valid_type,
                  assert_valid_xvm_node_kinds, assert_config_registers_package_name):
        check(meta)
    assert_no_typos(PKG_FILE)
    _lua(r'''
import = function() end
dofile(arg[1])
assert(package.spec == "2" and package.name == "chisel")
assert(package.licenses[1] == "MIT")
assert(package.xvm_enable and package.programs[1] == "chisel")
assert(#package.archs == 2 and package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/jpillora/chisel/releases")
assert(auto.resources.GLOBAL.required and not auto.resources.CN)
assert(not package.ci or not package.ci.update)
local count = 0
for platform, expected in pairs({linux={"linux", "gz"}, macosx={"darwin", "gz"}, windows={"windows", "zip"}}) do
    local section = assert(package.xpm[platform])
    assert(section.latest.ref == "1.12.0" and not section.deps)
    local version = section[section.latest.ref]
    for arch, alias in pairs({x86_64="amd64", aarch64="arm64"}) do
        assert(version.arch_alias[arch] == alias)
        local hash = assert(version.sha256[arch])
        assert(#hash == 64 and not hash:find("[^0-9a-f]"))
        local suffix = "chisel_${version}_" .. expected[1] .. "_" .. alias .. "." .. expected[2]
        assert(auto.resources.GLOBAL.url[platform][arch] == "https://github.com/jpillora/chisel/releases/download/${tag}/" .. suffix)
        assert(section.source == "https://github.com/jpillora/chisel/releases/download/v${version}/chisel_${version}_" .. expected[1] .. "_${arch_alias}." .. expected[2])
        count = count + 1
    end
end
assert(count == 6)
''')


@pytest.mark.static
@pytest.mark.parametrize("windows,preextracted", [(False, False), (False, True), (True, False)])
def test_shared_required_files_and_native_hooks(windows, preextracted):
    _lua(r'''
local windows = arg[2] == "true"
local preextracted = arg[3] == "true"
local files, commands, adds, removes = {}, {}, {}, {}
import = function() end
os.getenv = function(key) if key == "OS" and windows then return "Windows_NT" end end
os.isfile = function(path) return files[path] == true end
os.tryrm = function() end
os.mv = function(src, dst) assert(files[src]); files[src] = nil; files[dst] = true end
fs = {mkdir_p=function() end}
pkginfo = {
    install_dir=function() return "/install/chisel" end,
    install_file=function() return windows and "/cache/chisel_windows_arm64.zip" or "/cache/chisel_linux_amd64.gz" end,
}
shell = {exec=function(argv)
    commands[#commands+1] = argv
    if argv[1] == "sh" then
        assert(argv[2] == "-c" and argv[3] == 'gzip -dc "$1" > "$2"')
        assert(argv[5] == "/cache/chisel_linux_amd64.gz" and argv[6] == "/install/chisel/chisel")
        files[argv[6]] = true
    end
end}
xvm = {add=function(name, opt) adds[name] = opt.bindir end, remove=function(name) removes[name] = true end}
local exe = windows and "chisel.exe" or "chisel"
local function required(list)
    assert(#list == 1 and list[1] == exe)
    return files["/install/chisel/" .. exe] == true
end
payload = {
    present=required,
    require=function(list) assert(required(list)) end,
    unpack=function(opt)
        assert(windows and opt.extracted == "chisel_windows_arm64")
        files["/install/chisel/chisel.exe"] = true
    end,
}
dofile(arg[1])
assert(not installed())
if not windows then
    local ok, err = pcall(install)
    assert(not ok and err:match("gzip payload missing"))
    files["/cache/chisel_linux_amd64" .. (preextracted and "" or ".gz")] = true
end
assert(install() and installed())
if windows then
    assert(#commands == 0)
else
    assert(#commands == (preextracted and 1 or 2))
    assert(commands[#commands][1] == "chmod" and commands[#commands][2] == "+x")
end
assert(config() and adds.chisel == "/install/chisel")
assert(uninstall() and removes.chisel)
files["/install/chisel/" .. exe] = nil
assert(not installed())
''', str(windows).lower(), str(preextracted).lower())


@pytest.mark.isolation
@pytest.mark.parametrize("check", [
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_no_direct_pkg_manager,
    assert_uses_new_api,
])
def test_isolation(check):
    check(PKG_FILE)


@pytest.mark.isolation
def test_only_supported_hook_apis():
    src = (ROOT / PKG_FILE).read_text()
    assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
        "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
        "xim.libxpkg.xvm", "xim.pkgindex.payload", "xim.pkgindex.shell",
    }
    assert not re.search(r"\b(?:path\.|is_host\(|os\.(?:host|arch|exists|curdir)\(|raise\()", src)


@pytest.mark.index
def test_register():
    assert_xim_add_succeeds(PKG_FILE)


@pytest.mark.lifecycle
def test_install():
    assert_install_succeeds(under_test(PKG), timeout=180)


def _shim():
    subos = Path(xlings_home()) / "subos"
    names = dict.fromkeys((os.environ.get("XLINGS_TEST_SUBOS", "current"), "default"))
    for name in names:
        shim = subos / name / "bin" / ("chisel.exe" if os.name == "nt" else "chisel")
        if shim.is_file():
            return str(shim)
    pytest.fail(f"Missing installed chisel shim under {subos}")


@pytest.mark.verify
def test_version():
    proc = subprocess.run([_shim(), "--version"], capture_output=True, text=True,
                          check=True, timeout=15)
    assert os.environ.get("XLINGS_TEST_VERSION", VERSION) in proc.stdout + proc.stderr


def _reserve_port():
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    return sock


def _assert_running(processes, logs):
    for process, log in zip(processes, logs):
        assert process.poll() is None, log.read_text(errors="replace")


def _wait_listening(port, processes, logs):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        _assert_running(processes, logs)
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                return
        except OSError:
            time.sleep(0.05)  # Bounded readiness polling, not startup delay.
    pytest.fail("chisel did not listen: " + "\n".join(p.read_text() for p in logs))


@pytest.mark.verify
def test_loopback_forward_roundtrip_and_cleanup(tmp_path):
    payload = b"chisel isolated forward tunnel\nexact payload: 0123456789\n"

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            assert self.path == "/portable-proof"
            self.send_response(200)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, *args):
            pass

    endpoint = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    endpoint.daemon_threads = True
    endpoint_port = endpoint.server_address[1]
    thread = threading.Thread(target=endpoint.serve_forever, daemon=True)
    thread.start()
    processes, logs, streams, reservations = [], [], [], []
    ports = [endpoint_port]
    try:
        server_socket, forward_socket = _reserve_port(), _reserve_port()
        reservations.extend((server_socket, forward_socket))
        server_port, forward_port = (s.getsockname()[1] for s in reservations)
        ports.extend((server_port, forward_port))
        # The CLI does not expose the bound address for --port 0. Reserve OS-
        # assigned ports until immediately before starting each real listener.
        server_socket.close()
        server_log = tmp_path / "server.log"
        streams.append(server_log.open("wb"))
        logs.append(server_log)
        processes.append(subprocess.Popen(
            [_shim(), "server", "--host", "127.0.0.1", "--port", str(server_port)],
            stdout=streams[-1], stderr=subprocess.STDOUT, cwd=tmp_path,
        ))
        _wait_listening(server_port, processes, logs)
        forward_socket.close()
        client_log = tmp_path / "client.log"
        streams.append(client_log.open("wb"))
        logs.append(client_log)
        processes.append(subprocess.Popen(
            [_shim(), "client", f"http://127.0.0.1:{server_port}",
             f"127.0.0.1:{forward_port}:127.0.0.1:{endpoint_port}"],
            stdout=streams[-1], stderr=subprocess.STDOUT, cwd=tmp_path,
        ))
        _wait_listening(forward_port, processes, logs)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            _assert_running(processes, logs)
            connection = http.client.HTTPConnection("127.0.0.1", forward_port, timeout=0.5)
            try:
                connection.request("GET", "/portable-proof")
                response = connection.getresponse()
                assert response.status == 200
                assert response.read() == payload
                break
            except (OSError, http.client.HTTPException):
                time.sleep(0.05)
            finally:
                connection.close()
        else:
            pytest.fail("Tunnel roundtrip timed out: " + "\n".join(p.read_text() for p in logs))
    finally:
        for reservation in reservations:
            reservation.close()
        for process in reversed(processes):
            if process.poll() is None:
                if os.name == "nt":
                    # Windows shims wait for a child rather than execing it.
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   capture_output=True, check=True, timeout=10)
                else:
                    process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        endpoint.shutdown()
        endpoint.server_close()
        thread.join(timeout=5)
        for stream in streams:
            stream.close()
    assert not thread.is_alive()
    assert all(process.poll() is not None for process in processes)
    for port in ports:
        with socket.socket() as probe:
            probe.settimeout(0.3)
            assert probe.connect_ex(("127.0.0.1", port)) != 0, f"Listener leaked on {port}"
