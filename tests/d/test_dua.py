"""Tests for the dua package (`dua` CLI)."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

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

PKG = "dua"
PKG_FILE = "pkgs/d/dua.lua"
VERSION = "3.0.3"


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
    def test_all_platforms_and_arches_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["dua"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "dua")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/Byron/dua-cli/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)

assert(not (package.xpm.linux.deps and package.xpm.linux.deps.runtime), "linux musl binaries need no runtime deps")
local wdeps = package.xpm.windows.deps and package.xpm.windows.deps.runtime or {}
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime")

local expected = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(type(section.source) == "string" and section.source:find("${version}", 1, true))
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    assert(ver.sha256, "missing sha256 table in " .. plat)
    for _, arch in ipairs(arches) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        assert(tpl:find("${tag}", 1, true) and tpl:find("${version}", 1, true), "missing ${tag}/${version} in " .. tpl)
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
    def test_hooks_posix_unpack_and_register(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local extracted_dir = "/cache/dua-v3.0.3-x86_64-unknown-linux-musl"
dirs[extracted_dir] = true

pkginfo = {
    name = function() return "dua" end,
    version = function() return "3.0.3" end,
    install_file = function() return "/cache/dua-v3.0.3-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/dua/3.0.3" end,
}
os.host = function() return "linux" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/dua"] = true
    files[dst .. "/LICENSE"] = true
end
log = { info = function() end }
fs = { mkdir_p = function(p) dirs[p] = true end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1)
assert(moved[1][1] == extracted_dir and moved[1][2] == "/xpkgs/dua/3.0.3")
assert(installed())

files["/xpkgs/dua/3.0.3/dua"] = nil
assert(not installed(), "accepted missing dua binary")
files["/xpkgs/dua/3.0.3/dua"] = true

assert(config())
assert(#xvm_adds == 1)
assert(xvm_adds[1][1] == "dua" and xvm_adds[1][2].bindir == "/xpkgs/dua/3.0.3")

assert(uninstall())
assert(#xvm_rms == 1)
assert(xvm_rms[1] == "dua")
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
dofile(arg[1])

local files, dirs, execs, copied, xvm_adds, xvm_rms = {}, {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "dua" end,
    version = function() return "3.0.3" end,
    install_file = function() return "C:/cache/dua-v3.0.3-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/dua/3.0.3" end,
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
    mkdir_p = function() end,
    files = function(d)
        assert(d == "C:/xpkgs/vcruntime/14.44.35211/bin")
        return { d .. "/vcruntime140.dll", d .. "/msvcp140.dll" }
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/dua/3.0.3/dua.exe"] = true
        files["C:/xpkgs/dua/3.0.3/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\dua%-v3%.0%.3%-x86_64%-pc%-windows%-msvc%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\dua\\\\3%.0%.3"$'))
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/dua/3.0.3")
assert(installed())

assert(config())
assert(#xvm_adds == 1)
assert(xvm_adds[1][1] == "dua" and xvm_adds[1][2].bindir == "C:/xpkgs/dua/3.0.3")

assert(uninstall())
assert(#xvm_rms == 1)
assert(xvm_rms[1] == "dua")
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
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    def _run_dua(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("dua" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        res = self._run_dua("--version")
        assert res.returncode == 0, res.stdout + res.stderr
        assert f"dua {expected}" in res.stdout, res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("dua")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_inspects_directory(self):
        with tempfile.TemporaryDirectory() as work:
            sub = Path(work) / "sample_dir"
            sub.mkdir()
            (sub / "alpha.txt").write_bytes(b"a" * 4096)
            (sub / "beta.bin").write_bytes(b"b" * 8192)
            res = self._run_dua("aggregate", str(work))
            assert res.returncode == 0, res.stdout + res.stderr
            assert "sample_dir" in res.stdout or str(work) in res.stdout, res.stdout
            assert "total" in res.stdout.lower() or "12" in res.stdout or "B" in res.stdout, res.stdout
