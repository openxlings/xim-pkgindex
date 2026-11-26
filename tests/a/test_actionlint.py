"""Tests for the actionlint package."""
import os
from pathlib import Path
import re
import shutil
import subprocess

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
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "actionlint"
PKG_FILE = "pkgs/a/actionlint.lua"
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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self):
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "actionlint")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/rhysd/actionlint/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == "1.7.12", platform .. " latest should be 1.7.12")
    local tag = "v" .. version
    local entry = assert(p[version], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), platform .. "/" .. arch)
        local auto = au.resources.GLOBAL.url[platform][arch]
        local resolved_auto = auto:gsub("%${tag}", tag):gsub("%${version}", version)
        local resolved_xpm = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(resolved_auto == resolved_xpm, "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_install_config_uninstall_posix_and_windows(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- POSIX install: extract flat .tar.gz directly into install_dir + chmod +x
local files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "actionlint" end,
    version = function() return "1.7.12" end,
    install_file = function() return "/cache/actionlint_1.7.12_linux_amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/actionlint/1.7.12" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(mvs, {src, dst})
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^tar %-xzf") then
            files["/xpkgs/actionlint/1.7.12/actionlint"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
files["/cache/actionlint_1.7.12_linux_amd64.tar.gz"] = true
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/actionlint_1.7.12_linux_amd64.tar.gz" -C "/xpkgs/actionlint/1.7.12"')
assert(execs[2] == 'chmod +x "/xpkgs/actionlint/1.7.12/actionlint"')
assert(config())
assert(#adds == 1 and adds[1][1] == "actionlint" and adds[1][2].bindir == "/xpkgs/actionlint/1.7.12")
assert(uninstall())
assert(#rms == 1 and rms[1] == "actionlint")

-- POSIX fallback when archive was pre-extracted and removed
files, dirs, mvs, execs = {}, {}, {}, {}
files["/cache/actionlint"] = true
assert(install())
assert(#mvs == 1 and mvs[1][1] == "/cache/actionlint" and mvs[1][2] == "/xpkgs/actionlint/1.7.12/actionlint")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/actionlint/1.7.12/actionlint"')

-- Windows install via libs/payload.lua (.zip -> System32\\tar.exe)
files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "actionlint" end,
    version = function() return "1.7.12" end,
    install_file = function() return "C:/cache/actionlint_1.7.12_windows_amd64.zip" end,
    install_dir = function() return "C:/xpkgs/actionlint/1.7.12" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
files["C:/cache/actionlint_1.7.12_windows_amd64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/actionlint/1.7.12/actionlint.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\actionlint_1.7.12_windows_amd64.zip" -C "C:\\\\xpkgs\\\\actionlint\\\\1.7.12"')

-- Missing archive and extracted binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
''', PKG_FILE)


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
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "1.7.12")
        assert_command_output("actionlint -version", contains=expected)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_lints_minimal_workflow(self, tmp_path):
        wf_dir = tmp_path / ".github" / "workflows"
        wf_dir.mkdir(parents=True)
        valid_yml = wf_dir / "valid.yml"
        valid_yml.write_text(
            "name: CI\n"
            "on: [push]\n"
            "jobs:\n"
            "  build:\n"
            "    runs-on: ubuntu-latest\n"
            "    steps:\n"
            "      - uses: actions/checkout@v4\n"
            "      - run: echo ok\n",
            encoding="utf-8",
        )
        ok_res = subprocess.run(
            ["actionlint", str(valid_yml)],
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert ok_res.returncode == 0, ok_res.stdout + ok_res.stderr

        bad_yml = wf_dir / "bad.yml"
        bad_yml.write_text(
            "name: Bad\n"
            "on: [push]\n"
            "jobs:\n"
            "  build:\n"
            "    runs-on: ubuntu-latest\n"
            "    steps:\n"
            "      - run: echo ${{ github.nonexistent_field }}\n",
            encoding="utf-8",
        )
        bad_res = subprocess.run(
            ["actionlint", str(bad_yml)],
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert bad_res.returncode != 0, "expected actionlint to reject invalid expression"
        assert "nonexistent_field" in bad_res.stdout + bad_res.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("actionlint")
