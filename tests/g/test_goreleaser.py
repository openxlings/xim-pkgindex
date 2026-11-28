"""Tests for the goreleaser package."""
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

PKG = "goreleaser"
PKG_FILE = "pkgs/g/goreleaser.lua"
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
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "goreleaser")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/goreleaser/goreleaser/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "x86_64", aarch64 = "arm64" },
    macosx = { x86_64 = "x86_64", aarch64 = "arm64" },
    windows = { x86_64 = "x86_64", aarch64 = "arm64" },
}

for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "2.20.3")
    local ver = assert(section["2.20.3"], "missing 2.20.3 in " .. plat)
    for arch, alias in pairs(arches) do
        assert(ver.arch_alias[arch] == alias, plat .. "/" .. arch .. " alias mismatch")
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        local resolved_au = tmpl:gsub("%${tag}", "v2.20.3"):gsub("%${version}", "2.20.3")
        local resolved_xpm = section.source:gsub("%${version}", "2.20.3"):gsub("%${arch_alias}", alias)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
    end
    for arch in pairs(ver.sha256) do
        assert(arches[arch], "unexpected arch " .. arch .. " in " .. plat)
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- 1. POSIX flat .tar.gz extracted directly into install_dir
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
local function populate(root, exe)
    files[root .. "/" .. exe] = true
    files[root .. "/LICENSE.md"] = true
    files[root .. "/README.md"] = true
    files[root .. "/completions/goreleaser.bash"] = true
    files[root .. "/completions/goreleaser.fish"] = true
    files[root .. "/completions/goreleaser.zsh"] = true
    files[root .. "/manpages/goreleaser.1.gz"] = true
end

pkginfo = {
    name = function() return "goreleaser" end,
    version = function() return "2.20.3" end,
    install_file = function() return "/cache/goreleaser_Linux_x86_64.tar.gz" end,
    install_dir = function() return "/xpkgs/goreleaser/2.20.3" end,
}
files["/cache/goreleaser_Linux_x86_64.tar.gz"] = true
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
        if cmd:match("^tar %-xzf") then
            populate("/xpkgs/goreleaser/2.20.3", "goreleaser")
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
assert(execs[1] == 'tar -xzf "/cache/goreleaser_Linux_x86_64.tar.gz" -C "/xpkgs/goreleaser/2.20.3"')
assert(execs[2] == 'chmod +x "/xpkgs/goreleaser/2.20.3/goreleaser"')
assert(installed())

files["/xpkgs/goreleaser/2.20.3/README.md"] = nil
assert(not installed(), "accepted missing README.md")
files["/xpkgs/goreleaser/2.20.3/README.md"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "goreleaser" and adds[1][2].bindir == "/xpkgs/goreleaser/2.20.3")
assert(uninstall())
assert(#rms == 1 and rms[1] == "goreleaser")

-- 2. Windows flat .zip extracted via libs/payload.lua (System32\\tar.exe)
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "goreleaser" end,
    version = function() return "2.20.3" end,
    install_file = function() return "C:/cache/goreleaser_Windows_x86_64.zip" end,
    install_dir = function() return "C:/xpkgs/goreleaser/2.20.3" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        populate("C:/xpkgs/goreleaser/2.20.3", "goreleaser.exe")
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\goreleaser_Windows_x86_64.zip" -C "C:\\\\xpkgs\\\\goreleaser\\\\2.20.3"')
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "goreleaser" and adds[1][2].bindir == "C:/xpkgs/goreleaser/2.20.3")
assert(uninstall())
assert(#rms == 1 and rms[1] == "goreleaser")

-- 3. Missing archive must fail
files = {}
os.host = function() return "linux" end
local ok = pcall(install)
assert(not ok, "install() must fail when archive is missing")
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
        assert_install_succeeds(under_test(PKG), timeout=300)


class TestVerify:
    def _run_goreleaser(self, *args, check_rc=0):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("goreleaser" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
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
        _, out = self._run_goreleaser("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "2.20.3")
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("goreleaser")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_check_config_offline(self):
        with tempfile.TemporaryDirectory() as work:
            valid_cfg = Path(work) / ".goreleaser.yaml"
            valid_cfg.write_text("version: 2\nbuilds:\n  - skip: true\n", encoding="utf-8")
            _, ok_out = self._run_goreleaser("check", str(valid_cfg))
            assert "1 configuration file(s) validated" in ok_out, ok_out

            bad_cfg = Path(work) / "bad.yaml"
            bad_cfg.write_text("version: 2\nunknown_key_xyz: 123\n", encoding="utf-8")
            rc, bad_out = self._run_goreleaser("check", str(bad_cfg), check_rc=None)
            assert rc != 0, f"expected non-zero exit on invalid config: {bad_out}"
            assert "unknown_key_xyz" in bad_out, bad_out
