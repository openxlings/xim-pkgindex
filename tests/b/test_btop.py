"""Official btop musl resources, relocatable themes, and native terminal smoke."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "btop"
PKG_FILE = "pkgs/b/btop.lua"
ROOT = Path(__file__).resolve().parents[2]


def run_lua(source):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to evaluate the package declaration"
    return subprocess.run([lua, "-", PKG_FILE], input=source, cwd=ROOT,
                          text=True, capture_output=True, check=True, timeout=30)


def run_xlings(*args):
    binary = Path(xlings_home()) / "bin" / "xlings"
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for lifecycle checks"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def executable():
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    for name in ([subos] if subos else ["current", "default"]):
        shim = base / name / "bin" / PKG
        if shim.is_file():
            return str(shim)
    pytest.fail("Missing installed btop shim")


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)
        assert set(meta.platforms) == {"linux"}
        assert meta.programs == ["btop"]

    @pytest.mark.static
    def test_resource_and_updater_matrix(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2" and package.name == "btop")
assert(package.licenses[1] == "Apache-2.0")
assert(package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
assert(#package.archs == 2 and package.xpm.linux.latest.ref == "1.4.8")
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/aristocratos/btop/releases")
assert(auto.resources.CN == nil and auto.resources.GLOBAL.required == true)
local expected = {
    x86_64 = "af589cf82cc9ea9c29ce050b9239a13bef2d1492256d476156e1054a42ce89ad",
    aarch64 = "95328e26ab08f42033af26628e2d169206a5a420f35669ce17459ef85114c14c",
}
local count = 0
for arch, hash in pairs(package.xpm.linux["1.4.8"].sha256) do
    assert(hash == expected[arch])
    local url = package.xpm.source:gsub("%${version}", "1.4.8"):gsub("%${arch}", arch)
    local wanted = "https://github.com/aristocratos/btop/releases/download/v1.4.8/btop-"
        .. arch .. "-unknown-linux-musl.tar.gz"
    assert(url == wanted)
    assert(auto.resources.GLOBAL.url.linux[arch]:gsub("%${tag}", "v1.4.8") == wanted)
    count = count + 1
end
assert(count == 2)
assert(package.xpm.windows == nil and package.xpm.macosx == nil)
assert(auto.resources.GLOBAL.url.windows == nil and auto.resources.GLOBAL.url.macosx == nil)
''')

    @pytest.mark.static
    def test_install_layout_and_missing_payload(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
local files, moved = {}, false
local root = "/isolated/btop"
pkginfo = { install_dir = function() return root end }
fs = { mkdir_p = function(p) assert(p == root .. "/share/btop") end }
os.mv = function(src, dst)
    assert(src == root .. "/themes" and dst == root .. "/share/btop/themes")
    moved = true
end
payload = {
    unpack = function(opt)
        assert(opt.extracted == "btop" and opt.strip == 1)
    end,
    present = function(wanted)
        for _, f in ipairs(wanted) do if not files[f] then return false end end
        return true
    end,
}
local required = {"bin/btop", "LICENSE", "README.md", "Img/icon.svg",
                  "share/btop/themes/dracula.theme", "share/btop/themes/nord.theme"}
payload.require = function(wanted)
    assert(moved and #wanted == #required)
    for i, f in ipairs(wanted) do assert(f == required[i]); files[f] = true end
end
xvm = {
    add = function(name, opt) assert(name == "btop" and opt.bindir == root .. "/bin") end,
    remove = function(name) assert(name == "btop") end,
}
assert(not installed())
assert(install() and installed() and config() and uninstall())
for _, f in ipairs(required) do
    files[f] = nil
    assert(not installed(), "missing payload must require repair: " .. f)
    files[f] = true
end
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_compliance(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text()
        assert set(re.findall(r'import\("([^"]+)"\)', source)) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload"}
        assert not re.search(r'\b(?:path\.|os\.(?:host|curdir|execv)\(|is_host\(|raise\()', source)
        assert "system.exec" not in source and "os.exec" not in source


@pytest.mark.skipif(sys.platform != "linux", reason="Official binaries are Linux-only")
class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        run_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in run_xlings("search", under_test(PKG), "--agent")


@pytest.mark.skipif(sys.platform != "linux", reason="Official binaries are Linux-only")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        run_xlings("install", under_test(PKG), "--yes", "--agent")
        assert Path(executable()).is_file()


@pytest.mark.skipif(sys.platform != "linux", reason="Official binaries are Linux-only")
class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        result = subprocess.run([executable(), "--version"], text=True,
                                capture_output=True, check=True, timeout=15)
        assert "1.4.8" in result.stdout

    @pytest.mark.verify
    def test_monitor_and_relocated_theme(self, tmp_path):
        import fcntl
        import pty
        import select
        import struct
        import termios

        config = tmp_path / "btop.conf"
        config.write_text('color_theme = "dracula"\ntruecolor = True\n'
                          'theme_background = True\nshown_boxes = "cpu mem net proc"\n'
                          'check_temp = False\nshow_gpu_info = "Off"\n')
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        env = dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor", LANG="C.UTF-8")
        process = subprocess.Popen([executable(), "--config", str(config), "--force-utf"],
                                   stdin=slave, stdout=slave, stderr=slave, env=env)
        os.close(slave)
        snapshot = bytearray()
        deadline = time.monotonic() + 20
        # This exact Dracula background proves automatic ../share/btop/themes
        # lookup succeeded; no --themes-dir or user/global theme installation.
        dracula = b"\x1b[48;2;40;42;54m"
        try:
            while time.monotonic() < deadline and process.poll() is None:
                if not select.select([master], [], [], 0.2)[0]:
                    continue
                try:
                    chunk = os.read(master, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                snapshot.extend(chunk)
                if dracula in snapshot and b"proc" in snapshot.lower():
                    break
            os.write(master, b"q")
            assert process.wait(timeout=10) == 0, snapshot.decode(errors="replace")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            os.close(master)
            (tmp_path / "terminal.snapshot").write_bytes(snapshot)
        assert dracula in snapshot, "Bundled Dracula theme was not loaded"
        assert b"proc" in snapshot.lower(), "Process monitor did not render"
