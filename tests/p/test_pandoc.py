"""Tests for the pandoc package."""
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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "pandoc"
PKG_FILE = "pkgs/p/pandoc.lua"
VERSION = "3.14"
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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_platforms_arches_checksums_and_autoupdate(self):
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "pandoc")

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == "3.14")
    local entry = assert(p[version], "missing version entry: " .. platform)
    local tag = version
    for _, arch in ipairs(arches) do
        local sha = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), platform .. "/" .. arch)
        local alias = (entry.arch_alias and entry.arch_alias[arch]) or arch
        local resolved = p.source
            :gsub("%${version}", version)
            :gsub("%${arch_alias}", alias)
            :gsub("%${arch}", arch)
        local auto = assert(package.extensions.autoupdate.resources.GLOBAL.url[platform][arch],
                            "missing autoupdate url: " .. platform .. "/" .. arch)
        local expanded_auto = auto:gsub("%${tag}", tag):gsub("%${version}", version)
        assert(expanded_auto == resolved, "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        count = count + 1
    end
end
assert(count == 5)
''', PKG_FILE)

    @pytest.mark.static
    def test_hooks_posix_and_windows(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Linux install: pandoc-3.14/ extracted beside .tar.gz
local files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "pandoc" end,
    version = function() return "3.14" end,
    install_file = function() return "/cache/pandoc-3.14-linux-amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/pandoc/3.14" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(mvs, {src, dst})
    if dirs[src] then
        dirs[src] = nil
        dirs[dst] = true
    end
    if files[src .. "/bin/pandoc"] then
        files[src .. "/bin/pandoc"] = nil
        files[dst .. "/bin/pandoc"] = true
    end
    if files[src .. "/pandoc.exe"] then
        files[src .. "/pandoc.exe"] = nil
        files[dst .. "/pandoc.exe"] = true
    end
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd) table.insert(execs, cmd) end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
dirs["/cache/pandoc-3.14"] = true
files["/cache/pandoc-3.14/bin/pandoc"] = true
assert(install())
assert(installed())
assert(#mvs == 1 and mvs[1][1] == "/cache/pandoc-3.14" and mvs[1][2] == "/xpkgs/pandoc/3.14")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/pandoc/3.14/bin/pandoc"')
assert(config())
assert(#adds == 1 and adds[1][1] == "pandoc" and adds[1][2].bindir == "/xpkgs/pandoc/3.14/bin")
assert(uninstall())
assert(#rms == 1 and rms[1] == "pandoc")

-- macOS arm64 install: pandoc-3.14-arm64/ extracted beside .zip
files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "pandoc" end,
    version = function() return "3.14" end,
    install_file = function() return "/cache/pandoc-3.14-arm64-macOS.zip" end,
    install_dir = function() return "/xpkgs/pandoc/3.14" end,
}
os.host = function() return "macosx" end
dirs["/cache/pandoc-3.14-arm64"] = true
files["/cache/pandoc-3.14-arm64/bin/pandoc"] = true
assert(install())
assert(installed())
assert(#mvs == 1 and mvs[1][1] == "/cache/pandoc-3.14-arm64" and mvs[1][2] == "/xpkgs/pandoc/3.14")
assert(config())
assert(#adds == 1 and adds[1][1] == "pandoc" and adds[1][2].bindir == "/xpkgs/pandoc/3.14/bin")

-- Windows install via libs/payload.lua (.zip -> System32\\tar.exe with --strip-components=1)
files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "pandoc" end,
    version = function() return "3.14" end,
    install_file = function() return "C:/cache/pandoc-3.14-windows-x86_64.zip" end,
    install_dir = function() return "C:/xpkgs/pandoc/3.14" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/pandoc/3.14/pandoc.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\pandoc-3.14-windows-x86_64.zip" --strip-components=1 -C "C:\\\\xpkgs\\\\pandoc\\\\3.14"')
assert(config())
assert(#adds == 1 and adds[1][1] == "pandoc" and adds[1][2].bindir == "C:/xpkgs/pandoc/3.14" and adds[1][2].alias == "pandoc.exe")
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
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


@skip_if_not("linux")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=300)


@skip_if_not("linux")
class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        assert_command_output("pandoc --version", contains=f"pandoc {VERSION}")

    @pytest.mark.verify
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_xvm_shim_exists(self):
        assert_xvm_shim_exists(PKG)

    @pytest.mark.verify
    def test_converts_markdown_to_html(self):
        proc = subprocess.run(
            ["bash", "-l", "-c", "pandoc -f markdown -t html"],
            input="# Hello\n\n*one* **two**\n",
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert '<h1 id="hello">Hello</h1>' in proc.stdout
        assert "<p><em>one</em> <strong>two</strong></p>" in proc.stdout
