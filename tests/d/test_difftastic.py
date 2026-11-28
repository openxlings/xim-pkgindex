"""Tests for the difftastic package (`difft` CLI)."""
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

PKG = "difftastic"
PKG_FILE = "pkgs/d/difftastic.lua"
VERSION = "0.72.0"


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
        assert meta.programs == ["difft"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "difftastic")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/Wilfred/difftastic/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)

local ldeps = package.xpm.linux.deps and package.xpm.linux.deps.runtime or {}
assert(#ldeps == 2 and ldeps[1]:find("xim:glibc", 1, true) and ldeps[2]:find("xim:gcc-runtime", 1, true))
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
assert(package.xpm.linux["''' + VERSION + '''"].arch_alias.x86_64 == "x86_64-unknown-linux-musl")
assert(package.xpm.linux["''' + VERSION + '''"].arch_alias.aarch64 == "aarch64-unknown-linux-gnu")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_all_five_sha256_unique(self, meta):
        sha_matches = re.findall(r'(?:x86_64|aarch64)\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(sha_matches) == 5
        assert len(set(sha_matches)) == 5

    @pytest.mark.static
    def test_hooks_posix_tar_and_group_registration(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files["/cache/difft-0.72.0-x86_64-unknown-linux-musl.tar.gz"] = true

pkginfo = {
    name = function() return "difftastic" end,
    version = function() return "0.72.0" end,
    install_file = function() return "/cache/difft-0.72.0-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/difftastic/0.72.0" end,
}
os.host = function() return "linux" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function(p) dirs[p] = true end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xzf ") then
            files["/xpkgs/difftastic/0.72.0/difft"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/difft-0.72.0-x86_64-unknown-linux-musl.tar.gz" -C "/xpkgs/difftastic/0.72.0"')
assert(execs[2] == 'chmod +x "/xpkgs/difftastic/0.72.0/difft"')
assert(installed())

files["/xpkgs/difftastic/0.72.0/difft"] = nil
assert(not installed(), "accepted missing difft binary")
files["/xpkgs/difftastic/0.72.0/difft"] = true

assert(config())
assert(#xvm_adds == 2)
assert(xvm_adds[1][1] == "difft" and xvm_adds[1][2].bindir == "/xpkgs/difftastic/0.72.0")
assert(xvm_adds[2][1] == "difftastic" and xvm_adds[2][2].type == "group")

assert(uninstall())
assert(#xvm_rms == 2)
assert(xvm_rms[1] == "difft" and xvm_rms[2] == "difftastic")
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
    name = function() return "difftastic" end,
    version = function() return "0.72.0" end,
    install_file = function() return "C:/cache/difft-0.72.0-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/difftastic/0.72.0" end,
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
        files["C:/xpkgs/difftastic/0.72.0/difft.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\difft%-0%.72%.0%-x86_64%-pc%-windows%-msvc%.zip" %-C "C:\\\\xpkgs\\\\difftastic\\\\0%.72%.0"$'))
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/difftastic/0.72.0")
assert(installed())

assert(config())
assert(#xvm_adds == 2)
assert(xvm_adds[1][1] == "difft" and xvm_adds[1][2].bindir == "C:/xpkgs/difftastic/0.72.0")
assert(xvm_adds[2][1] == "difftastic" and xvm_adds[2][2].type == "group")

assert(uninstall())
assert(#xvm_rms == 2)
assert(xvm_rms[1] == "difft" and xvm_rms[2] == "difftastic")
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
            "xim.libxpkg.system",
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
    def _run_difft(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("difft" + suffix)
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
        res = self._run_difft("--version")
        assert res.returncode == 0, res.stdout + res.stderr
        assert f"Difftastic {expected}" in res.stdout, res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("difft")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_diffs_two_files(self):
        with tempfile.TemporaryDirectory() as work:
            a = Path(work) / "a.py"
            b = Path(work) / "b.py"
            a.write_text("def greet():\n    return 'hello'\n", encoding="utf-8")
            b.write_text("def greet():\n    return 'world'\n", encoding="utf-8")
            res = self._run_difft("--color=never", str(a), str(b))
            assert res.returncode == 0, res.stdout + res.stderr
            assert "Python" in res.stdout, res.stdout
            assert "hello" in res.stdout and "world" in res.stdout, res.stdout
