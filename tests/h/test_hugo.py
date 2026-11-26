"""Tests for the hugo package."""
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

PKG = "hugo"
PKG_FILE = "pkgs/h/hugo.lua"
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
assert(package.programs and #package.programs == 1 and package.programs[1] == "hugo")

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "", aarch64 = "" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == "0.170.1", platform .. " latest should be 0.170.1")
    local entry = assert(p[version], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        if alias ~= "" then
            assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        end
        local sha = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), platform .. "/" .. arch)
        local auto = package.extensions.autoupdate.resources.GLOBAL.url[platform][arch]
        local resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        local expanded_auto = auto:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        assert(expanded_auto == resolved, "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
assert(package.xpm.macosx["0.170.1"].sha256.x86_64 == package.xpm.macosx["0.170.1"].sha256.aarch64)
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_install_config_uninstall_linux_macos_and_windows(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: Linux install (extract flat .tar.gz directly into install_dir + chmod +x)
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "hugo" end,
    version = function() return "0.170.1" end,
    install_file = function() return "/cache/hugo_0.170.1_linux-amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/hugo/0.170.1" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k == p or k:sub(1, #p + 1) == p .. "/" then files[k] = nil end
    end
end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^tar %-xzf") then
            files["/xpkgs/hugo/0.170.1/hugo"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
files["/cache/hugo_0.170.1_linux-amd64.tar.gz"] = true
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/hugo_0.170.1_linux-amd64.tar.gz" -C "/xpkgs/hugo/0.170.1"')
assert(execs[2] == 'chmod +x "/xpkgs/hugo/0.170.1/hugo"')
assert(config())
assert(#adds == 1 and adds[1][1] == "hugo" and adds[1][2].bindir == "/xpkgs/hugo/0.170.1" and adds[1][2].alias == nil)
assert(uninstall())
assert(#rms == 1 and rms[1] == "hugo")

-- Case 2: macOS install (pkgutil --expand-full darwin-universal.pkg -> Payload/hugo)
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "hugo" end,
    version = function() return "0.170.1" end,
    install_file = function() return "/cache/hugo_0.170.1_darwin-universal.pkg" end,
    install_dir = function() return "/xpkgs/hugo/0.170.1" end,
}
os.host = function() return "macosx" end
files["/cache/hugo_0.170.1_darwin-universal.pkg"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^pkgutil %-%-expand%-full") then
            files["/xpkgs/hugo/0.170.1/._pkg/Payload/hugo"] = true
        end
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(files["/xpkgs/hugo/0.170.1/hugo"])
assert(not files["/xpkgs/hugo/0.170.1/._pkg/Payload/hugo"])
assert(#execs == 2)
assert(execs[1] == 'pkgutil --expand-full "/cache/hugo_0.170.1_darwin-universal.pkg" "/xpkgs/hugo/0.170.1/._pkg"')
assert(execs[2] == 'chmod +x "/xpkgs/hugo/0.170.1/hugo"')
assert(config())
assert(#adds == 1 and adds[1][1] == "hugo" and adds[1][2].bindir == "/xpkgs/hugo/0.170.1" and adds[1][2].alias == nil)

-- Case 3: Windows install via libs/payload.lua (.zip -> System32\\tar.exe) + alias = hugo.exe
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "hugo" end,
    version = function() return "0.170.1" end,
    install_file = function() return "C:/cache/hugo_0.170.1_windows-amd64.zip" end,
    install_dir = function() return "C:/xpkgs/hugo/0.170.1" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
files["C:/cache/hugo_0.170.1_windows-amd64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/hugo/0.170.1/hugo.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\hugo_0.170.1_windows-amd64.zip" -C "C:\\\\xpkgs\\\\hugo\\\\0.170.1"')
assert(config())
assert(#adds == 1 and adds[1][1] == "hugo" and adds[1][2].bindir == "C:/xpkgs/hugo/0.170.1" and adds[1][2].alias == "hugo.exe")

-- Case 4: Missing archive and extracted binary must fail
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
    def test_hugo_version(self):
        assert_command_output("hugo version", contains="v0.170.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_hugo_new_site(self, tmp_path):
        site_dir = tmp_path / "site"
        assert_command_output(f'hugo new site "{site_dir}"', contains="Congratulations!")
        assert (site_dir / "hugo.toml").is_file()

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("hugo")
