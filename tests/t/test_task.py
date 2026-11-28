"""Tests for the task package (go-task/task)."""
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
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "task"
PKG_FILE = "pkgs/t/task.lua"
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
    def test_all_platforms_arches_and_autoupdate_pinned(self):
        _run_lua(
            '''
import = function() end
dofile(arg[1])

assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "task")

local auto = assert(package.extensions and package.extensions.autoupdate, "missing autoupdate")
assert(auto.source == "https://github.com/go-task/task/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local expected = {
    linux   = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx  = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
local count = 0
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing xpm." .. plat)
    local ver = assert(p.latest and p.latest.ref, "missing latest.ref in " .. plat)
    assert(ver == "3.54.0")
    local entry = assert(p[ver], "missing version entry in " .. plat)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, plat .. "/" .. arch)
        local h = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local resolved_xpm = p.source:gsub("%${version}", ver):gsub("%${arch_alias}", alias)
        local resolved_auto = assert(global_url[plat] and global_url[plat][arch]):gsub("%${tag}", "v" .. ver)
        assert(resolved_xpm == resolved_auto, "xpm and autoupdate URLs disagree for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_posix_and_windows_in_lua_sandbox(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
dofile(arg[1])

-- 1. POSIX archive extraction + chmod + config + uninstall
local files, dirs, execs, mvs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    install_file = function() return "/cache/task_linux_amd64.tar.gz" end,
    install_dir  = function() return "/xpkgs/task/3.54.0" end,
}
files["/cache/task_linux_amd64.tar.gz"] = true
os.isfile = function(p) return files[p] == true end
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
            files["/xpkgs/task/3.54.0/task"] = true
            files["/xpkgs/task/3.54.0/LICENSE"] = true
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
assert(execs[1] == 'tar -xzf "/cache/task_linux_amd64.tar.gz" -C "/xpkgs/task/3.54.0"')
assert(execs[2] == 'chmod +x "/xpkgs/task/3.54.0/task"')
assert(config())
assert(#adds == 1 and adds[1][1] == "task" and adds[1][2].bindir == "/xpkgs/task/3.54.0")
assert(uninstall())
assert(#rms == 1 and rms[1] == "task")

-- 2. Windows zip extraction via System32\\tar.exe
files, dirs, execs, mvs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    install_file = function() return "C:/cache/task_windows_amd64.zip" end,
    install_dir  = function() return "C:/xpkgs/task/3.54.0" end,
}
files["C:/cache/task_windows_amd64.zip"] = true
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/task/3.54.0/task.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\task_windows_amd64.zip" -C "C:\\\\xpkgs\\\\task\\\\3.54.0"')

-- 3. Pre-extracted fallback without archive file
files, dirs, execs, mvs = {}, {}, {}, {}
pkginfo = {
    install_file = function() return "/cache/task_linux_amd64.tar.gz" end,
    install_dir  = function() return "/xpkgs/task/3.54.0" end,
}
files["/cache/task"] = true
files["/cache/LICENSE"] = true
assert(install())
assert(installed())
assert(#mvs == 2)
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/task/3.54.0/task"')

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
            "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    def _task_bin(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("task" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return str(shim)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "3.54.0")
        assert_command_output("task --version", contains=expected)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("task")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_run_taskfile(self):
        task_bin = self._task_bin()
        with tempfile.TemporaryDirectory() as work:
            taskfile = Path(work) / "Taskfile.yml"
            taskfile.write_text(
                "version: '3'\n"
                "tasks:\n"
                "  hello:\n"
                "    silent: true\n"
                "    cmds:\n"
                "      - echo hello-from-task\n",
                encoding="utf-8",
            )
            proc = subprocess.run(
                [task_bin, "--dir", work, "hello"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                check=True,
                timeout=30,
            )
            assert "hello-from-task" in proc.stdout, proc.stdout + proc.stderr
