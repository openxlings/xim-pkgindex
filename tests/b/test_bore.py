"""Bore: isolated installation and an authenticated, bidirectional TCP tunnel."""
from contextlib import ExitStack
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import time

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification, assert_no_direct_path_modification,
    assert_no_direct_pkg_manager, assert_no_exec_xvm, assert_no_typos,
    assert_required_fields, assert_uses_new_api, assert_valid_spec,
    assert_valid_type, assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG_FILE = "pkgs/b/bore.lua"
VERSION = "0.6.0"


def _xlings(*args):
    name = "xlings.exe" if os.name == "nt" else "xlings"
    executable = Path(xlings_home()) / "bin" / name
    if not executable.is_file():
        executable = shutil.which(name)
    assert executable, "native xlings executable missing"
    return subprocess.run([str(executable), *args], capture_output=True,
                          text=True, timeout=180, check=True)


def _stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def _wait_for_log(process, path, pattern):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        text = path.read_text(encoding="utf-8")
        match = re.search(pattern, text)
        if match:
            return match
        assert process.poll() is None, text
        time.sleep(0.02)
    pytest.fail(f"bore did not become ready: {path.read_text(encoding='utf-8')}")


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_valid_xvm_node_kinds(meta)
        assert_no_typos(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_only(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_registration(self):
        _xlings("config", "--add-xpkg", str(Path(PKG_FILE).resolve()))


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        _xlings("install", under_test("bore", version), "-y")


@pytest.fixture
def bore_paths():
    home = Path(xlings_home())
    base = home / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS") or (
        "current" if (base / "current" / "bin").is_dir() else "default"
    )
    name = "bore.exe" if os.name == "nt" else "bore"
    shim = base / subos / "bin" / name
    assert shim.is_file(), f"missing real bore shim: {shim}"
    version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
    payload = home / "data" / "xpkgs" / (
        "local-x-bore" if under_test("bore").startswith("local:") else "xim-x-bore"
    ) / version / name
    assert payload.is_file(), f"missing bore payload: {payload}"
    if os.name == "nt":
        assert (payload.parent / "vcruntime140.dll").is_file(), "missing app-local CRT"
    return shim, payload


class TestVerify:
    @pytest.mark.verify
    def test_version(self, bore_paths):
        shim, _ = bore_paths
        result = subprocess.run([str(shim), "--version"], capture_output=True,
                                text=True, timeout=15, check=True)
        assert os.environ.get("XLINGS_TEST_VERSION", VERSION) in result.stdout.split()

    @pytest.mark.verify
    def test_authenticated_tcp_round_trip(self, bore_paths, tmp_path):
        _, executable = bore_paths
        # Upstream fixes its control port at 7835; do not talk to another service.
        with socket.socket() as probe:
            try:
                probe.bind(("127.0.0.1", 7835))
            except OSError as error:
                pytest.skip(f"upstream's fixed control port is unavailable: {error}")

        env = os.environ.copy()
        for key in list(env):
            if key.startswith("BORE_"):
                del env[key]
        env.update(NO_COLOR="1", RUST_LOG="info")
        secret = "xlings-loopback-test"
        with ExitStack() as stack:
            listener = stack.enter_context(socket.socket())
            listener.bind(("127.0.0.1", 0))
            listener.listen()
            listener.settimeout(5)
            server_log = tmp_path / "server.log"
            server = subprocess.Popen(
                [str(executable), "server", "--bind-addr", "127.0.0.1",
                 "--bind-tunnels", "127.0.0.1", "--secret", secret],
                env=env, stdout=stack.enter_context(server_log.open("wb")),
                stderr=subprocess.STDOUT,
            )
            stack.callback(_stop, server)
            _wait_for_log(server, server_log, r"server listening")
            client_log = tmp_path / "client.log"
            client = subprocess.Popen(
                [str(executable), "local", str(listener.getsockname()[1]),
                 "--local-host", "127.0.0.1", "--to", "127.0.0.1", "--secret", secret],
                env=env, stdout=stack.enter_context(client_log.open("wb")),
                stderr=subprocess.STDOUT,
            )
            stack.callback(_stop, client)
            match = _wait_for_log(client, client_log, r"remote_port=(\d+)")
            remote = stack.enter_context(socket.create_connection(
                ("127.0.0.1", int(match.group(1))), timeout=5,
            ))
            request = b"xlings bore round trip\x00\xff" * 64
            remote.sendall(request)
            remote.shutdown(socket.SHUT_WR)
            local, _ = listener.accept()
            stack.enter_context(local)
            local.settimeout(5)
            source = stack.enter_context(local.makefile("rb"))
            assert source.read() == request
            response = b"tunnel response\xff\x00" * 64
            local.sendall(response)
            local.shutdown(socket.SHUT_WR)
            destination = stack.enter_context(remote.makefile("rb"))
            assert destination.read() == response
