"""Tests for the etcd package."""
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

PKG = "etcd"
PKG_FILE = "pkgs/e/etcd.lua"
VERSION = "3.7.4"


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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["etcd", "etcdctl", "etcdutl"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/etcd-io/etcd/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == ver)
    local entry = assert(section[ver], "missing " .. ver .. " in " .. plat)
    assert(entry.arch_alias and entry.arch_alias.x86_64 == "amd64")
    if plat ~= "windows" then
        assert(entry.arch_alias.aarch64 == "arm64")
    end
    assert(entry.sha256)
    for _, arch in ipairs(arches) do
        local h = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(global_url[plat] and type(global_url[plat][arch]) == "string")
        assert(global_url[plat][arch]:find("${tag}", 1, true))
        assert(global_url[plat][arch]:find("${version}", 1, true))
    end
end
assert(package.xpm.windows[ver].sha256.aarch64 == nil, "windows/aarch64 not published upstream")
assert(global_url.windows.aarch64 == nil)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_linux_and_macosx(self):
        for plat, archive in [
            ("linux", f"/cache/etcd-v{VERSION}-linux-amd64.tar.gz"),
            ("macosx", f"/cache/etcd-v{VERSION}-darwin-arm64.zip"),
        ]:
            stem = archive.rsplit("/", 1)[-1].removesuffix(".tar.gz").removesuffix(".zip")
            _run_lua(
                '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local plat = arg[2]
local archive_path = arg[3]
local stem = arg[4]
local ver = arg[5]

local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
dirs["/cache/" .. stem] = true

pkginfo = {
    name = function() return "etcd" end,
    version = function() return ver end,
    install_file = function() return archive_path end,
    install_dir = function() return "/xpkgs/etcd/" .. ver end,
}
os.host = function() return plat end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/etcd"] = true
    files[dst .. "/etcdctl"] = true
    files[dst .. "/etcdutl"] = true
end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/" .. stem and moved[1][2] == "/xpkgs/etcd/" .. ver)
assert(installed())

files["/xpkgs/etcd/" .. ver .. "/etcdutl"] = nil
assert(not installed(), "accepted missing etcdutl binary")
files["/xpkgs/etcd/" .. ver .. "/etcdutl"] = true

assert(config())
assert(#xvm_adds == 3)
assert(xvm_adds[1][1] == "etcd" and xvm_adds[1][2].bindir == "/xpkgs/etcd/" .. ver and xvm_adds[1][2].binding == nil)
assert(xvm_adds[2][1] == "etcdctl" and xvm_adds[2][2].bindir == "/xpkgs/etcd/" .. ver and xvm_adds[2][2].binding == "etcd@" .. ver)
assert(xvm_adds[3][1] == "etcdutl" and xvm_adds[3][2].bindir == "/xpkgs/etcd/" .. ver and xvm_adds[3][2].binding == "etcd@" .. ver)

assert(uninstall())
assert(#xvm_rms == 3)
assert(xvm_rms[1] == "etcdutl" and xvm_rms[2] == "etcdctl" and xvm_rms[3] == "etcd")
''',
                PKG_FILE,
                plat,
                archive,
                stem,
                VERSION,
            )

    @pytest.mark.static
    def test_hooks_windows_zip(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local ver = arg[2]
local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "etcd" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/etcd-v" .. ver .. "-windows-amd64.zip" end,
    install_dir = function() return "C:/xpkgs/etcd/" .. ver end,
}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
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
        files["C:/xpkgs/etcd/" .. ver .. "/etcd.exe"] = true
        files["C:/xpkgs/etcd/" .. ver .. "/etcdctl.exe"] = true
        files["C:/xpkgs/etcd/" .. ver .. "/etcdutl.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\etcd%-v3%.7%.4%-windows%-amd64%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\etcd\\\\3%.7%.4"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 3)
assert(xvm_adds[1][1] == "etcd" and xvm_adds[1][2].binding == nil)
assert(xvm_adds[2][1] == "etcdctl" and xvm_adds[2][2].binding == "etcd@" .. ver)
assert(xvm_adds[3][1] == "etcdutl" and xvm_adds[3][2].binding == "etcd@" .. ver)

assert(uninstall())
assert(#xvm_rms == 3)
''',
            PKG_FILE,
            VERSION,
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
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    def _shim(self, prog: str) -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / (prog + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_prog(self, prog: str, *args: str) -> str:
        shim = self._shim(prog)
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_versions(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert f"etcd Version: {expected}" in self._run_prog("etcd", "--version")
        assert f"etcdctl version: {expected}" in self._run_prog("etcdctl", "version")
        assert f"etcdutl version: {expected}" in self._run_prog("etcdutl", "version")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        for prog in ("etcd", "etcdctl", "etcdutl"):
            assert_xvm_registered(prog)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_local_put_get_roundtrip(self):
        def free_port() -> int:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(("127.0.0.1", 0))
                return s.getsockname()[1]

        client_port = free_port()
        peer_port = free_port()
        client_url = f"http://127.0.0.1:{client_port}"
        peer_url = f"http://127.0.0.1:{peer_port}"

        with tempfile.TemporaryDirectory() as data_dir:
            proc = subprocess.Popen(
                [
                    str(self._shim("etcd")),
                    "--name", "test-node",
                    "--data-dir", data_dir,
                    "--listen-client-urls", client_url,
                    "--advertise-client-urls", client_url,
                    "--listen-peer-urls", peer_url,
                    "--initial-advertise-peer-urls", peer_url,
                    "--initial-cluster", f"test-node={peer_url}",
                    "--log-level", "error",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                deadline = time.monotonic() + 15.0
                ready = False
                while time.monotonic() < deadline:
                    if proc.poll() is not None:
                        _, err = proc.communicate()
                        pytest.fail(f"etcd exited prematurely ({proc.returncode}): {err}")
                    r = subprocess.run(
                        [str(self._shim("etcdctl")), f"--endpoints={client_url}", "endpoint", "health"],
                        capture_output=True,
                        text=True,
                        timeout=5,
                    )
                    if r.returncode == 0:
                        ready = True
                        break
                    time.sleep(0.2)
                assert ready, "etcd did not become healthy in time"

                put_res = subprocess.run(
                    [str(self._shim("etcdctl")), f"--endpoints={client_url}", "put", "xlings-key", "xlings-val"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    check=True,
                )
                assert "OK" in put_res.stdout

                get_res = subprocess.run(
                    [str(self._shim("etcdctl")), f"--endpoints={client_url}", "get", "xlings-key", "--print-value-only"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    check=True,
                )
                assert get_res.stdout.strip() == "xlings-val"
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)
