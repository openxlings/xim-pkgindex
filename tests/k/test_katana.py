"""Portable Katana package checks and a deterministic, loopback-only crawl."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import threading

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

PKG = "katana"
VERSION = "1.8.0"
PKG_FILE = "pkgs/k/katana.lua"
ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.static
def test_metadata_and_official_matrix():
    meta = parse_xpkg(PKG_FILE)
    for check in (assert_required_fields, assert_valid_spec, assert_valid_type,
                  assert_valid_xvm_node_kinds, assert_config_registers_package_name):
        check(meta)
    assert_no_typos(PKG_FILE)
    assert meta.spec == "2" and meta.programs == [PKG]
    assert set(meta.platforms) == {"linux", "macosx", "windows"}
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua 5.3+ is required to validate the resource matrix"
    subprocess.run([lua, "-", str(ROOT / PKG_FILE)], input=r'''
import = function() end
dofile(arg[1])
assert(package.licenses[1] == "MIT" and package.xvm_enable)
assert(package.ci.mirror and not package.ci.update)
assert(#package.archs == 2 and package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
local count, seen = 0, {}
for platform, upstream in pairs({linux="linux", macosx="macOS", windows="windows"}) do
    local section = assert(package.xpm[platform])
    assert(section.latest.ref == "1.8.0" and not section.deps)
    local entry = assert(section[section.latest.ref])
    for arch, alias in pairs({x86_64="amd64", aarch64="arm64"}) do
        assert(entry.arch_alias[arch] == alias)
        local digest = assert(entry.sha256[arch])
        assert(#digest == 64 and not digest:find("[^0-9a-f]") and not seen[digest])
        seen[digest] = true
        local resolved = section.source:gsub("%${version}", "1.8.0"):gsub("%${arch_alias}", alias)
        assert(resolved == "https://github.com/projectdiscovery/katana/releases/download/v1.8.0/katana_1.8.0_" .. upstream .. "_" .. alias .. ".zip")
        count = count + 1
    end
end
assert(count == 6)
''', text=True, capture_output=True, check=True, timeout=10)


@pytest.mark.isolation
@pytest.mark.parametrize("check", [
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_no_direct_pkg_manager,
    assert_uses_new_api,
])
def test_isolation(check):
    check(PKG_FILE)


def _bindir():
    root = Path(xlings_home()) / "subos"
    selected = os.environ.get("XLINGS_TEST_SUBOS")
    if selected:
        return root / selected / "bin"
    return root / ("current" if (root / "current").is_dir() else "default") / "bin"


def _shim():
    shim = _bindir() / ("katana.exe" if os.name == "nt" else "katana")
    assert shim.is_file(), "The installed Katana SubOS shim is missing"
    return str(shim)


def _native_xlings(*args):
    suffix = ".exe" if os.name == "nt" else ""
    candidate = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    executable = str(candidate) if candidate.is_file() else shutil.which("xlings" + suffix)
    assert executable, "xlings is unavailable"
    env = dict(os.environ, XLINGS_HOME=xlings_home(), XLINGS_BIN=str(_bindir()),
               XLINGS_SUBOS_LIB=str(_bindir().parent / "lib"))
    proc = subprocess.run([executable, *args], stdin=subprocess.DEVNULL,
                          capture_output=True, text=True, timeout=180, env=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    return proc.stdout + proc.stderr


@pytest.mark.index
def test_register():
    _native_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
    assert PKG in _native_xlings("search", PKG)


@pytest.mark.lifecycle
def test_install_and_idempotence():
    coordinate = under_test(PKG, os.environ.get("XLINGS_TEST_VERSION", VERSION))
    _native_xlings("install", coordinate, "-y")
    assert Path(_shim()).is_file()
    output = _native_xlings("install", coordinate, "-y")
    assert "already installed" in output.lower(), output


def _run_katana(args, tmp_path):
    # Katana creates a default form config at runtime, even in standard mode.
    # Isolate HOME on every platform, suppress inherited authentication/proxies,
    # and never let the feature test use real user configuration or credentials.
    env = {key: value for key, value in os.environ.items()
           if not key.lower().endswith("_proxy") and key not in {
               "AUTH_CREDENTIALS", "CAPTCHA_SOLVER_KEY", "CAPTCHA_SOLVER_PROVIDER",
           }}
    for key in ("HOME", "USERPROFILE", "XDG_CONFIG_HOME", "APPDATA", "LOCALAPPDATA"):
        env[key] = str(tmp_path)
    env["NO_PROXY"] = "*"
    options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
    process = subprocess.Popen([_shim(), "-disable-update-check", *args],
                               stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True, encoding="utf-8",
                               cwd=tmp_path, env=env, **options)
    try:
        stdout, stderr = process.communicate(timeout=20)
        assert process.returncode == 0, stdout + stderr
        return stdout + stderr
    finally:
        if process.poll() is None:
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               capture_output=True, check=True, timeout=10)
            else:
                os.killpg(process.pid, signal.SIGKILL)
            process.communicate(timeout=5)
        for stream in (process.stdout, process.stderr):
            stream.close()


@pytest.mark.verify
def test_version(tmp_path):
    output = _run_katana(["-version"], tmp_path)
    assert os.environ.get("XLINGS_TEST_VERSION", VERSION) in output, output


@pytest.mark.verify
def test_crawl_discovers_and_fetches_linked_page(tmp_path):
    seen = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            seen.append(self.path)
            if self.path == "/":
                content = b'<html><body><a href="/katana-proof.html">Discover this page</a></body></html>'
            elif self.path == "/katana-proof.html":
                content = b"<html><body>A distinct offline crawler proof page.</body></html>"
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def log_message(self, *_args):
            pass

    server = HTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05})
    thread.start()
    try:
        base = f"http://127.0.0.1:{server.server_address[1]}"
        output = _run_katana([
            "-u", base + "/", "-silent", "-no-color", "-depth", "2",
            "-concurrency", "1", "-parallelism", "1", "-retry", "0",
            "-timeout", "2", "-crawl-duration", "5s", "-disable-redirects",
            "-crawl-scope", "^" + re.escape(base) + r"/(?:|katana-proof\.html)$",
            "-known-files", "", "-headless=false", "-hybrid=false",
            "-kb=false", "-kb-validate-secrets=false",
        ], tmp_path)
        assert base + "/katana-proof.html" in output.splitlines(), output
        assert "/" in seen and "/katana-proof.html" in seen, seen
        assert set(seen) <= {"/", "/katana-proof.html"}, seen
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
    assert not thread.is_alive(), "The fixture HTTP server leaked a thread"


# Keep removal after all verify tests, including when the whole suite is run.
@pytest.mark.lifecycle
def test_remove_last():
    _native_xlings("remove", under_test(PKG), "-y")
    assert not (_bindir() / ("katana.exe" if os.name == "nt" else "katana")).exists()
