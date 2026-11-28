"""Tests for the dasel package."""
import json
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
    assert_valid_xvm_node_kinds,
    assert_config_registers_package_name,
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

PKG = "dasel"
PKG_FILE = "pkgs/d/dasel.lua"
VERSION = "3.11.2"
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
    def test_platforms_arches_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local target_ver = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "dasel")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/TomWright/dasel/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64" },
}

local seen_hashes = {}
local count = 0
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.deps == nil, plat .. " uses static binary and needs no runtime deps")
    assert(section.latest and section.latest.ref == target_ver)
    local ver = assert(section[target_ver], "missing " .. target_ver .. " in " .. plat)
    for arch, alias in pairs(arches) do
        assert(ver.arch_alias[arch] == alias, plat .. "/" .. arch .. " alias mismatch")
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(not seen_hashes[h], "duplicate sha256 for " .. plat .. "/" .. arch)
        seen_hashes[h] = true
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        local resolved_au = tmpl:gsub("%${tag}", "v" .. target_ver):gsub("%${version}", target_ver)
        local resolved_xpm = section.source:gsub("%${version}", target_ver):gsub("%${arch_alias}", alias)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(ver.sha256) do
        assert(arches[arch], "unexpected arch " .. arch .. " in " .. plat)
    end
end
assert(count == 5)
assert(package.xpm.windows[target_ver].sha256.aarch64 == nil, "windows/aarch64 has no upstream asset")
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_gz_and_windows_exe(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- 1. POSIX .gz binary decompressed into install_dir/dasel + chmod +x
local files, dirs, execs, moved, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "dasel" end,
    version = function() return "3.11.2" end,
    install_file = function() return "/cache/dasel_linux_amd64.gz" end,
    install_dir = function() return "/xpkgs/dasel/3.11.2" end,
}
files["/cache/dasel_linux_amd64.gz"] = true
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("gzip %-dc", 1, false) then
            files["/xpkgs/dasel/3.11.2/dasel"] = true
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
assert(execs[1]:find('gzip %-dc', 1, false))
assert(execs[1]:find('"/cache/dasel_linux_amd64.gz"', 1, true))
assert(execs[1]:find('"/xpkgs/dasel/3.11.2/dasel"', 1, true))
assert(execs[2] == 'chmod +x "/xpkgs/dasel/3.11.2/dasel"')
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "dasel" and adds[1][2].bindir == "/xpkgs/dasel/3.11.2")
assert(uninstall())
assert(#rms == 1 and rms[1] == "dasel")

-- 2. POSIX pre-decompressed binary beside .gz fallback
files, dirs, execs, moved = {}, {}, {}, {}
files["/cache/dasel_linux_amd64"] = true
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/dasel_linux_amd64"
       and moved[1][2] == "/xpkgs/dasel/3.11.2/dasel")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/dasel/3.11.2/dasel"')
assert(installed())

-- 3. Windows raw .exe moved directly into install_dir/dasel.exe
files, dirs, execs, moved, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "dasel" end,
    version = function() return "3.11.2" end,
    install_file = function() return "C:/cache/dasel_windows_amd64.exe" end,
    install_dir = function() return "C:/xpkgs/dasel/3.11.2" end,
}
files["C:/cache/dasel_windows_amd64.exe"] = true
assert(not installed())
assert(install())
assert(#execs == 0)
assert(#moved == 1 and moved[1][1] == "C:/cache/dasel_windows_amd64.exe"
       and moved[1][2] == "C:/xpkgs/dasel/3.11.2/dasel.exe")
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "dasel" and adds[1][2].bindir == "C:/xpkgs/dasel/3.11.2")
assert(uninstall())
assert(#rms == 1 and rms[1] == "dasel")

-- 4. Missing payload must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when payload is missing")
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
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    def _run_dasel(self, *args, stdin_text=None, check_rc=0):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("dasel" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
            input=stdin_text,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        out = result.stdout + result.stderr
        if check_rc is not None:
            assert result.returncode == check_rc, f"rc={result.returncode}: {out}"
        return result.returncode, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        _, out = self._run_dasel("version")
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("dasel")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_query_json_and_yaml_offline(self):
        _, out_json = self._run_dasel(
            "-i", "json", "user.name",
            stdin_text='{"user":{"name":"alice","tags":["a","b"]}}\n',
        )
        assert json.loads(out_json) == "alice", out_json

        _, out_yaml = self._run_dasel(
            "-i", "yaml", "-o", "json", "app",
            stdin_text="app:\n  port: 8080\n",
        )
        assert json.loads(out_yaml) == {"port": 8080}, out_yaml
