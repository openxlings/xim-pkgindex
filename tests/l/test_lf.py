"""Metadata, isolation, payload hooks, and real terminal navigation for lf."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
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
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home

PKG = "lf"
PKG_FILE = "pkgs/l/lf.lua"
VERSION = "42"
REPO = Path(__file__).resolve().parents[2]


def _run_xlings(*args, timeout=180):
    """Use the native CLI, not a login shell or Windows' WSL bash."""
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


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args], input=script, text=True, capture_output=True,
        check=True, cwd=REPO,
    ).stdout


def _shim():
    name = "lf.exe" if os.name == "nt" else "lf"
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
    shim = base / subos / "bin" / name
    if not shim.is_file() and subos == "current":
        shim = base / "default" / "bin" / name
    assert shim.is_file(), f"Missing lf shim: {shim}"
    return shim


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
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)
        assert meta.spec == "2"
        assert meta.programs == ["lf"]
        assert set(meta.platforms) == {"linux", "macosx", "windows"}

    @pytest.mark.static
    def test_resources_and_numeric_tag_mapping(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local version = arg[2]
local auto = assert(package.extensions.autoupdate)
assert(auto.tag:gsub("%${version}", version) == "r" .. version)
assert(auto.resources.GLOBAL.required == true)
assert(auto.resources.CN == nil)
local expected = {
    linux = {x86_64 = true, aarch64 = true},
    macosx = {x86_64 = true, aarch64 = true},
    windows = {x86_64 = true},
}
local count = 0
for platform, arches in pairs(expected) do
    local section = assert(package.xpm[platform])
    assert(section.latest.ref == version)
    assert(section.deps == nil)
    local entries = assert(section[version])
    for arch in pairs(arches) do
        local resource = assert(entries[arch])
        assert(#resource.sha256 == 64 and resource.sha256:match("^%x+$"))
        local template = assert(auto.resources.GLOBAL.url[platform][arch])
        local url = template:gsub("%${tag}", "r" .. version)
        assert(resource.url == url)
        count = count + 1
    end
    for arch in pairs(entries) do assert(arches[arch], "unsupported architecture") end
    for arch in pairs(auto.resources.GLOBAL.url[platform]) do assert(arches[arch]) end
end
assert(count == 5)
''', PKG_FILE, VERSION)

    @pytest.mark.static
    @pytest.mark.parametrize("windows", [False, True])
    def test_hooks_require_payload_and_route_executable(self, windows):
        _run_lua('''
import = function() end
local windows = arg[2] == "windows"
local dir = windows and "C:/package home/lf/42" or "/package home/lf/42"
local exe = windows and "lf.exe" or "lf"
local archive = windows and "C:/cache/lf-windows-amd64.zip" or "/cache/lf-linux-amd64.tar.gz"
local files, adds, removes, commands = {}, {}, {}, {}
local extract = true
os.host = function() return windows and "windows" or "linux" end
os.getenv = function(key)
    if windows and key == "SystemRoot" then return "C:/Windows" end
end
os.isfile = function(path) return files[path] == true end
os.isdir = function() return false end
os.tryrm = function() files[dir .. "/" .. exe] = nil end
fs = {mkdir_p = function() end}
log = {info = function() end}
pkginfo = {
    name = function() return "lf" end,
    install_file = function() return archive end,
    install_dir = function() return dir end,
}
system = {exec = function(command)
    commands[#commands + 1] = command
    if extract then files[dir .. "/" .. exe] = true end
end}
xvm = {
    add = function(name, options) adds[#adds + 1] = {name, options} end,
    remove = function(name) removes[#removes + 1] = name end,
}
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])
assert(not installed())
assert(install() and installed())
assert(#commands == (windows and 1 or 2))
assert(config())
assert(#adds == 1 and adds[1][1] == "lf" and adds[1][2].bindir == dir)
assert(uninstall() and #removes == 1 and removes[1] == "lf")
files[dir .. "/" .. exe] = nil
assert(not installed())
extract = false
local ok, message = pcall(install)
assert(not ok and tostring(message):find(exe, 1, true), "missing payload must fail")
''', PKG_FILE, "windows" if windows else "posix")


class TestIsolation:
    @pytest.mark.isolation
    @pytest.mark.parametrize("check", [
        assert_no_exec_xvm, assert_no_bashrc_modification,
        assert_no_direct_path_modification, assert_uses_new_api,
        assert_no_direct_pkg_manager,
    ])
    def test_isolation(self, check):
        check(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_api_boundary(self):
        source = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', source)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|os\.execv\(|os\.curdir\(|raise\()', source)


class TestIndex:
    @pytest.mark.index
    def test_add(self):
        _run_xlings("config", "--add-xpkg", str(REPO / PKG_FILE), timeout=45)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        output = _run_xlings("install", under_test(PKG), "-y")
        assert "installed" in output.lower(), output


class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        result = subprocess.run(
            [str(_shim()), "-version"], capture_output=True, text=True, timeout=15,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert re.search(rf"^r?{re.escape(version)}(?:\s|$)", result.stdout)

    @pytest.mark.verify
    def test_registered(self):
        assert_xvm_registered("lf")

    @pytest.mark.verify
    @pytest.mark.skipif(os.name == "nt", reason="PTY navigation requires a POSIX terminal")
    def test_navigates_directory_without_server(self, tmp_path):
        import errno
        import fcntl
        import pty
        import select
        import signal
        import struct
        import termios
        import time

        nested = tmp_path / "nested"
        nested.mkdir()
        (nested / "fixture.txt").write_text("lf fixture\n", encoding="utf-8")
        config = tmp_path / "lfrc"
        config.write_text("set preview false\n", encoding="utf-8")
        last_dir = tmp_path / "last-dir"
        env = {**os.environ, "TERM": "xterm-256color", "HOME": str(tmp_path),
               "XDG_CONFIG_HOME": str(tmp_path / "config"),
               "XDG_DATA_HOME": str(tmp_path / "data"),
               "XDG_CACHE_HOME": str(tmp_path / "cache")}
        command = [str(_shim()), "-single", "-config", str(config),
                   "-last-dir-path", str(last_dir), "-command", "cd nested",
                   "-command", "quit"]
        pid, master = pty.fork()
        if pid == 0:
            try:
                os.chdir(tmp_path)
                fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
                os.execve(command[0], command, env)
            finally:
                os._exit(127)
        output = bytearray()
        status = None
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        output.extend(os.read(master, 65536))
                    except OSError as exc:
                        if exc.errno != errno.EIO:
                            raise
                finished, child_status = os.waitpid(pid, os.WNOHANG)
                if finished:
                    status = child_status
                    break
            assert status is not None, "lf did not exit its isolated PTY"
            assert os.waitstatus_to_exitcode(status) == 0, output.decode(errors="replace")
            assert last_dir.read_text(encoding="utf-8") == str(nested.resolve())
        finally:
            if status is None:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)
            os.close(master)
        # -single never starts a server; the only child above is always reaped.
