"""Official jid payloads, fail-closed installation, and real JSON selection."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

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
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "jid"
PKG_FILE = "pkgs/j/jid.lua"
ROOT = Path(__file__).resolve().parents[2]
VERSION = "1.1.3"
HASHES = {
    "linux": {
        "x86_64": "e3731dfbf3948113df78b4ef642c4f85b7bd6732c11f66f71489cf9152a42701",
        "aarch64": "ee4eb30853597c48d304b63fc6fb9e058ff2c039b296ce3506fc7b1a77a9b58b",
    },
    "macosx": {
        "x86_64": "bc04fa1d0faeae545eff9cec176ebae437451546c149090e2877babf61ef4755",
        "aarch64": "2f63039c83581be6ac26da38fdcf1b575f15f38a128089c9642647b5fcb8b2e1",
    },
    "windows": {
        "x86_64": "02153d3edae1ec7bfdcfb21de5904469fac75cbbac8f6199639d31b69c8aef3b",
        "aarch64": "a19dba7ad4ca0939f1722fc29aa5b89a179fd60bfc7f8f697d619fee9c8bd07f",
    },
}


def _lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter unavailable")
    result = subprocess.run(
        [lua, "-", PKG_FILE, *args], input=script, text=True,
        capture_output=True, cwd=ROOT,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def _xlings(*args):
    executable = Path(xlings_home()) / "bin" / ("xlings.exe" if os.name == "nt" else "xlings")
    result = subprocess.run(
        [str(executable), *args, "--agent"], env=dict(os.environ),
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180,
    )
    assert result.returncode == 0, result.stdout + result.stderr


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        for check in (assert_required_fields, assert_valid_spec, assert_valid_type,
                      assert_config_registers_package_name, assert_valid_xvm_node_kinds):
            check(meta)
        assert_no_typos(PKG_FILE)
        assert meta.programs == ["jid"]
        assert set(meta.platforms) == set(HASHES)

    @pytest.mark.static
    def test_complete_official_matrix_and_updates(self):
        lines = _lua('''
import = function() end
dofile(arg[1])
assert(package.spec == "2" and package.licenses[1] == "MIT")
assert(package.xvm_enable and package.ci.mirror and package.ci.update == nil)
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/simeji/jid/releases" and auto.resources.CN == nil)
for plat, section in pairs(package.xpm) do
    assert(section.latest.ref == "1.1.3" and section.deps == nil)
    for arch, hash in pairs(section["1.1.3"].sha256) do
        print(table.concat({plat, arch, section["1.1.3"].arch_alias[arch], hash,
            section.source, auto.resources.GLOBAL.url[plat][arch]}, "|"))
    end
end
''').splitlines()
        observed = {}
        for line in lines:
            plat, arch, alias, digest, source, auto = line.split("|")
            assert alias == {"x86_64": "amd64", "aarch64": "arm64"}[arch]
            upstream_os = "darwin" if plat == "macosx" else plat
            url = (f"https://github.com/simeji/jid/releases/download/v{VERSION}/"
                   f"jid_{upstream_os}_{alias}.zip")
            assert source.replace("${version}", VERSION).replace("${arch_alias}", alias) == url
            assert auto.replace("${tag}", "v" + VERSION) == url
            observed.setdefault(plat, {})[arch] = digest
        assert observed == HASHES

    @pytest.mark.static
    @pytest.mark.parametrize("plat", ["linux", "darwin", "windows"])
    def test_payload_and_registration(self, plat):
        _lua(r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])
local windows = arg[2] == "windows"
local archive = "/cache/jid_" .. arg[2] .. "_amd64.zip"
local dir = "/packages/jid/1.1.3"
local exe = windows and "jid.exe" or "jid"
local files, commands, adds, removes = {}, {}, {}, {}
local deliver = true
pkginfo = {
    install_dir = function() return dir end,
    install_file = function() return archive end,
    name = function() return "jid" end,
}
os.getenv = function(k)
    if k == "OS" and windows then return "Windows_NT" end
    if k == "SystemRoot" then return "C:\\Windows" end
end
os.host = function() return windows and "windows" or arg[2] end
os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function()
    files[dir .. "/jid"] = nil
    files[dir .. "/jid.exe"] = nil
end
os.mv = function(src, dst)
    assert(src == "/cache/" .. exe and dst == dir .. "/" .. exe)
    if deliver then files[dst] = true end
end
fs = { mkdir_p = function() end }
log = { info = function() end }
system = { exec = function(cmd)
    commands[#commands + 1] = cmd
    if deliver then files[dir .. "/" .. exe] = true end
end }
xvm = {
    add = function(name, opt) adds[#adds + 1] = { name, opt } end,
    remove = function(name) removes[#removes + 1] = name end,
}
assert(not installed())
files[dir .. "/" .. (windows and "jid" or "jid.exe")] = true
assert(not installed(), "another platform's binary must not satisfy installed()")
files[archive] = true
assert(install() and installed())
assert(commands[1]:find(windows and "System32\\tar.exe" or "unzip", 1, true))
files[dir .. "/" .. exe] = nil
assert(not installed(), "missing executable was accepted")
deliver = false
local ok, err = pcall(install)
assert(not ok and err:find(exe, 1, true), "empty archive must name missing executable")
files[archive] = nil
files["/cache/" .. exe] = true
deliver = true
assert(install() and installed())
files["/cache/" .. exe] = nil
ok, err = pcall(install)
assert(not ok and err:find("neither archive", 1, true))
assert(config() and #adds == 1 and adds[1][1] == "jid" and adds[1][2].bindir == dir)
assert(uninstall() and #removes == 1 and removes[1] == "jid")
''', plat)


class TestIsolation:
    @pytest.mark.isolation
    def test_portable_hooks(self):
        for check in (assert_no_exec_xvm, assert_no_bashrc_modification,
                      assert_no_direct_path_modification, assert_uses_new_api,
                      assert_no_direct_pkg_manager):
            check(PKG_FILE)
        src = (ROOT / PKG_FILE).read_text()
        assert set(re.findall(r'import\("([^"]+)"\)', src)) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.shell",
        }
        assert not re.search(r"\b(?:path\.|os\.(?:host|arch|exists|curdir)\(|raise\()", src)


class TestIndex:
    @pytest.mark.index
    def test_registration(self):
        _xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _xlings("install", under_test(PKG), "-y")


@pytest.fixture
def jid():
    subos = Path(xlings_home()) / "subos"
    names = [os.environ["XLINGS_TEST_SUBOS"]] if os.environ.get("XLINGS_TEST_SUBOS") else ["current", "default"]
    for name in names:
        shim = subos / name / "bin" / ("jid.exe" if os.name == "nt" else "jid")
        if shim.is_file():
            return shim
    pytest.fail(f"Missing actual jid shim in {subos}")


@pytest.fixture
def runtime_env(tmp_path):
    env = dict(os.environ)
    for key, child in {
        "HOME": "user", "USERPROFILE": "user", "APPDATA": "config",
        "LOCALAPPDATA": "data", "XDG_CONFIG_HOME": "config",
        "XDG_DATA_HOME": "data", "XDG_STATE_HOME": "state", "XDG_CACHE_HOME": "cache",
    }.items():
        path = tmp_path / child
        path.mkdir(exist_ok=True)
        env[key] = str(path)
    env["TERM"] = "xterm-256color"
    return env


class TestVerify:
    @pytest.mark.verify
    def test_version_and_help(self, jid, runtime_env):
        version = subprocess.run([str(jid), "-version"], env=runtime_env,
                                 capture_output=True, text=True, check=True, timeout=15)
        assert os.environ.get("XLINGS_TEST_VERSION", VERSION) in version.stdout
        help_result = subprocess.run([str(jid), "-help"], env=runtime_env,
                                     capture_output=True, text=True, check=True, timeout=15)
        assert "Exit jid and print the current result" in help_result.stdout

    @pytest.mark.verify
    def test_invalid_json_is_rejected_without_terminal(self, jid, runtime_env):
        result = subprocess.run([str(jid)], input="{\"users\": [}", env=runtime_env,
                                capture_output=True, text=True, timeout=15)
        assert result.returncode == 1, result.stdout + result.stderr
        assert "invalid json format" in result.stdout.lower()
        assert "panic" not in result.stdout + result.stderr

    @pytest.mark.verify
    @pytest.mark.skipif(os.name == "nt", reason="POSIX controlling-terminal API unavailable; Windows runs version and JSON rejection")
    @pytest.mark.parametrize("quit_key", [b"\r", b"\x11"], ids=["enter", "ctrl-q"])
    def test_pipe_json_interactive_selection(self, jid, runtime_env, quit_key):
        import errno
        import fcntl
        import pty
        import select
        import signal
        import struct
        import termios

        source_r, source_w = os.pipe()
        result_r, result_w = os.pipe()
        pid, master = pty.fork()
        if pid == 0:
            os.close(source_w)
            os.close(result_r)
            fcntl.ioctl(1, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 120, 0, 0))
            os.dup2(source_r, 0)
            os.dup2(result_w, 1)
            os.close(source_r)
            os.close(result_w)
            os.execve(str(jid), [str(jid), "-M"], runtime_env)
        os.close(source_r)
        os.close(result_w)
        os.write(source_w, b'{"users":[{"name":"jid-selected-proof"},{"name":"jid-other-proof"}]}')
        os.close(source_w)
        screen, result = bytearray(), bytearray()
        readers = {master, result_r}
        status = None
        query_sent = quit_sent = False
        deadline = time.monotonic() + 20
        try:
            while readers and time.monotonic() < deadline:
                ready, _, _ = select.select(list(readers), [], [], min(0.2, max(0, deadline - time.monotonic())))
                for fd in ready:
                    try:
                        chunk = os.read(fd, 65536)
                    except OSError as exc:
                        if fd != master or exc.errno != errno.EIO:
                            raise
                        chunk = b""
                    if not chunk:
                        readers.remove(fd)
                        continue
                    if fd == result_r:
                        result.extend(chunk)
                    else:
                        screen.extend(chunk)
                        if b"\x1b[6n" in chunk:
                            os.write(master, b"\x1b[1;1R")
                        if not query_sent and b"jid-other-proof" in screen:
                            os.write(master, b"\x15.users[0].name")
                            query_sent = True
                            screen.clear()
                        elif query_sent and not quit_sent and b"jid-selected-proof" in screen:
                            os.write(master, quit_key)
                            quit_sent = True
                if status is None:
                    waited, raw_status = os.waitpid(pid, os.WNOHANG)
                    if waited:
                        status = raw_status
            if status is None:
                waited, raw_status = os.waitpid(pid, os.WNOHANG)
                if waited:
                    status = raw_status
        finally:
            if status is None:
                os.kill(pid, signal.SIGKILL)
                _, status = os.waitpid(pid, 0)
            os.close(master)
            os.close(result_r)
        rendered = screen.decode("utf-8", errors="replace")
        assert query_sent and quit_sent, rendered
        assert os.waitstatus_to_exitcode(status) == 0, rendered + result.decode(errors="replace")
        assert json.loads(result) == "jid-selected-proof", rendered + result.decode(errors="replace")

    @pytest.mark.verify
    def test_xvm_registration(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = Path(xlings_home()) / "subos"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if (subos / "current").is_dir() else "default")
        assert_xvm_registered("jid")
