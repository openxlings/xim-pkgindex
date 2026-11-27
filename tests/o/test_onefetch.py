"""Tests for the onefetch package and real Git repository statistics."""
import json
import os
from pathlib import Path
import platform
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
)
from tests.lib.platform_utils import under_test, xlings_home

PKG = "onefetch"
PKG_FILE = "pkgs/o/onefetch.lua"
VERSION = "3.3.0"
REPO = Path(__file__).resolve().parents[2]
SUPPORTED = (platform.system(), platform.machine().lower()) in {
    ("Linux", "x86_64"), ("Darwin", "arm64"), ("Darwin", "aarch64"),
    ("Windows", "amd64"), ("Windows", "x86_64"),
}
native_only = pytest.mark.skipif(not SUPPORTED, reason="No upstream portable asset for this platform/CPU")


def _run_lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    subprocess.run(
        [lua, "-", PKG_FILE], input=script, text=True, capture_output=True,
        check=True, cwd=REPO,
    )


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert meta.spec == "2"
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)
        assert_valid_xvm_node_kinds(meta)
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_verified_architecture_matrix_and_autoupdate(self, meta):
        assert set(meta.platforms) == {"linux", "macosx", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.xvm_enable and package.programs[1] == "onefetch")
assert(package.ci.mirror)
assert(#package.archs == 2 and package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/o2sh/onefetch/releases")
assert(auto.resources.GLOBAL.required == true and auto.resources.CN == nil)
local expected = {
    linux = { "x86_64", "linux", "664ca61395157d722cd70eb20549d250b36cfcf4a71aae5229bd928b8afd2301" },
    macosx = { "aarch64", "mac", "ce507fcd2ca993c73acc247a0acc831924b55cd8d9e20efca0e2ba7fad962620" },
    windows = { "x86_64", "win", "3b900747d75195fbfdc04cdd6c8f858d72918c67cba178526f26d68ab69f9653" },
}
for plat, e in pairs(expected) do
    local section = package.xpm[plat]
    assert(section.latest.ref == "3.3.0")
    local entries = section["3.3.0"]
    local count = 0
    for arch, resource in pairs(entries) do
        count = count + 1
        assert(arch == e[1], "generic archive must not imply unsupported CPU: " .. plat .. "/" .. arch)
        assert(resource.sha256 == e[3])
        assert(resource.url == "https://github.com/o2sh/onefetch/releases/download/3.3.0/onefetch-" .. e[2] .. ".tar.gz")
        local template = auto.resources.GLOBAL.url[plat][arch]
        assert(template:gsub("%${tag}", "3.3.0") == resource.url)
    end
    assert(count == 1)
    local targets = 0
    for arch in pairs(auto.resources.GLOBAL.url[plat]) do
        targets = targets + 1
        assert(arch == e[1])
    end
    assert(targets == 1)
end
local linux = package.xpm.linux.deps.runtime
assert(#linux == 2 and linux[1] == "xim:glibc@>=2.39" and linux[2] == "xim:gcc-runtime@15.1.0")
assert(package.xpm.windows.deps.runtime[1] == "xim:vcruntime")
assert(package.xpm.macosx.deps == nil)
''')

    @pytest.mark.static
    def test_flat_archives_license_crt_and_routing(self):
        _run_lua(r'''
import = function() end
payload = assert(loadfile("libs/payload.lua"))()
winpath = assert(loadfile("libs/winpath.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])
local real_open = io.open
local files, execs, adds, removes = {}, {}, {}, {}
local archive, dir = "/cache/onefetch-linux.tar.gz", "/pkg/onefetch"
local windows, land_binary, copy_crt = false, true, true
pkginfo = {
    install_file = function() return archive end,
    install_dir = function() return dir end,
    dep_install_dir = function(name) assert(name == "xim:vcruntime"); return "C:/crt" end,
}
os.host = function() return windows and "windows" or "linux" end
os.isfile = function(p) return files[p] == true end
os.tryrm = function() files[dir .. "/onefetch"] = nil; files[dir .. "/onefetch.exe"] = nil end
os.mv = function(src, dst) assert(files[src]); files[src] = nil; files[dst] = true end
os.cp = function(src, dst)
    assert(src == "C:/crt/bin/vcruntime140.dll")
    if copy_crt then files[dst] = true end
end
fs = { mkdir_p = function() end }
system = { exec = function(cmd)
    execs[#execs + 1] = cmd
    if cmd:find("tar", 1, true) and land_binary then
        files[dir .. (windows and "/onefetch.exe" or "/onefetch")] = true
    end
end }
io.open = function(path, mode)
    assert(path == dir .. "/LICENSE.md" and mode == "wb")
    return {
        write = function(_, text)
            assert(text:find("Copyright (c) 2018 Ossama Hjaji", 1, true))
            assert(text:find("THE SOFTWARE IS PROVIDED", 1, true))
            files[path] = true
            return true
        end,
        close = function() return true end,
    }
end
xvm = {
    add = function(name, opts) adds[#adds + 1] = {name, opts} end,
    remove = function(name) removes[#removes + 1] = name end,
}
assert(not installed())
files[archive] = true
assert(install() and installed())
assert(#execs == 2 and execs[1]:find("tar", 1, true) and execs[2]:find("chmod", 1, true))
assert(config() and adds[1][1] == "onefetch" and adds[1][2].bindir == dir)
assert(uninstall() and removes[1] == "onefetch")
-- Engines that retain only a flat extracted executable are supported too.
files, execs = { ["/cache/onefetch"] = true }, {}
assert(install() and installed() and #execs == 1)
-- Neither a successful tar command nor a license alone proves installation.
files, execs, land_binary = { [archive] = true }, {}, false
assert(not pcall(install))
files = {}
assert(not pcall(install))
-- The Windows tarball is also flat; route to system tar and deploy only the
-- actually imported CRT DLL, checking it in installed() as well as install().
windows, land_binary = true, true
archive, dir = "C:/cache/onefetch-win.tar.gz", "C:/pkg/onefetch"
files, execs = { [archive] = true }, {}
assert(install() and installed())
assert(#execs == 1 and execs[1]:find("\\System32\\tar.exe", 1, true))
assert(execs[1]:find("C:\\cache\\onefetch-win.tar.gz", 1, true))
files[dir .. "/vcruntime140.dll"] = nil
assert(not installed())
copy_crt = false
assert(not pcall(install))
io.open = real_open
''')


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_isolation(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_api_boundary(self):
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.system",
            "xim.libxpkg.xvm", "xim.pkgindex.payload", "xim.pkgindex.shell",
            "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @native_only
    def test_install(self):
        assert_install_succeeds(under_test(PKG, os.environ.get("XLINGS_TEST_VERSION", VERSION)))


class TestVerify:
    def _run(self, *args, env=None):
        suffix = ".exe" if os.name == "nt" else ""
        base = Path(xlings_home()) / "subos"
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = base / subos / "bin"
        if not bindir.is_dir():
            bindir = base / "default" / "bin"
        shim = bindir / (PKG + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args], capture_output=True, text=True, encoding="utf-8",
            timeout=30, env=env,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    @pytest.mark.verify
    @native_only
    def test_version(self):
        assert os.environ.get("XLINGS_TEST_VERSION", VERSION) in self._run("--version")

    @pytest.mark.verify
    @native_only
    def test_committed_python_repository_statistics(self, tmp_path):
        repo = tmp_path / "sample-repo"
        repo.mkdir()
        home = tmp_path / "home"
        home.mkdir()
        env = {
            **os.environ, "HOME": str(home), "USERPROFILE": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Package Test Author",
            "GIT_AUTHOR_EMAIL": "package-test@example.invalid",
            "GIT_COMMITTER_NAME": "Package Test Author",
            "GIT_COMMITTER_EMAIL": "package-test@example.invalid",
        }
        def git(*args):
            subprocess.run(["git", "-C", str(repo), *args], check=True,
                           capture_output=True, text=True, env=env, timeout=15)

        git("init", "-q")
        git("config", "user.name", "Package Test Author")
        git("config", "user.email", "package-test@example.invalid")
        (repo / "sample.py").write_text(
            'def greeting():\n    return "hello"\n\nprint(greeting())\n', encoding="utf-8",
        )
        git("add", "sample.py")
        git("-c", "commit.gpgsign=false", "commit", "-qm", "Add sample")
        report = json.loads(self._run("--output", "json", "--no-art", str(repo), env=env))
        fields = {key: value for field in report["infoFields"] for key, value in field.items()}
        assert fields["CommitsInfo"]["numberOfCommits"] == 1
        assert fields["ContributorsInfo"]["totalNumberOfAuthors"] == 1
        assert fields["LocInfo"]["linesOfCode"] == 3
        assert fields["SizeInfo"]["fileCount"] == 1
        assert fields["LanguagesInfo"]["languagesWithPercentage"] == [
            {"language": "Python", "percentage": 100.0},
        ]
        assert fields["AuthorsInfo"]["authors"][0]["name"] == "Package Test Author"
        assert fields["ChurnInfo"]["file_churns"][0]["filePath"] == "sample.py"
