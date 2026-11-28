"""Tests for the typos package (crate-ci/typos)."""
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
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "typos"
PKG_FILE = "pkgs/t/typos.lua"
VERSION = "1.52.2"
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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

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
local ver = arg[2]

assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "typos")

local auto = assert(package.extensions and package.extensions.autoupdate, "missing autoupdate")
assert(auto.source == "https://github.com/crate-ci/typos/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}
local count = 0
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(p.deps == nil, plat .. " should declare no deps")
    assert(p.latest and p.latest.ref == ver, "latest.ref mismatch in " .. plat)
    local entry = assert(p[ver], "missing version entry in " .. plat)
    local seen = {}
    for _, arch in ipairs(arches) do
        seen[arch] = true
        local res = assert(entry[arch], "missing " .. plat .. "/" .. arch)
        assert(type(res.url) == "string" and res.url:find("v" .. ver, 1, true))
        assert(type(res.sha256) == "string" and #res.sha256 == 64 and res.sha256:match("^%x+$"))
        local auto_resolved = assert(global_url[plat] and global_url[plat][arch]):gsub("%${tag}", "v" .. ver)
        assert(res.url == auto_resolved, "xpm and autoupdate URLs disagree for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for k in pairs(entry) do
        assert(seen[k], "unexpected arch entry " .. plat .. "/" .. k)
    end
end
assert(package.xpm.windows[ver].aarch64 == nil, "windows/aarch64 waits for xim:vcruntime ARM64 support")
assert(global_url.windows.aarch64 == nil, "autoupdate must match supported windows/x86_64-only matrix")
assert(count == 5)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_and_windows_in_lua_sandbox(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- 1. POSIX flat tarball extraction + chmod + config + uninstall
local files, dirs, execs, mvs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "typos" end,
    install_file = function() return "/cache/typos-v1.52.2-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir  = function() return "/xpkgs/typos/1.52.2" end,
}
files["/cache/typos-v1.52.2-x86_64-unknown-linux-musl.tar.gz"] = true
os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(mvs, {src, dst})
    files[src] = nil
    files[dst] = true
end
os.getenv = function() return nil end
fs = { mkdir_p = function(p) dirs[p] = true end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xzf") then
            files["/xpkgs/typos/1.52.2/typos"] = true
            files["/xpkgs/typos/1.52.2/README.md"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/typos-v1.52.2-x86_64-unknown-linux-musl.tar.gz" -C "/xpkgs/typos/1.52.2"')
assert(execs[2] == 'chmod +x "/xpkgs/typos/1.52.2/typos"')
assert(config())
assert(#adds == 1 and adds[1][1] == "typos" and adds[1][2].bindir == "/xpkgs/typos/1.52.2")
assert(uninstall())
assert(#rms == 1 and rms[1] == "typos")

-- 2. Windows flat zip extraction via System32\\tar.exe
files, dirs, execs, mvs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "typos" end,
    install_file = function() return "C:/cache/typos-v1.52.2-x86_64-pc-windows-msvc.zip" end,
    install_dir  = function() return "C:/xpkgs/typos/1.52.2" end,
}
files["C:/cache/typos-v1.52.2-x86_64-pc-windows-msvc.zip"] = true
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/typos/1.52.2/typos.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\typos-v1.52.2-x86_64-pc-windows-msvc.zip" -C "C:\\\\xpkgs\\\\typos\\\\1.52.2"')

-- 3. Pre-extracted fallback without archive file
files, dirs, execs, mvs = {}, {}, {}, {}
pkginfo = {
    name = function() return "typos" end,
    install_file = function() return "/cache/typos-v1.52.2-x86_64-unknown-linux-musl.tar.gz" end,
    install_dir  = function() return "/xpkgs/typos/1.52.2" end,
}
files["/cache/typos"] = true
files["/cache/LICENSE-MIT"] = true
assert(install())
assert(installed())
assert(#mvs == 2)
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/typos/1.52.2/typos"')

-- 4. Missing both archive and pre-extracted binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
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
            "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    def _typos_bin(self):
        suffix = ".exe" if os.name == "nt" else ""
        for subos in (
            os.environ.get("XLINGS_TEST_SUBOS", "current"),
            "default",
        ):
            shim = Path(xlings_home()) / "subos" / subos / "bin" / ("typos" + suffix)
            if shim.is_file():
                return str(shim)
        raise AssertionError("Missing installed typos shim in XLINGS_HOME/subos/*/bin")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output("typos --version", contains=f"typos-cli {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("typos")
        assert_xvm_shim_exists("typos")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_detects_typo_on_temp_file(self):
        typos_bin = self._typos_bin()
        with tempfile.TemporaryDirectory() as work:
            bad = Path(work) / "sample.rs"
            bad.write_text("let teh = 1;\n", encoding="utf-8")
            proc_bad = subprocess.run(
                [typos_bin, "--isolated", str(bad)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                timeout=30,
            )
            assert proc_bad.returncode == 2, proc_bad.stdout + proc_bad.stderr
            combined = proc_bad.stdout + proc_bad.stderr
            assert "teh" in combined and "the" in combined, combined

            good = Path(work) / "clean.rs"
            good.write_text("let the = 1;\n", encoding="utf-8")
            proc_good = subprocess.run(
                [typos_bin, "--isolated", str(good)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                timeout=30,
            )
            assert proc_good.returncode == 0, proc_good.stdout + proc_good.stderr
