"""Tests for the rclone package."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_command_output,
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
    assert_xim_add_succeeds,
    assert_xvm_registered,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "rclone"
PKG_FILE = "pkgs/r/rclone.lua"
VERSION = "1.76.0"
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
    def test_platforms_arches_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "rclone")

local auto = assert(package.extensions and package.extensions.autoupdate, "missing autoupdate")
assert(auto.source == "https://github.com/rclone/rclone/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected_os = { linux = "linux", macosx = "osx", windows = "windows" }
local count = 0
for plat, os_tag in pairs(expected_os) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(not section.deps, "static binary should not declare deps on " .. plat)
    local version = assert(section.latest and section.latest.ref)
    assert(version == "1.76.0")
    local ver = assert(section[version], "missing version entry in " .. plat)
    assert(ver.arch_alias and ver.arch_alias.x86_64 == "amd64" and ver.arch_alias.aarch64 == "arm64")
    for arch, alias in pairs({ x86_64 = "amd64", aarch64 = "arm64" }) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local au_tmpl = assert(global_url[plat] and global_url[plat][arch])
        assert(au_tmpl:find("${tag}", 1, true) and au_tmpl:find("${version}", 1, true))
        local au_resolved = au_tmpl:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local xpm_resolved = section.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(au_resolved == xpm_resolved, "URL mismatch on " .. plat .. "/" .. arch)
        assert(xpm_resolved:find("rclone%-v" .. version .. "%-" .. os_tag .. "%-" .. alias .. "%.zip$"))
        count = count + 1
    end
end
assert(count == 6)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_posix_preextracted_and_fallbacks(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX with pre-extracted directory beside the archive
local files, dirs, moved, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}, {}
dirs["/cache/rclone-v1.76.0-linux-amd64"] = true

pkginfo = {
    name = function() return "rclone" end,
    version = function() return "1.76.0" end,
    install_file = function() return "/cache/rclone-v1.76.0-linux-amd64.zip" end,
    install_dir = function() return "/xpkgs/rclone/1.76.0" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/rclone"] = true
    files[dst .. "/rclone.1"] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/rclone-v1.76.0-linux-amd64" and moved[1][2] == "/xpkgs/rclone/1.76.0")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/rclone/1.76.0/rclone"')
assert(installed())

files["/xpkgs/rclone/1.76.0/rclone"] = nil
assert(not installed(), "accepted missing rclone binary")
files["/xpkgs/rclone/1.76.0/rclone"] = true
files["/xpkgs/rclone/1.76.0/rclone.1"] = nil
assert(not installed(), "accepted missing rclone.1")
files["/xpkgs/rclone/1.76.0/rclone.1"] = true

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "rclone" and xvm_adds[1][2].bindir == "/xpkgs/rclone/1.76.0")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "rclone")

-- Case 2: POSIX fallback via unzip -q -o when archive is not pre-extracted
files, dirs, moved, execs = {}, {}, {}, {}
files["/cache/rclone-v1.76.0-linux-amd64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^unzip ") then
            dirs["/xpkgs/rclone/1.76.0.unpack/rclone-v1.76.0-linux-amd64"] = true
        end
    end,
}
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'unzip -q -o "/cache/rclone-v1.76.0-linux-amd64.zip" -d "/xpkgs/rclone/1.76.0.unpack"')
assert(execs[2] == 'chmod +x "/xpkgs/rclone/1.76.0/rclone"')

-- Case 3: POSIX tar fallback if unzip fails
files, dirs, moved, execs = {}, {}, {}, {}
files["/cache/rclone-v1.76.0-linux-amd64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^unzip ") then
            error("unzip unavailable")
        elseif cmd:match("^tar ") then
            files["/xpkgs/rclone/1.76.0/rclone"] = true
            files["/xpkgs/rclone/1.76.0/rclone.1"] = true
        end
    end,
}
assert(install())
assert(installed())
assert(#execs == 3)
assert(execs[2] == 'tar -xf "/cache/rclone-v1.76.0-linux-amd64.zip" --strip-components=1 -C "/xpkgs/rclone/1.76.0"')
assert(execs[3] == 'chmod +x "/xpkgs/rclone/1.76.0/rclone"')
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_windows_via_payload_unpack(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "rclone" end,
    version = function() return "1.76.0" end,
    install_file = function() return "C:/cache/rclone-v1.76.0-windows-amd64.zip" end,
    install_dir = function() return "C:/xpkgs/rclone/1.76.0" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or (k == "OS" and "Windows_NT" or nil) end
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
        files["C:/xpkgs/rclone/1.76.0/rclone.exe"] = true
        files["C:/xpkgs/rclone/1.76.0/rclone.1"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\rclone-v1.76.0-windows-amd64.zip" --strip-components=1 -C "C:\\\\xpkgs\\\\rclone\\\\1.76.0"')
assert(installed())

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "rclone" and xvm_adds[1][2].bindir == "C:/xpkgs/rclone/1.76.0")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "rclone")
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
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output("rclone --version", contains=f"rclone v{expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_local_copy_and_lsf(self):
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("rclone.exe" if os.name == "nt" else "rclone")
        assert shim.is_file(), f"Missing installed shim: {shim}"
        with tempfile.TemporaryDirectory() as work:
            src = Path(work) / "src"
            dst = Path(work) / "dst"
            src.mkdir()
            (src / "hello.txt").write_text("rclone-ok\n", encoding="utf-8")
            subprocess.run([str(shim), "copy", str(src), str(dst)], check=True, timeout=30)
            assert (dst / "hello.txt").read_text(encoding="utf-8") == "rclone-ok\n"
            lsf = subprocess.run([str(shim), "lsf", str(dst)], capture_output=True, text=True, check=True, timeout=30)
            assert "hello.txt" in lsf.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists(PKG)
