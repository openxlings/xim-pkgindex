"""Tests for the dufs package."""
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

from tests.lib.xpkg_parser import parse_xpkg
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

PKG = "dufs"
PKG_FILE = "pkgs/d/dufs.lua"
VERSION = "0.47.0"
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
        assert meta.programs == ["dufs"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "dufs")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "dufs")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/sigoden/dufs/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

assert(not package.xpm.linux.deps, "static musl linux binaries need no runtime deps")
local wdeps = package.xpm.windows.deps and package.xpm.windows.deps.runtime or {}
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime")

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}

local seen_hashes = {}
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
        local resolved_au = tmpl:gsub("%${tag}", "v''' + VERSION + '''"):gsub("%${version}", "''' + VERSION + '''")
        local resolved_xpm = section.source:gsub("%${version}", "''' + VERSION + '''"):gsub("%${arch}", arch)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
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
    def test_hooks_posix_tar(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "dufs" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "/cache/dufs-v''' + VERSION + '''-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/dufs/''' + VERSION + '''" end,
}
files["/cache/dufs-v''' + VERSION + '''-x86_64-unknown-linux-musl.tar.gz"] = true
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^'tar' '%-xzf'") then
            files["/xpkgs/dufs/''' + VERSION + '''/dufs"] = true
        end
    end,
}
shell = assert(loadfile("libs/shell.lua"))()
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

dofile(arg[1])

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == "'tar' '-xzf' '/cache/dufs-v''' + VERSION + '''-x86_64-unknown-linux-musl.tar.gz' '-C' '/xpkgs/dufs/''' + VERSION + ''''")
assert(execs[2] == "'chmod' '+x' '/xpkgs/dufs/''' + VERSION + '''/dufs'")
assert(installed())

files["/xpkgs/dufs/''' + VERSION + '''/dufs"] = nil
assert(not installed(), "accepted missing dufs binary")
files["/xpkgs/dufs/''' + VERSION + '''/dufs"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "dufs" and adds[1][2].bindir == "/xpkgs/dufs/''' + VERSION + '''")
assert(uninstall())
assert(#rms == 1 and rms[1] == "dufs")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_windows_zip_and_vcruntime_copy(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
local files, dirs, execs, copied, adds, rms = {}, {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "dufs" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "C:/cache/dufs-v''' + VERSION + '''-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/dufs/''' + VERSION + '''" end,
    dep_install_dir = function(dep)
        assert(dep == "xim:vcruntime")
        return "C:/xpkgs/vcruntime/14.44.35211"
    end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.cp = function(src, dst) table.insert(copied, {src, dst}) end
log = { info = function() end }
fs = {
    mkdir_p = function(p) dirs[p] = true end,
    files = function(d)
        assert(d == "C:/xpkgs/vcruntime/14.44.35211/bin")
        return { d .. "/vcruntime140.dll", d .. "/msvcp140.dll" }
    end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/dufs/''' + VERSION + '''/dufs.exe"] = true
    end,
}
shell = assert(loadfile("libs/shell.lua"))()
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

dofile(arg[1])

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\dufs-v''' + VERSION + '''-x86_64-pc-windows-msvc.zip" -C "C:\\\\xpkgs\\\\dufs\\\\''' + VERSION + '''"')
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/dufs/''' + VERSION + '''")
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "dufs" and adds[1][2].bindir == "C:/xpkgs/dufs/''' + VERSION + '''")
assert(uninstall())
assert(#rms == 1 and rms[1] == "dufs")
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
        src = Path(PKG_FILE).read_text(encoding="utf-8")
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
        shim = bindir / ("dufs" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_dufs(self, *args):
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
        out = self._run_dufs("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert f"dufs {expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_non_blocking(self):
        out = self._run_dufs("--help")
        assert "Dufs is a distinctive utility file server" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_serves_static_file(self):
        shim = self._shim_path()
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]

        with tempfile.TemporaryDirectory() as work:
            Path(work, "hello.txt").write_text("dufs-ok\n", encoding="utf-8")
            proc = subprocess.Popen(
                [str(shim), "-b", "127.0.0.1", "-p", str(port), work],
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
                        pytest.fail(f"dufs exited early ({proc.returncode}): {out}\n{err}")
                    try:
                        with urllib.request.urlopen(f"http://127.0.0.1:{port}/hello.txt", timeout=1.0) as resp:
                            if resp.status == 200:
                                body = resp.read().decode("utf-8")
                                break
                    except Exception:
                        time.sleep(0.1)
                assert body == "dufs-ok\n"
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("dufs")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists("dufs")
