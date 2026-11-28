"""Tests for the agg package (asciinema gif generator)."""
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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "agg"
PKG_FILE = "pkgs/a/agg.lua"
VERSION = "1.9.0"
REPO = Path(__file__).resolve().parents[2]


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    r = subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        cwd=REPO,
    )
    assert r.returncode == 0, f"Lua failed:\n{r.stderr}\n{r.stdout}"
    return r.stdout


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
    def test_platforms_deps_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["agg"]
        assert meta.has_xvm_enable
        assert meta.has_installed
        assert meta.has_install
        assert meta.has_config
        assert meta.has_uninstall

        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.spec == "2", "spec must be 2")
assert(package.name == "agg")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "agg")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/asciinema/agg/releases")
local global_au = assert(au.resources and au.resources.GLOBAL)
assert(global_au.required == true)
local url_map = assert(global_au.url)

local ldeps = assert(package.xpm.linux.deps and package.xpm.linux.deps.runtime)
assert(#ldeps == 2 and ldeps[1]:find("xim:glibc", 1, true) and ldeps[2]:find("xim:gcc-runtime", 1, true))
assert(package.xpm.macosx.deps == nil, "macosx binary should not declare runtime deps")
local wdeps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime", "windows must declare xim:vcruntime")

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}

local seen = {}
local count = 0
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    local ref = assert(p.latest and p.latest.ref, "missing latest ref for " .. plat)
    assert(ref == "''' + VERSION + '''", plat .. " latest should be ''' + VERSION + '''")
    local entry = assert(p[ref], "missing version entry for " .. plat)
    assert(type(p.source) == "string" and p.source:find("${version}", 1, true), plat .. " source missing ${version}")

    local allowed = {}
    for _, arch in ipairs(arches) do
        allowed[arch] = true
        local h = assert(entry.sha256 and entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(not seen[h], "duplicate sha256 across targets")
        seen[h] = true

        local arch_token = (entry.arch_alias and entry.arch_alias[arch]) or arch
        local xpm_resolved = p.source:gsub("%${version}", ref):gsub("%${arch_alias}", arch_token):gsub("%${arch}", arch)
        local tmpl = assert(url_map[plat] and url_map[plat][arch], "missing autoupdate template for " .. plat .. "/" .. arch)
        assert(tmpl:find("${tag}", 1, true), "autoupdate template must use ${tag}: " .. plat .. "/" .. arch)
        local auto_resolved = tmpl:gsub("%${tag}", "v" .. ref):gsub("%${version}", ref)
        assert(auto_resolved == xpm_resolved,
               "installer/updater URLs disagree for " .. plat .. "/" .. arch .. ": " .. auto_resolved .. " vs " .. xpm_resolved)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(allowed[arch], "unexpected arch on " .. plat .. ": " .. arch)
    end
end
assert(count == 5)
assert(package.xpm.linux["''' + VERSION + '''"].arch_alias.x86_64 == "x86_64-unknown-linux-musl")
assert(package.xpm.linux["''' + VERSION + '''"].arch_alias.aarch64 == "aarch64-unknown-linux-gnu")
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_checks_binary(self):
        _run_lua('''
import = function() end
dofile(arg[1])
pkginfo = { install_dir = function() return "/xpkgs/agg/1.9.0" end }
os.isfile = function(p) return p == "/xpkgs/agg/1.9.0/agg.exe" end
assert(installed() == true)
os.isfile = function() return false end
assert(installed() == false)
''', PKG_FILE)

    @pytest.mark.static
    def test_install_moves_binary_and_copies_vcruntime_on_windows(self):
        _run_lua('''
import = function() end
dofile(arg[1])

-- 1. Linux raw binary install
local moved, execs, copied = {}, {}, {}
pkginfo = {
    install_file = function() return "/cache/agg-x86_64-unknown-linux-musl" end,
    install_dir = function() return "/xpkgs/agg/1.9.0" end,
    dep_install_dir = function() return nil end,
}
fs = { mkdir_p = function() end, files = function() return {} end }
os.tryrm = function() end
os.mv = function(s, d) table.insert(moved, {s, d}) end
os.cp = function(s, d) table.insert(copied, {s, d}) end
os.isfile = function(p) return p == "/xpkgs/agg/1.9.0/agg" end
system = { exec = function(cmd) table.insert(execs, cmd) end }

assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/agg-x86_64-unknown-linux-musl" and moved[1][2] == "/xpkgs/agg/1.9.0/agg")
assert(#execs == 1 and execs[1]:find("chmod +x", 1, true))
assert(#copied == 0)

-- 2. Windows raw binary install + xim:vcruntime app-local DLL copy
moved, execs, copied = {}, {}, {}
pkginfo = {
    install_file = function() return "C:\\\\cache\\\\agg-x86_64-pc-windows-msvc.exe" end,
    install_dir = function() return "C:/xpkgs/agg/1.9.0" end,
    dep_install_dir = function(name)
        assert(name == "xim:vcruntime")
        return "C:/xpkgs/xim-x-vcruntime/14.44.35211"
    end,
}
fs = {
    mkdir_p = function() end,
    files = function(dir)
        assert(dir == "C:/xpkgs/xim-x-vcruntime/14.44.35211/bin")
        return { "C:/xpkgs/xim-x-vcruntime/14.44.35211/bin/vcruntime140.dll" }
    end,
}
os.isfile = function(p) return p == "C:/xpkgs/agg/1.9.0/agg.exe" end

assert(install())
assert(#moved == 1 and moved[1][2] == "C:/xpkgs/agg/1.9.0/agg.exe")
assert(#execs == 0)
assert(#copied == 1 and copied[1][2] == "C:/xpkgs/agg/1.9.0")
''', PKG_FILE)

    @pytest.mark.static
    def test_config_and_uninstall(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local adds, rms = {}, {}
pkginfo = { install_dir = function() return "/pkg" end }
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(config())
assert(#adds == 1 and adds[1][1] == "agg" and adds[1][2].bindir == "/pkg")

assert(uninstall())
assert(#rms == 1 and rms[1] == "agg")
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
        assert_command_output("agg --version", contains=f"agg {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists(PKG)
