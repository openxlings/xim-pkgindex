"""Portable superfile assets, fail-closed hooks and real spf functionality."""
import os
from pathlib import Path
import re
import shutil
import subprocess
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
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "superfile"
PKG_FILE = "pkgs/s/superfile.lua"
ROOT = Path(__file__).resolve().parents[2]
VERSION = "1.6.1"
HASHES = {
    "linux": {
        "x86_64": "2ab6872fee8fb2d6d120503f964cc693cf5ce328afedbe3988729593870c570e",
        "aarch64": "643d123cc957b23f871cf9fca873e7bf22452640b8dc0fb87d2bd51722ddf5ed",
    },
    "macosx": {
        "x86_64": "506aae6c8fa53c3ddd5816428740cf176fd456d2f67656fdeec92b36a398b673",
        "aarch64": "4d2e4c028b5cc870d0b3afcef88dd501fcf0d4d982ea3301f687ffd446821cb9",
    },
    "windows": {
        "x86_64": "dd7156c51bbbba7a0a0d1fcb10ebf60560762c4917729c40450641e27e2cb7c5",
        "aarch64": "55b25919f7adc8bdafbb47e0cdda10b8d285347a8505f6071f359ea190391965",
    },
}


def _lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter unavailable")
    return subprocess.run(
        [lua, "-", PKG_FILE, *args], input=script, text=True,
        capture_output=True, check=True, cwd=ROOT,
    ).stdout


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        for check in (assert_required_fields, assert_valid_spec, assert_valid_type,
                      assert_config_registers_package_name, assert_valid_xvm_node_kinds):
            check(meta)
        assert_no_typos(PKG_FILE)
        assert meta.programs == ["spf"]
        assert set(meta.platforms) == set(HASHES)

    @pytest.mark.static
    def test_complete_official_matrix_and_autoupdate(self):
        lines = _lua('''
import = function() end
dofile(arg[1])
assert(package.spec == "2" and package.licenses[1] == "MIT")
assert(package.xvm_enable and package.ci == nil)
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/yorukot/superfile/releases")
assert(auto.resources.CN == nil)
for plat, section in pairs(package.xpm) do
    assert(section.latest.ref == "1.6.1" and section.deps == nil)
    for arch, hash in pairs(section["1.6.1"].sha256) do
        print(table.concat({plat, arch, section["1.6.1"].arch_alias[arch], hash,
            section.source, auto.resources.GLOBAL.url[plat][arch]}, "|"))
    end
end
''').splitlines()
        observed = {}
        for line in lines:
            plat, arch, alias, digest, source, auto = line.split("|")
            expected_alias = {"x86_64": "amd64", "aarch64": "arm64"}[arch]
            assert alias == expected_alias
            upstream_os = "darwin" if plat == "macosx" else plat
            ext = "zip" if plat == "windows" else "tar.gz"
            url = (f"https://github.com/yorukot/superfile/releases/download/v{VERSION}/"
                   f"superfile-{upstream_os}-v{VERSION}-{alias}.{ext}")
            assert source.replace("${version}", VERSION).replace("${arch_alias}", alias) == url
            assert auto.replace("${tag}", "v" + VERSION) == url
            observed.setdefault(plat, {})[arch] = digest
        assert observed == HASHES

    @pytest.mark.static
    @pytest.mark.parametrize("plat", ["linux", "darwin", "windows"])
    @pytest.mark.parametrize("arch", ["amd64", "arm64"])
    def test_real_payload_helper_and_registration(self, plat, arch):
        _lua(r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local windows = arg[2] == "windows"
local stem = "superfile-" .. arg[2] .. "-v1.6.1-" .. arg[3]
local archive = "/cache/" .. stem .. (windows and ".zip" or ".tar.gz")
local dir = "/packages/superfile/1.6.1"
local exe = windows and "spf.exe" or "spf"
local files, dirs, adds, removes, commands = {}, {}, {}, {}, {}
local extracted = "/cache/dist/" .. stem
pkginfo = {
    install_dir = function() return dir end,
    install_file = function() return archive end,
    name = function() return "superfile" end,
}
os.getenv = function(k)
    if k == "OS" and windows then return "Windows_NT" end
    if k == "SystemRoot" then return "C:\\Windows" end
end
os.host = function() return windows and "windows" or "linux" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function() files = {} end
os.mv = function(src, dst)
    assert(src == extracted and dst == dir)
    files[dir .. "/" .. exe] = true
end
fs = { mkdir_p = function() end }
log = { info = function() end }
system = { exec = function(cmd)
    commands[#commands + 1] = cmd
    assert(cmd:find("--strip-components=2", 1, true))
    files[dir .. "/" .. exe] = true
end }
xvm = {
    add = function(name, opt) adds[#adds + 1] = {name, opt} end,
    remove = function(name) removes[#removes + 1] = name end,
}
assert(not installed())
dirs[extracted] = true
assert(install() and installed())
files[dir .. "/" .. exe] = nil
assert(not installed(), "missing executable was accepted")
os.mv = function() end
local ok, err = pcall(install)
assert(not ok and err:find(exe, 1, true), "missing payload must name the missing file")
dirs[extracted] = nil
if windows then
    assert(install() and installed() and #commands == 1)
    assert(commands[1]:find("System32\\tar.exe", 1, true))
    system.exec = function() end
    ok, err = pcall(install)
    assert(not ok and err:find(exe, 1, true), "empty zip must fail closed")
else
    ok, err = pcall(install)
    assert(not ok and err:find("no extracted directory", 1, true))
end
assert(config() and #adds == 2)
assert(adds[1][1] == "spf" and adds[1][2].bindir == dir)
assert(adds[2][1] == "superfile" and adds[2][2].type == "group")
assert(uninstall() and #removes == 2)
assert(removes[1] == "spf" and removes[2] == "superfile")
''', plat, arch)


class TestIsolation:
    @pytest.mark.isolation
    def test_portable_hooks(self):
        for check in (assert_no_exec_xvm, assert_no_bashrc_modification,
                      assert_no_direct_path_modification, assert_uses_new_api,
                      assert_no_direct_pkg_manager):
            check(PKG_FILE)
        src = (ROOT / PKG_FILE).read_text()
        assert set(re.findall(r'import\("([^"]+)"\)', src)) == {
            "xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r"\b(?:path\.|os\.(?:host|arch|exists|curdir)\(|raise\()", src)
        hooks = src[src.index("function install()") :]
        assert "system.exec" not in hooks and "os.exec" not in hooks


class TestIndex:
    @pytest.mark.index
    def test_registration(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


@pytest.fixture
def spf():
    subos = Path(xlings_home()) / "subos"
    names = [os.environ["XLINGS_TEST_SUBOS"]] if os.environ.get("XLINGS_TEST_SUBOS") else ["current", "default"]
    for name in names:
        shim = subos / name / "bin" / ("spf.exe" if os.name == "nt" else "spf")
        if shim.is_file():
            return shim
    pytest.fail(f"Missing actual spf shim in {subos}")


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
    def test_version_and_config_discovery(self, spf, runtime_env):
        version = subprocess.run([str(spf), "--version"], env=runtime_env,
                                 capture_output=True, text=True, check=True, timeout=15)
        assert os.environ.get("XLINGS_TEST_VERSION", VERSION) in version.stdout
        result = subprocess.run([str(spf), "path-list"], env=runtime_env,
                                capture_output=True, text=True, check=True, timeout=15)
        config = Path(runtime_env["XDG_CONFIG_HOME"]) / "superfile"
        assert str(config / "config.toml") in result.stdout
        assert str(config / "hotkeys.toml") in result.stdout
        assert list((config / "theme").glob("*.toml")), "embedded themes were not initialized"
        assert not (config / "config.toml").exists(), "path discovery should not launch the UI"

    @pytest.mark.verify
    @pytest.mark.skipif(os.name == "nt", reason="stdlib PTY is POSIX-only; Windows runs config discovery")
    def test_browse_directory_and_quit(self, spf, runtime_env, tmp_path):
        import errno
        import fcntl
        import pty
        import select
        import signal
        import struct
        import termios

        directory = tmp_path / "browse-proof"
        directory.mkdir()
        marker = "superfile-proof.txt"
        (directory / marker).write_text("A real file visible in the file manager.\n")
        config = tmp_path / "offline.toml"
        config.write_text("ignore_missing_fields = true\nauto_check_update = false\n"
                          "default_open_file_preview = false\nnerdfont = false\n")
        pid, master = pty.fork()
        if pid == 0:
            fcntl.ioctl(1, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 160, 0, 0))
            os.execve(str(spf), [str(spf), "--config-file", str(config),
                                 "--print-last-dir", str(directory)], runtime_env)
        output = bytearray()
        status = None
        quit_sent = False
        dismissed_intro = False
        deadline = time.monotonic() + 25
        try:
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as exc:
                        if exc.errno != errno.EIO:
                            raise
                        break
                    if not chunk:
                        break
                    output.extend(chunk)
                    if b"\x1b[6n" in chunk:
                        os.write(master, b"\x1b[1;1R")
                    # The first key dismisses the documented first-use overlay.
                    if not dismissed_intro and b"\x1b[?1049h" in output:
                        os.write(master, b"\r")
                        dismissed_intro = True
                    if marker.encode() in output and not quit_sent:
                        os.write(master, b"q")
                        quit_sent = True
                waited, raw_status = os.waitpid(pid, os.WNOHANG)
                if waited:
                    status = raw_status
                    break
            if status is None:
                waited, raw_status = os.waitpid(pid, os.WNOHANG)
                if waited:
                    status = raw_status
        finally:
            if status is None:
                os.kill(pid, signal.SIGKILL)
                _, status = os.waitpid(pid, 0)
            os.close(master)
        rendered = output.decode("utf-8", errors="replace")
        assert marker in rendered, rendered
        assert quit_sent and os.waitstatus_to_exitcode(status) == 0, rendered
        assert str(directory) in rendered, rendered
        assert (directory / marker).read_text().startswith("A real file")

    @pytest.mark.verify
    def test_xvm_registration(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = Path(xlings_home()) / "subos"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if (subos / "current").is_dir() else "default")
        assert_xvm_registered("spf")
        assert_xvm_registered("superfile")
