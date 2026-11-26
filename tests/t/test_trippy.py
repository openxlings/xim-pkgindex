"""Tests for the trippy package (`trip` CLI/TUI)."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_config_registers_package_name,
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

PKG = "trippy"
PKG_FILE = "pkgs/t/trippy.lua"
VERSION = "0.13.0"
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
        check=True,
        cwd=REPO_ROOT,
    ).stdout


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def code(meta):
    return "\n".join(
        line for line in meta.raw_content.splitlines()
        if not line.lstrip().startswith("--")
    )


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
    def test_package_registration(self, meta):
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_all_platforms_and_arches_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["trip"]
        _run_lua(
            r'''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "trippy")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "trip")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/fujiapple852/trippy/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

assert(package.xpm.linux.deps == nil, "musl static Linux binaries need no runtime deps")
local wdeps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime")

local expected = {
    linux = { arches = { "x86_64", "aarch64" }, ext = "tar.gz" },
    macosx = { arches = { "x86_64", "aarch64" }, ext = "tar.gz" },
    windows = { arches = { "x86_64" }, ext = "zip" },
}
local seen_hashes, seen_filenames = {}, {}
local count = 0

for plat, spec in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    assert(ver.sha256, "missing sha256 table in " .. plat)
    for _, arch in ipairs(spec.arches) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^[0-9a-f]+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(not seen_hashes[h], "duplicate sha256: " .. h)
        seen_hashes[h] = true

        local xpm_resolved = section.source
            :gsub("%${version}", "''' + VERSION + '''")
            :gsub("%${arch}", arch)
            :gsub("%${ext}", spec.ext)
        local tpl = assert(global_url[plat] and global_url[plat][arch],
                           "missing autoupdate url for " .. plat .. "/" .. arch)
        local auto_resolved = tpl:gsub("%${tag}", "''' + VERSION + '''"):gsub("%${version}", "''' + VERSION + '''")
        assert(auto_resolved == xpm_resolved,
               "xpm and autoupdate URLs disagree for " .. plat .. "/" .. arch)
        local filename = xpm_resolved:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
end
assert(count == 5, "expected 5 platform/arch entries")
assert(package.xpm.windows["''' + VERSION + '''"].sha256.aarch64 == nil,
       "windows/aarch64 imports VCRUNTIME140.dll and is omitted")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_posix_unpack_and_group_registration(self):
        _run_lua(
            r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
system = {}
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files["/cache/trippy-0.13.0-x86_64-unknown-linux-musl.tar.gz"] = true

pkginfo = {
    name = function() return "trippy" end,
    version = function() return "0.13.0" end,
    install_file = function() return "/cache/trippy-0.13.0-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/trippy/0.13.0" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    if dirs[src] then
        dirs[src] = nil
        dirs[dst] = true
        local prefix = src .. "/"
        local to_move = {}
        for k, v in pairs(files) do
            if k:sub(1, #prefix) == prefix and v then
                table.insert(to_move, k)
            end
        end
        for _, k in ipairs(to_move) do
            files[k] = nil
            files[dst .. "/" .. k:sub(#prefix + 1)] = true
        end
    end
end
log = { info = function() end }
fs = { mkdir_p = function(p) dirs[p] = true end }
system.exec = function(cmd)
    table.insert(execs, cmd)
    if cmd:match("^'tar' '%-xzf'") then
        dirs["/cache/trippy-0.13.0-x86_64-unknown-linux-musl"] = true
        files["/cache/trippy-0.13.0-x86_64-unknown-linux-musl/trip"] = true
    end
end
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == "'tar' '-xzf' '/cache/trippy-0.13.0-x86_64-unknown-linux-musl.tar.gz' '-C' '/cache'")
assert(execs[2] == "'chmod' '+x' '/xpkgs/trippy/0.13.0/trip'")
assert(installed())

files["/xpkgs/trippy/0.13.0/trip"] = nil
assert(not installed(), "accepted missing trip binary")
files["/xpkgs/trippy/0.13.0/trip"] = true

assert(config())
assert(#xvm_adds == 2)
assert(xvm_adds[1][1] == "trip" and xvm_adds[1][2].bindir == "/xpkgs/trippy/0.13.0")
assert(xvm_adds[2][1] == "trippy" and xvm_adds[2][2].type == "group")

assert(uninstall())
assert(#xvm_rms == 2)
assert(xvm_rms[1] == "trip" and xvm_rms[2] == "trippy")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_windows_zip_and_vcruntime_copy(self):
        _run_lua(
            r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
system = {}
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

local files, dirs, execs, copied, xvm_adds, xvm_rms = {}, {}, {}, {}, {}, {}
local vcruntime_dir = "C:/xpkgs/vcruntime/14.44.35211"

pkginfo = {
    name = function() return "trippy" end,
    version = function() return "0.13.0" end,
    install_file = function() return "C:/cache/trippy-0.13.0-x86_64-pc-windows-msvc.zip" end,
    install_dir = function() return "C:/xpkgs/trippy/0.13.0" end,
    dep_install_dir = function(dep)
        assert(dep == "xim:vcruntime")
        return vcruntime_dir
    end,
}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.cp = function(src, dst)
    table.insert(copied, {src, dst})
    local name = src:match("([^/\\]+)$")
    files[dst .. "/" .. name] = true
end
log = { info = function() end }
fs = {
    mkdir_p = function(p) dirs[p] = true end,
    files = function(d)
        assert(d == vcruntime_dir .. "/bin")
        return { d .. "/vcruntime140.dll", d .. "/msvcp140.dll" }
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system.exec = function(cmd)
    table.insert(execs, cmd)
    files["C:/xpkgs/trippy/0.13.0/trip.exe"] = true
end

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\Windows\\System32\\tar.exe -xf "C:\\cache\\trippy-0.13.0-x86_64-pc-windows-msvc.zip" --strip-components=1 -C "C:\\xpkgs\\trippy\\0.13.0"')
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/trippy/0.13.0")
assert(files["C:/xpkgs/trippy/0.13.0/vcruntime140.dll"] == true)
assert(installed())

assert(config())
assert(#xvm_adds == 2)
assert(xvm_adds[1][1] == "trip" and xvm_adds[1][2].bindir == "C:/xpkgs/trippy/0.13.0")
assert(xvm_adds[2][1] == "trippy" and xvm_adds[2][2].type == "group")

assert(uninstall())
assert(#xvm_rms == 2)
assert(xvm_rms[1] == "trip" and xvm_rms[2] == "trippy")
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
    def test_portable_lua_and_libxpkg_only(self, code):
        assert set(re.findall(r'import\("([^"]+)"\)', code)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|try\s*\{|raise\()', code)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    def _trip_shim(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("trip" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return str(shim)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        res = subprocess.run(
            [self._trip_shim(), "--version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
        assert res.returncode == 0, res.stdout + res.stderr
        assert f"trip {expected}" in res.stdout, res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_and_non_blocking_probe(self):
        shim = self._trip_shim()
        help_res = subprocess.run(
            [shim, "--help"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
        assert help_res.returncode == 0, help_res.stdout + help_res.stderr
        assert "network diagnostic tool" in help_res.stdout.lower(), help_res.stdout

        probe_res = subprocess.run(
            [shim, "/?"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=5,
        )
        # Without elevated privileges `/?` exits immediately instead of opening TUI.
        assert probe_res.returncode in (0, 1), probe_res.stdout + probe_res.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_print_config_template(self):
        res = subprocess.run(
            [self._trip_shim(), "--print-config-template"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
        assert res.returncode == 0, res.stdout + res.stderr
        assert "[trippy]" in res.stdout, res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = Path(xlings_home()) / "subos"
            monkeypatch.setenv(
                "XLINGS_TEST_SUBOS",
                "current" if (subos / "current").is_dir() else "default",
            )
        assert_xvm_registered("trip")
        assert_xvm_registered("trippy")
