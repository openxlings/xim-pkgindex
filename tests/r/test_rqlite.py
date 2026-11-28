"""Tests for the rqlite portable client/server package."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_valid_xvm_node_kinds,
    assert_config_registers_package_name,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
)
from tests.lib.platform_utils import current_platform, under_test, xlings_home

PKG = "rqlite"
PKG_FILE = "pkgs/r/rqlite.lua"
VERSION = "10.8.0"
REPO = Path(__file__).resolve().parents[2]
SUPPORTED = pytest.mark.skipif(current_platform() not in {"linux", "windows"}, reason="No upstream macOS portable archive")


def _run_lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", PKG_FILE], input=script, text=True, capture_output=True, check=True, cwd=REPO).stdout


def _run_xlings(*args: str, timeout: int = 180) -> str:
    """Invoke xlings directly so login shells cannot replace XLINGS_HOME."""
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for package index and lifecycle checks"
    result = subprocess.run(
        [command, *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def _shim(program):
    base = Path(xlings_home()) / "subos"
    scope = os.environ.get("XLINGS_TEST_SUBOS", "current")
    bindir = base / scope / "bin"
    if not bindir.is_dir():
        bindir = base / "default" / "bin"
    shim = bindir / (program + (".exe" if os.name == "nt" else ""))
    assert shim.is_file(), f"Missing installed shim: {shim}"
    return shim


def _payload(program):
    namespace = under_test(PKG).split(":")[0]
    version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
    suffix = ".exe" if os.name == "nt" else ""
    return Path(xlings_home()) / "data" / "xpkgs" / f"{namespace}-x-rqlite" / version / (program + suffix)


def _run(program, *args, **kwargs):
    result = subprocess.run([str(_shim(program)), *args], capture_output=True, text=True, timeout=20, **kwargs)
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout + result.stderr


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
        assert set(meta.platforms) == {"linux", "windows"}
        assert meta.programs == ["rqlite", "rqlited"]

    @pytest.mark.static
    def test_verified_matrix_and_autoupdate(self):
        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/rqlite/rqlite/releases")
assert(auto.resources.GLOBAL.required == true and auto.resources.CN == nil)
assert(package.xpm.linux.deps.runtime[1] == "xim:glibc@2.44.3")
assert(package.xpm.linux.deps.build[1] == "xim:patchelf@>=0.19.3")
assert(package.xpm.windows.deps == nil and package.xpm.macosx == nil)
local expected = {
    linux = {
        x86_64 = {"amd64", "3bf0f1dba46b4d069ef3c49dc1fe1d1a05d5ad9d16d1de9daa4afea1f0203038"},
        aarch64 = {"arm64", "a26bb98755bb608cff457e3d0a2161bca42dbe8bc507a6373595c04d44d576f9"},
    },
    windows = {
        x86_64 = {"win64", "a5da71daafe91b5dee72b03753f26b2871725dcc01a508a1fc5b3691e1f5ef07"},
    },
}
for platform, arches in pairs(expected) do
    local section = package.xpm[platform]
    assert(section.latest.ref == "10.8.0")
    local version = section["10.8.0"]
    for arch, asset in pairs(arches) do
        assert(version.sha256[arch] == asset[2])
        local resolved = section.source.GLOBAL:gsub("%${version}", "10.8.0"):gsub("%${arch_alias}", asset[1])
        local update = auto.resources.GLOBAL.url[platform][arch]:gsub("%${tag}", "v10.8.0")
        assert(resolved == update)
    end
    for arch in pairs(version.sha256) do assert(arches[arch]) end
end
assert(package.xpm.windows["10.8.0"].sha256.aarch64 == nil)
''')

    @pytest.mark.static
    def test_payload_hooks_and_namespaced_uninstall(self):
        _run_lua('''
import = function() end
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local files, dirs, adds, removes = {}, {}, {}, {}
local root = "/xpkgs/local-x-rqlite/10.8.0"
local archive = "/cache/rqlite-v10.8.0-linux-amd64.tar.gz"
pkginfo = {
    install_dir = function() return root end,
    install_file = function() return archive end,
    version = function() return "10.8.0" end,
    name = function() return "rqlite" end,
}
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function() end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
os.mv = function(src, dst)
    assert(dirs[src])
    for _, name in ipairs({"rqlite", "rqlited", "rqbench"}) do files[dst .. "/" .. name] = true end
end
xvm = {
    add = function(name, opts) adds[name] = opts end,
    remove = function(name, version) removes[name] = version end,
}
assert(not installed())
dirs["/cache/rqlite-v10.8.0-linux-amd64"] = true
assert(install() and installed() and config())
assert(adds.rqlite.bindir == root and adds.rqlited.bindir == root and adds.rqbench.bindir == root)
assert(adds.rqlited.binding == "rqlite@10.8.0" and adds.rqbench.binding == "rqlite@10.8.0")
assert(uninstall())
for _, name in ipairs({"rqlite", "rqlited", "rqbench"}) do assert(removes[name] == "local:10.8.0") end
files[root .. "/rqlited"] = nil
assert(not installed())
dirs = {}
assert(not pcall(install), "missing extraction must fail")

-- Flat Windows zip: shared payload helper invokes the system tar, no strip.
files, adds, removes = {}, {}, {}
root = "C:/xpkgs/xim-x-rqlite/10.8.0"
archive = "C:/cache/rqlite-v10.8.0-win64.zip"
os.host = function() return "windows" end
winpath = { native = function(p) return p end }
system = { exec = function(command)
    assert(command:find("System32", 1, true) and not command:find("--strip-components", 1, true))
    files[root .. "/rqlite.exe"] = true
    files[root .. "/rqlited.exe"] = true
end }
assert(install() and installed() and config() and uninstall())
assert(adds.rqbench == nil and removes.rqbench == nil)
assert(removes.rqlite == "10.8.0" and removes.rqlited == "10.8.0")
files[root .. "/rqlited.exe"] = nil
assert(not installed())
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_boundaries(self):
        for assertion in (assert_no_exec_xvm, assert_no_bashrc_modification, assert_no_direct_path_modification,
                          assert_uses_new_api, assert_no_direct_pkg_manager):
            assertion(PKG_FILE)
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|os\.arch\(|os\.host\(|raise\(|is_host\()', src)
        assert not re.search(r'\b(?:systemctl|launchctl|schtasks|os\.exec|system\.exec)\b', src)


class TestIndex:
    @pytest.mark.index
    @SUPPORTED
    def test_register_and_search(self):
        _run_xlings("config", "--add-xpkg", PKG_FILE, timeout=45)
        assert PKG in _run_xlings("search", under_test(PKG))


class TestLifecycle:
    @pytest.mark.lifecycle
    @SUPPORTED
    def test_install(self):
        out = _run_xlings("install", under_test(PKG, os.environ.get("XLINGS_TEST_VERSION", VERSION)), "--yes")
        assert "installed" in out.lower() or "already installed" in out.lower(), out
        for program in ("rqlite", "rqlited"):
            assert _shim(program).is_file()


class TestVerify:
    @pytest.mark.verify
    @SUPPORTED
    @pytest.mark.parametrize("program", ["rqlite", "rqlited"])
    def test_version_routing(self, program):
        version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        output = _run(program, "--version")
        if os.name == "nt" and program == "rqlite" and version == "10.8.0":
            # Upstream build-windows.yml passes release -X flags to the server
            # only. Prove the shell's exact release identity, not just "10".
            assert output.strip() == "Version 10, commit unknown, built on unknown", output
            binary = _payload(program).read_bytes()
            assert hashlib.sha256(binary).hexdigest() == "37c13d8f10732641b95363425ebc6e1269ec6155fff62485ce00319bc18195eb"
            assert b"mod\tgithub.com/rqlite/rqlite/v10\tv10.8.0\t" in binary
            assert b"build\tvcs.revision=bc6efce12319a09380c71e8c4b949ed4b570f7bd\n" in binary
            assert b"build\tvcs.modified=false\n" in binary
        else:
            assert version in output, output

    @pytest.mark.verify
    @SUPPORTED
    def test_sqlite_http_and_cli(self, tmp_path):
        # Separate ephemeral loopback listeners for HTTP and Raft, never defaults.
        with socket.socket() as http, socket.socket() as raft:
            http.bind(("127.0.0.1", 0))
            raft.bind(("127.0.0.1", 0))
            http_port, raft_port = http.getsockname()[1], raft.getsockname()[1]
        executable = _payload("rqlited")
        assert executable.is_file(), executable
        env = {**os.environ, "HOME": str(tmp_path), "USERPROFILE": str(tmp_path)}
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        base_url = f"http://127.0.0.1:{http_port}"
        with (tmp_path / "server.log").open("w+", encoding="utf-8") as log:
            process = subprocess.Popen([
                str(executable), "-node-id", "xpkg-test", "-http-addr", f"127.0.0.1:{http_port}",
                "-raft-addr", f"127.0.0.1:{raft_port}", str(tmp_path / "data"),
            ], stdout=log, stderr=subprocess.STDOUT, env=env)
            try:
                deadline = time.monotonic() + 15
                while True:
                    assert process.poll() is None, "rqlited exited before becoming ready"
                    try:
                        with opener.open(base_url + "/readyz", timeout=1) as response:
                            if response.status == 200:
                                break
                    except (urllib.error.URLError, TimeoutError):
                        pass
                    if time.monotonic() >= deadline:
                        pytest.fail("rqlited did not elect a leader within 15 seconds")
                    time.sleep(0.1)

                def request(path, sql):
                    req = urllib.request.Request(base_url + path, data=json.dumps(sql).encode(), headers={"Content-Type": "application/json"})
                    with opener.open(req, timeout=5) as response:
                        data = json.load(response)
                    assert "error" not in data, data
                    assert all("error" not in result for result in data["results"]), data
                    return data["results"]

                created = request("/db/execute", ["CREATE TABLE packages (id INTEGER PRIMARY KEY, name TEXT, stars INTEGER)"])
                assert len(created) == 1
                inserted = request("/db/execute", [["INSERT INTO packages(name, stars) VALUES(?, ?)", "rqlite", 18000]])
                assert inserted[0]["rows_affected"] == 1 and inserted[0]["last_insert_id"] == 1, inserted
                selected = request("/db/query", ["SELECT name, stars FROM packages WHERE id=1"])
                assert selected[0]["columns"] == ["name", "stars"], selected
                assert selected[0]["values"] == [["rqlite", 18000]], selected
                output = _run("rqlite", "-H", "127.0.0.1", "-p", str(http_port),
                              input="SELECT name, stars FROM packages WHERE id=1;\n.quit\n", env=env)
                assert "rqlite" in output and "18000" in output, output
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read())
                raise
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
            assert process.poll() is not None
