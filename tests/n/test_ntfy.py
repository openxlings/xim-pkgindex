"""Portable ntfy resources, isolation, and native lifecycle checks."""
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "ntfy"
PKG_FILE = "pkgs/n/ntfy.lua"
ROOT = Path(__file__).resolve().parents[2]


def run_lua(source):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to evaluate the package declaration"
    return subprocess.run([lua, "-", PKG_FILE], input=source, cwd=ROOT,
                          text=True, capture_output=True, check=True, timeout=30)


def run_xlings(*args):
    # Native argv deliberately avoids login-shell startup and Windows' bash.exe.
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for lifecycle checks"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def executable():
    suffix = ".exe" if os.name == "nt" else ""
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    candidates = [subos] if subos else ["current", "default"]
    for name in candidates:
        shim = base / name / "bin" / (PKG + suffix)
        if shim.is_file():
            return str(shim)
    pytest.fail("Missing installed ntfy shim")


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_resource_and_updater_matrix(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2" and package.name == "ntfy")
local expected = {
    linux = {x86_64="linux_amd64.tar.gz", aarch64="linux_arm64.tar.gz"},
    macosx = {x86_64="darwin_all.tar.gz", aarch64="darwin_all.tar.gz"},
    windows = {x86_64="windows_amd64.zip"},
}
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/binwiederhier/ntfy/releases")
assert(auto.resources.CN == nil)
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    for arch, suffix in pairs(arches) do
        local hash = assert(entry.sha256[arch])
        assert(#hash == 64 and hash:match("^[a-f0-9]+$"))
        local url = p.source:gsub("%${version}", version)
        if entry.arch_alias then
            url = url:gsub("%${arch_alias}", entry.arch_alias[arch])
        end
        local wanted = "https://github.com/binwiederhier/ntfy/releases/download/v"
            .. version .. "/ntfy_" .. version .. "_" .. suffix
        assert(url == wanted, url)
        local update = auto.resources.GLOBAL.url[platform][arch]
        assert(update:gsub("%${version}", version) == url)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unexpected architecture") end
    for arch in pairs(auto.resources.GLOBAL.url[platform]) do assert(arches[arch]) end
end
assert(count == 5)
''')

    @pytest.mark.static
    def test_archive_layout_and_hooks(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
local archive, is_windows, files = "", false, {}
pkginfo = { install_dir = function() return "/isolated/ntfy" end,
            install_file = function() return archive end }
os.isfile = function(p) return files[p] == true end
payload = {
    unpack = function(opt)
        local name = archive:gsub("\\", "/"):match("([^/]+)$")
        local expected = name:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
        assert(opt.extracted == expected and opt.strip == 1)
        files = {}
        for _, f in ipairs({is_windows and "ntfy.exe" or "ntfy",
                            "LICENSE", "README.md", "client/client.yml"}) do
            files["/isolated/ntfy/" .. f] = true
        end
    end,
    present = function(wanted)
        for _, f in ipairs(wanted) do
            if not files["/isolated/ntfy/" .. f] then return false end
        end
        return true
    end,
}
payload.require = function(wanted) assert(payload.present(wanted)) end
xvm = {
    add = function(name, opt) assert(name == "ntfy" and opt.bindir == "/isolated/ntfy") end,
    remove = function(name) assert(name == "ntfy") end,
}
for _, suffix in ipairs({"linux_amd64.tar.gz", "linux_arm64.tar.gz",
                         "darwin_all.tar.gz", "windows_amd64.zip"}) do
    is_windows = suffix:match("%.zip$") ~= nil
    archive = "/download/ntfy_9.8.7_" .. suffix
    assert(install() and installed() and config() and uninstall())
    files["/isolated/ntfy/LICENSE"] = nil
    assert(not installed(), "incomplete payload must not count as installed")
end
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_compliance(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text()
        imports = re.findall(r'import\("([^"]+)"\)', source)
        assert set(imports) == {"xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload"}
        assert not re.search(r'\b(?:path\.|os\.(?:host|curdir|execv)\(|is_host\(|raise\()', source)
        assert "system.exec" not in source and "os.exec" not in source


class TestIndex:
    @pytest.mark.index
    def test_register(self):
        run_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in run_xlings("search", under_test(PKG), "--agent")


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        run_xlings("install", under_test(PKG), "--yes", "--agent")
        assert Path(executable()).is_file()


class TestVerify:
    @pytest.mark.verify
    def test_version_and_registration(self):
        result = subprocess.run([executable(), "--version"], capture_output=True,
                                text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        match = re.search(r"ntfy version (\d+\.\d+\.\d+)\b", result.stdout)
        assert match, result.stdout
        if os.environ.get("XLINGS_TEST_VERSION"):
            assert match[1] == os.environ["XLINGS_TEST_VERSION"]
        registry = Path(executable()).parent.parent / ".xlings.json"
        node = json.loads(registry.read_text(encoding="utf-8"))["workspace"][PKG]
        assert node["active"] in node["installed"]

    @pytest.mark.verify
    @pytest.mark.skipif(sys.platform != "linux", reason="Native Linux server check; macOS is client-only")
    def test_loopback_publish(self, tmp_path):
        # Explicit empty configs and a clean environment prevent user/provider settings.
        server_config = tmp_path / "server.yml"
        client_config = tmp_path / "client.yml"
        server_config.write_text("{}\n")
        client_config.write_text("{}\n")
        env = {k: v for k, v in os.environ.items() if not k.startswith("NTFY_")}
        env.update(HOME=str(tmp_path), XDG_CONFIG_HOME=str(tmp_path))
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        address = f"127.0.0.1:{port}"
        with (tmp_path / "server.log").open("w+") as log:
            process = subprocess.Popen(
                [executable(), "serve", "--config", str(server_config),
                 "--listen-http", address, "--web-root", "disable"],
                cwd=tmp_path, env=env, stdout=log, stderr=log,
            )
            try:
                deadline = time.monotonic() + 15
                while True:
                    if process.poll() is not None:
                        log.seek(0)
                        pytest.fail("ntfy exited before listening: " + log.read())
                    try:
                        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                            break
                    except OSError:
                        assert time.monotonic() < deadline, "ntfy did not listen"
                        time.sleep(0.05)
                result = subprocess.run(
                    [executable(), "publish", "--config", str(client_config),
                     "--no-cache", "--no-firebase", f"http://{address}/xpkg-test",
                     "isolated ntfy message"],
                    cwd=tmp_path, env=env, capture_output=True, text=True, timeout=15,
                )
                assert result.returncode == 0, result.stdout + result.stderr
                message = json.loads(result.stdout)
                assert message["topic"] == "xpkg-test"
                assert message["message"] == "isolated ntfy message"
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            assert process.poll() is not None
        with socket.socket() as probe:
            assert probe.connect_ex(("127.0.0.1", port)) != 0
