"""Tests for the qdrant package."""
import json
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

PKG = "qdrant"
PKG_FILE = "pkgs/q/qdrant.lua"
VERSION = "1.20.2"
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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["qdrant"]
        assert meta.has_xvm_enable
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "qdrant")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/qdrant/qdrant/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected = {
    linux = { x86_64 = true, aarch64 = true },
    macosx = { x86_64 = true, aarch64 = true },
    windows = { x86_64 = true },
}

local count = 0
local seen_filenames = {}
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == ver, "latest mismatch in " .. plat)
    local entry = assert(section[ver], "missing " .. ver .. " in " .. plat)
    for arch in pairs(arches) do
        local h = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^[0-9a-f]+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local resolved_xpm = section.source:gsub("%${version}", ver):gsub("%${arch}", arch)
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        local resolved_au = tmpl:gsub("%${tag}", "v" .. ver):gsub("%${version}", ver)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
        local filename = resolved_xpm:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch " .. arch .. " in " .. plat)
    end
end
assert(count == 5)
assert(package.xpm.linux.deps == nil, "musl static Linux binaries should not declare runtime deps")
assert(package.xpm.macosx.deps == nil)
local win_deps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(win_deps[1] == "xim:vcruntime" and #win_deps == 1)
assert(global_url.windows.aarch64 == nil, "windows/aarch64 not published upstream")
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local ver = arg[2]

-- 1. POSIX flat .tar.gz extracted directly into install_dir
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
local cur_file = "/cache/qdrant-x86_64-unknown-linux-musl.tar.gz"
local cur_dir = "/xpkgs/qdrant/" .. ver
local vcruntime_dir = "C:/xpkgs/xim-x-vcruntime/14.44.35211"

pkginfo = {
    name = function() return "qdrant" end,
    version = function() return ver end,
    install_file = function() return cur_file end,
    install_dir = function() return cur_dir end,
    dep_install_dir = function(dep)
        if dep == "xim:vcruntime" then return vcruntime_dir end
        return nil
    end,
}
files[cur_file] = true
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
os.cp = function(src, dst)
    local name = src:match("([^/\\\\]+)$")
    files[dst .. "/" .. name] = true
end
fs = {
    mkdir_p = function(p) dirs[p] = true end,
    files = function(p)
        if p == vcruntime_dir .. "/bin" then
            return { vcruntime_dir .. "/bin/vcruntime140.dll" }
        end
        return {}
    end,
}
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xzf") then
            files[cur_dir .. "/qdrant"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == string.format('tar -xzf "%s" -C "%s"', cur_file, cur_dir))
assert(execs[2] == string.format('chmod +x "%s/qdrant"', cur_dir))
assert(installed())

assert(config())
assert(#adds == 1 and adds[1][1] == "qdrant" and adds[1][2].bindir == cur_dir)
assert(uninstall())
assert(#rms == 1 and rms[1] == "qdrant")

-- 2. POSIX pre-extracted fallback when archive was removed
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
files["/cache/qdrant"] = true
assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == string.format('chmod +x "%s/qdrant"', cur_dir))
assert(installed())

-- 3. Windows flat .zip extracted via System32\\tar.exe + app-local vcruntime DLLs
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
cur_file = "C:/cache/qdrant-x86_64-pc-windows-msvc.zip"
cur_dir = "C:/xpkgs/qdrant/" .. ver
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files[cur_dir .. "/qdrant.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == string.format('C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\qdrant-x86_64-pc-windows-msvc.zip" -C "C:\\\\xpkgs\\\\qdrant\\\\%s"', ver))
assert(files[cur_dir .. "/qdrant.exe"] == true)
assert(files[cur_dir .. "/vcruntime140.dll"] == true)
assert(installed())

assert(config())
assert(#adds == 1 and adds[1][1] == "qdrant" and adds[1][2].bindir == cur_dir)
assert(uninstall())
assert(#rms == 1 and rms[1] == "qdrant")
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
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=180)


class TestVerify:
    def _shim(self) -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("qdrant" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_qdrant(self, *args, check=True, cwd=None):
        result = subprocess.run(
            [str(self._shim()), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
            cwd=cwd,
        )
        if check:
            assert result.returncode == 0, result.stdout + result.stderr
        return result

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        res = self._run_qdrant("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert f"qdrant {expected}" in (res.stdout + res.stderr)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_and_probe_non_blocking(self, tmp_path):
        help_res = self._run_qdrant("--help", cwd=tmp_path)
        assert "vector similarity search engine" in (help_res.stdout + help_res.stderr)

        probe_res = self._run_qdrant("/?", check=False, cwd=tmp_path)
        assert probe_res.returncode != 0
        assert not (tmp_path / "storage").exists()

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("qdrant")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists("qdrant")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_http_healthz_and_collections(self):
        def free_port() -> int:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(("127.0.0.1", 0))
                return s.getsockname()[1]

        http_port = free_port()
        grpc_port = free_port()

        with tempfile.TemporaryDirectory() as td:
            env = os.environ.copy()
            env["QDRANT__SERVICE__HOST"] = "127.0.0.1"
            env["QDRANT__SERVICE__HTTP_PORT"] = str(http_port)
            env["QDRANT__SERVICE__GRPC_PORT"] = str(grpc_port)
            env["QDRANT__STORAGE__STORAGE_PATH"] = os.path.join(td, "storage")
            env["QDRANT__STORAGE__SNAPSHOTS_PATH"] = os.path.join(td, "snapshots")
            env["QDRANT__LOG_LEVEL"] = "ERROR"

            proc = subprocess.Popen(
                [str(self._shim()), "--disable-telemetry"],
                cwd=td,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                deadline = time.monotonic() + 15.0
                health_body = None
                while time.monotonic() < deadline:
                    if proc.poll() is not None:
                        _, err = proc.communicate()
                        pytest.fail(f"qdrant exited prematurely ({proc.returncode}): {err}")
                    try:
                        with urllib.request.urlopen(f"http://127.0.0.1:{http_port}/healthz", timeout=1) as resp:
                            if resp.status == 200:
                                health_body = resp.read().decode("utf-8")
                                break
                    except Exception:
                        time.sleep(0.2)
                assert health_body and "healthz check passed" in health_body

                with urllib.request.urlopen(f"http://127.0.0.1:{http_port}/collections", timeout=5) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                assert data["status"] == "ok"
                assert data["result"]["collections"] == []
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)
