"""Tests for the miniserve package."""
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.request

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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "miniserve"
PKG_FILE = "pkgs/m/miniserve.lua"
VERSION = "0.35.0"
REPO = Path(__file__).resolve().parents[2]


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
        cwd=REPO,
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
        assert meta.spec == "2"

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_platforms_arches_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["miniserve"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "miniserve")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "miniserve")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/svenstaro/miniserve/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

assert(not package.xpm.linux.deps, "static musl linux binaries need no runtime deps")
assert(not package.xpm.macosx.deps, "macosx binaries need no runtime deps")
assert(not package.xpm.windows.deps, "static CRT windows binary needs no runtime deps")

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}

local seen_hashes = {}
local seen_filenames = {}
local count = 0
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    local arch_set = {}
    for _, arch in ipairs(arches) do
        arch_set[arch] = true
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(not seen_hashes[h], "duplicate sha256 for " .. plat .. "/" .. arch)
        seen_hashes[h] = true
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        assert(tmpl:find("${tag}", 1, true), "autoupdate template must use ${tag}")
        assert(tmpl:find("${version}", 1, true), "autoupdate template must use ${version}")
        local resolved_au = tmpl:gsub("%${tag}", "v''' + VERSION + '''"):gsub("%${version}", "''' + VERSION + '''")
        local resolved_xpm = section.source:gsub("%${version}", "''' + VERSION + '''"):gsub("%${arch}", arch)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
        local filename = resolved_xpm:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(ver.sha256) do
        assert(arch_set[arch], "unexpected arch " .. arch .. " in " .. plat)
    end
end
assert(count == 5)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_unix_raw_binary(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "miniserve" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "/cache/miniserve-''' + VERSION + '''-x86_64-unknown-linux-musl" end,
    install_dir = function() return "/xpkgs/miniserve/''' + VERSION + '''" end,
}
files["/cache/miniserve-''' + VERSION + '''-x86_64-unknown-linux-musl"] = true
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k:sub(1, #p) == p then files[k] = nil end
    end
end
os.mv = function(src, dst)
    assert(files[src], "missing src: " .. src)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd) table.insert(execs, cmd) end,
}
shell = assert(loadfile("libs/shell.lua"))()
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

dofile(arg[1])

assert(not installed())
assert(install())
assert(dirs["/xpkgs/miniserve/''' + VERSION + '''"] == true)
assert(files["/xpkgs/miniserve/''' + VERSION + '''/miniserve"] == true)
assert(#execs == 1)
assert(execs[1] == "'chmod' '+x' '/xpkgs/miniserve/''' + VERSION + '''/miniserve'")
assert(installed())

files["/xpkgs/miniserve/''' + VERSION + '''/miniserve"] = nil
assert(not installed(), "accepted missing miniserve binary")
files["/xpkgs/miniserve/''' + VERSION + '''/miniserve"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "miniserve" and adds[1][2].bindir == "/xpkgs/miniserve/''' + VERSION + '''")
assert(uninstall())
assert(#rms == 1 and rms[1] == "miniserve")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_windows_raw_binary(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "miniserve" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "C:/cache/miniserve-''' + VERSION + '''-x86_64-pc-windows-msvc.exe" end,
    install_dir = function() return "C:/xpkgs/miniserve/''' + VERSION + '''" end,
}
files["C:/cache/miniserve-''' + VERSION + '''-x86_64-pc-windows-msvc.exe"] = true
os.host = function() return "windows" end
os.getenv = function(k) return k == "OS" and "Windows_NT" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k:sub(1, #p) == p then files[k] = nil end
    end
end
os.mv = function(src, dst)
    assert(files[src], "missing src: " .. src)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd) table.insert(execs, cmd) end,
}
shell = assert(loadfile("libs/shell.lua"))()
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

dofile(arg[1])

assert(not installed())
assert(install())
assert(#execs == 0, "must not run chmod on Windows")
assert(files["C:/xpkgs/miniserve/''' + VERSION + '''/miniserve.exe"] == true)
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "miniserve" and adds[1][2].bindir == "C:/xpkgs/miniserve/''' + VERSION + '''")
assert(uninstall())
assert(#rms == 1 and rms[1] == "miniserve")
''',
            PKG_FILE,
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
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=180)


class TestVerify:
    def _shim_path(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("miniserve" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_miniserve(self, *args):
        result = subprocess.run(
            [str(self._shim_path()), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        out = self._run_miniserve("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert f"miniserve {expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_non_blocking(self):
        out = self._run_miniserve("--help")
        assert "For when you really just want to serve some files over HTTP right now!" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_serves_static_file(self):
        shim = self._shim_path()
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]

        with tempfile.TemporaryDirectory() as work:
            Path(work, "hello.txt").write_text("miniserve-ok\n", encoding="utf-8")
            proc = subprocess.Popen(
                [str(shim), "-i", "127.0.0.1", "-p", str(port), work],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                body = None
                deadline = time.monotonic() + 10.0
                while time.monotonic() < deadline:
                    if proc.poll() is not None:
                        out, err = proc.communicate()
                        pytest.fail(f"miniserve exited early ({proc.returncode}): {out}\n{err}")
                    try:
                        with urllib.request.urlopen(f"http://127.0.0.1:{port}/hello.txt", timeout=1.0) as resp:
                            if resp.status == 200:
                                body = resp.read().decode("utf-8")
                                break
                    except Exception:
                        time.sleep(0.1)
                assert body == "miniserve-ok\n"
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = "current" if (Path(xlings_home()) / "subos" / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS")
        if subos:
            shim = Path(xlings_home()) / "subos" / subos / "bin" / ("miniserve" + suffix)
            assert shim.is_file(), f"shim not found at {shim}"
        else:
            assert_xvm_shim_exists(PKG)
