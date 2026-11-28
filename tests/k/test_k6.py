"""Tests for the k6 package."""
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

PKG = "k6"
PKG_FILE = "pkgs/k/k6.lua"


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
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/grafana/k6/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "2.4.0")
    local ver = assert(section["2.4.0"], "missing 2.4.0 in " .. plat)
    for _, arch in ipairs(arches) do
        local h = ver.sha256 and ver.sha256[arch] or (ver[arch] and ver[arch].sha256)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(global_url[plat] and type(global_url[plat][arch]) == "string")
    end
end
assert(package.xpm.windows["2.4.0"].aarch64 == nil)
assert(global_url.windows.aarch64 == nil)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_posix(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
dirs["/cache/k6-v2.4.0-linux-amd64"] = true

pkginfo = {
    name = function() return "k6" end,
    version = function() return "2.4.0" end,
    install_file = function() return "/cache/k6-v2.4.0-linux-amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/k6/2.4.0" end,
}
os.host = function() return "linux" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/k6"] = true
end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/k6-v2.4.0-linux-amd64" and moved[1][2] == "/xpkgs/k6/2.4.0")
assert(installed())

files["/xpkgs/k6/2.4.0/k6"] = nil
assert(not installed(), "accepted missing k6 binary")
files["/xpkgs/k6/2.4.0/k6"] = true

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "k6" and xvm_adds[1][2].bindir == "/xpkgs/k6/2.4.0")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "k6")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_macosx(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, moved = {}, {}, {}
dirs["/cache/k6-v2.4.0-macos-arm64"] = true

pkginfo = {
    name = function() return "k6" end,
    version = function() return "2.4.0" end,
    install_file = function() return "/cache/k6-v2.4.0-macos-arm64.zip" end,
    install_dir = function() return "/xpkgs/k6/2.4.0" end,
}
os.host = function() return "macosx" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/k6"] = true
end
log = { info = function() end }
fs = { mkdir_p = function() end }

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/k6-v2.4.0-macos-arm64" and moved[1][2] == "/xpkgs/k6/2.4.0")
assert(installed())
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "k6" end,
    version = function() return "2.4.0" end,
    install_file = function() return "C:/cache/k6-v2.4.0-windows-amd64.zip" end,
    install_dir = function() return "C:/xpkgs/k6/2.4.0" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/k6/2.4.0/k6.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\k6%-v2%.4%.0%-windows%-amd64%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\k6\\\\2%.4%.0"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "k6" and xvm_adds[1][2].bindir == "C:/xpkgs/k6/2.4.0")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "k6")
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
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    def _run_k6(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("k6" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
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
        out = self._run_k6("version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "2.4.0")
        assert f"k6 v{expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("k6")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_inspect_script(self):
        with tempfile.TemporaryDirectory() as work:
            script = Path(work) / "smoke.js"
            script.write_text(
                "export const options = { vus: 1, iterations: 1 };\n"
                "export default function () {}\n",
                encoding="utf-8",
            )
            out = self._run_k6("inspect", str(script))
            assert '"vus": 1' in out, out
            assert '"iterations": 1' in out, out
