"""Tests for the lefthook package."""
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

PKG = "lefthook"
PKG_FILE = "pkgs/l/lefthook.lua"
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
    def test_platforms_arches_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "lefthook")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/evilmartians/lefthook/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "x86_64", aarch64 = "arm64" },
    macosx = { x86_64 = "x86_64", aarch64 = "arm64" },
    windows = { x86_64 = "x86_64", aarch64 = "arm64" },
}

for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "2.2.3")
    local ver = assert(section["2.2.3"], "missing 2.2.3 in " .. plat)
    for arch, alias in pairs(arches) do
        assert(ver.arch_alias[arch] == alias, plat .. "/" .. arch .. " alias mismatch")
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        local resolved_au = tmpl:gsub("%${tag}", "v2.2.3"):gsub("%${version}", "2.2.3")
        local resolved_xpm = section.source:gsub("%${version}", "2.2.3"):gsub("%${arch_alias}", alias)
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
    def test_hooks_posix_gz_and_windows_exe(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- 1. POSIX .gz binary decompressed into install_dir/lefthook + chmod +x
local files, dirs, execs, moved, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "lefthook" end,
    version = function() return "2.2.3" end,
    install_file = function() return "/cache/lefthook_2.2.3_Linux_x86_64.gz" end,
    install_dir = function() return "/xpkgs/lefthook/2.2.3" end,
}
files["/cache/lefthook_2.2.3_Linux_x86_64.gz"] = true
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
            files["/xpkgs/lefthook/2.2.3/lefthook"] = true
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
assert(execs[1]:find('"/cache/lefthook_2.2.3_Linux_x86_64.gz"', 1, true))
assert(execs[1]:find('"/xpkgs/lefthook/2.2.3/lefthook"', 1, true))
assert(execs[2] == 'chmod +x "/xpkgs/lefthook/2.2.3/lefthook"')
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "lefthook" and adds[1][2].bindir == "/xpkgs/lefthook/2.2.3")
assert(uninstall())
assert(#rms == 1 and rms[1] == "lefthook")

-- 2. POSIX pre-decompressed binary beside .gz fallback
files, dirs, execs, moved = {}, {}, {}, {}
files["/cache/lefthook_2.2.3_Linux_x86_64"] = true
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/lefthook_2.2.3_Linux_x86_64"
       and moved[1][2] == "/xpkgs/lefthook/2.2.3/lefthook")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/lefthook/2.2.3/lefthook"')
assert(installed())

-- 3. Windows raw .exe moved directly into install_dir/lefthook.exe
files, dirs, execs, moved, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "lefthook" end,
    version = function() return "2.2.3" end,
    install_file = function() return "C:/cache/lefthook_2.2.3_Windows_x86_64.exe" end,
    install_dir = function() return "C:/xpkgs/lefthook/2.2.3" end,
}
files["C:/cache/lefthook_2.2.3_Windows_x86_64.exe"] = true
assert(not installed())
assert(install())
assert(#execs == 0)
assert(#moved == 1 and moved[1][1] == "C:/cache/lefthook_2.2.3_Windows_x86_64.exe"
       and moved[1][2] == "C:/xpkgs/lefthook/2.2.3/lefthook.exe")
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "lefthook" and adds[1][2].bindir == "C:/xpkgs/lefthook/2.2.3")
assert(uninstall())
assert(#rms == 1 and rms[1] == "lefthook")

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
    def _run_lefthook(self, *args, cwd=None, check_rc=0):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("lefthook" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
            cwd=cwd,
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
        _, out = self._run_lefthook("version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "2.2.3")
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("lefthook")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_validate_and_run_offline(self):
        with tempfile.TemporaryDirectory() as work:
            repo = Path(work)
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            (repo / "lefthook.yml").write_text(
                "pre-commit:\n"
                "  commands:\n"
                "    greet:\n"
                "      run: echo lefthook-verify-ok\n",
                encoding="utf-8",
            )
            subprocess.run(["git", "add", "lefthook.yml"], cwd=repo, check=True)
            _, out_val = self._run_lefthook("validate", cwd=repo)
            assert "All good" in out_val, out_val

            _, out_dump = self._run_lefthook("dump", cwd=repo)
            assert "greet" in out_dump, out_dump

            self._run_lefthook("install", cwd=repo)
            self._run_lefthook("check-install", cwd=repo)
            _, out_run = self._run_lefthook("run", "pre-commit", "--all-files", cwd=repo)
            assert "lefthook-verify-ok" in out_run, out_run
