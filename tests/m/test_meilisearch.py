"""Tests for the meilisearch package."""
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
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_valid_xvm_node_kinds,
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

PKG = "meilisearch"
PKG_FILE = "pkgs/m/meilisearch.lua"
VERSION = "1.58.0"
REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
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
    def test_all_platforms_arches_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["meilisearch"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "meilisearch")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/meilisearch/meilisearch/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)

local ldeps = package.xpm.linux.deps and package.xpm.linux.deps.runtime or {}
assert(#ldeps == 2 and ldeps[1] == "xim:glibc@>=2.39" and ldeps[2] == "xim:gcc-runtime")
local wdeps = package.xpm.windows.deps and package.xpm.windows.deps.runtime or {}
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime")

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "aarch64" },
    macosx = { x86_64 = "amd64", aarch64 = "apple-silicon" },
    windows = { x86_64 = "amd64" },
}
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(type(section.source) == "string" and section.source:find("${version}", 1, true))
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    assert(ver.sha256, "missing sha256 table in " .. plat)
    assert(ver.arch_alias, "missing arch_alias table in " .. plat)
    for arch, alias in pairs(arches) do
        assert(ver.arch_alias[arch] == alias, "alias mismatch for " .. plat .. "/" .. arch)
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        local auto_resolved = tpl:gsub("%${tag}", "v''' + VERSION + '''")
        local src_resolved = section.source:gsub("%${version}", "''' + VERSION + '''"):gsub("%${arch_alias}", alias)
        assert(auto_resolved == src_resolved, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
    end
    for arch in pairs(ver.sha256) do
        assert(arches[arch], "unexpected arch in " .. plat .. ": " .. arch)
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_all_five_sha256_unique(self, meta):
        sha_matches = re.findall(r'(?:x86_64|aarch64)\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(sha_matches) == 5
        assert len(set(sha_matches)) == 5

    @pytest.mark.static
    def test_hooks_posix_and_windows_in_lua_sandbox(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX raw binary
local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local dl = "/cache/meilisearch-linux-amd64"
local dst_dir = "/xpkgs/xim-x-meilisearch/1.58.0"
files[dl] = true

pkginfo = {
    name = function() return "meilisearch" end,
    version = function() return "1.58.0" end,
    install_file = function() return dl end,
    install_dir = function() return dst_dir end,
}
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
system = { exec = function(cmd) table.insert(execs, cmd) end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(files[dst_dir .. "/meilisearch"])
assert(#execs == 1 and execs[1] == 'chmod +x "' .. dst_dir .. '/meilisearch"')
assert(installed())

files[dst_dir .. "/meilisearch"] = nil
assert(not installed(), "accepted missing meilisearch binary")
files[dst_dir .. "/meilisearch"] = true

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "meilisearch" and xvm_adds[1][2].bindir == dst_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "meilisearch")

-- Case 2: Windows raw .exe + vcruntime copy
files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local copied = {}
dl = "C:/cache/meilisearch-windows-amd64.exe"
dst_dir = "C:/xpkgs/xim-x-meilisearch/1.58.0"
files[dl] = true
pkginfo.install_file = function() return dl end
pkginfo.install_dir = function() return dst_dir end
pkginfo.dep_install_dir = function(dep)
    assert(dep == "xim:vcruntime")
    return "C:/xpkgs/xim-x-vcruntime/14.44.35211"
end
fs.files = function(d)
    assert(d == "C:/xpkgs/xim-x-vcruntime/14.44.35211/bin")
    return { d .. "/vcruntime140.dll", d .. "/msvcp140.dll" }
end
os.cp = function(src, dst) table.insert(copied, {src, dst}) end

assert(not installed())
assert(install())
assert(files[dst_dir .. "/meilisearch.exe"])
assert(#execs == 0, "must not run chmod on Windows")
assert(#copied == 2 and copied[1][2] == dst_dir)
assert(installed())
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "meilisearch" and xvm_adds[1][2].bindir == dst_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "meilisearch")
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
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
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
        assert_install_succeeds(under_test(PKG), timeout=300)


class TestVerify:
    def _shim_path(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / "default" / "bin"
        shim = bindir / ("meilisearch" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        res = subprocess.run(
            [str(self._shim_path()), "--version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert res.returncode == 0, res.stdout + res.stderr
        assert f"meilisearch {expected}" in res.stdout, res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("meilisearch")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_http_health_and_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        shim = self._shim_path()
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]

        with tempfile.TemporaryDirectory() as work:
            proc = subprocess.Popen(
                [
                    str(shim),
                    "--db-path", f"{work}/data.ms",
                    "--dump-dir", f"{work}/dumps",
                    "--snapshot-dir", f"{work}/snapshots",
                    "--http-addr", f"127.0.0.1:{port}",
                    "--no-analytics",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                health = None
                for _ in range(50):
                    if proc.poll() is not None:
                        raise AssertionError(
                            f"meilisearch exited early ({proc.returncode}): {proc.stderr.read()}"
                        )
                    try:
                        with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2) as resp:
                            health = json.loads(resp.read().decode("utf-8"))
                            break
                    except Exception:
                        time.sleep(0.2)
                assert health == {"status": "available"}, f"unexpected /health response: {health}"
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/version", timeout=2) as resp:
                    ver = json.loads(resp.read().decode("utf-8"))
                assert ver.get("pkgVersion") == expected, ver
            finally:
                proc.terminate()
                proc.wait(timeout=10)
