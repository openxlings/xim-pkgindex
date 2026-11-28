"""Tests for the procs package (modern replacement for ps)."""
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

PKG = "procs"
PKG_FILE = "pkgs/p/procs.lua"
VERSION = "0.14.12"
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
        assert meta.programs == ["procs"]
        assert meta.has_xvm_enable
        assert meta.has_installed
        assert meta.has_install
        assert meta.has_config
        assert meta.has_uninstall

        _run_lua('''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "procs")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/dalance/procs/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)

local expected = {
    linux = { "x86_64", "aarch64" },
    macosx = { "x86_64", "aarch64" },
    windows = { "x86_64" },
}

local seen = {}
local count = 0
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    if plat == "windows" then
        assert(p.deps and p.deps.runtime and #p.deps.runtime == 1 and p.deps.runtime[1] == "xim:vcruntime",
               "windows must declare xim:vcruntime runtime dep")
    else
        assert(not p.deps, plat .. " static/Mach-O binary should not declare runtime deps")
    end

    local ver = assert(p.latest and p.latest.ref, "missing latest ref: " .. plat)
    assert(ver == "0.14.12")
    local entry = assert(p[ver], "missing version entry: " .. plat)
    assert(type(p.source) == "string" and p.source:find("${version}", 1, true) and p.source:find("${arch}", 1, true),
           plat .. " source must template ${version} and ${arch}")

    local allowed = {}
    for _, arch in ipairs(arches) do
        allowed[arch] = true
        local sha = assert(entry.sha256 and entry.sha256[arch], "missing sha256: " .. plat .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), "invalid sha256: " .. plat .. "/" .. arch)
        assert(not seen[sha], "duplicate sha256 across targets")
        seen[sha] = true

        local auto = assert(au.resources.GLOBAL.url[plat][arch], "missing autoupdate url: " .. plat .. "/" .. arch)
        assert(auto:find("${tag}", 1, true), "autoupdate template must use ${tag}: " .. plat .. "/" .. arch)
        local auto_resolved = auto:gsub("%${tag}", "v" .. ver):gsub("%${version}", ver)
        local xpm_resolved = p.source:gsub("%${version}", ver):gsub("%${arch}", arch)
        assert(auto_resolved == xpm_resolved,
               "installer/updater URLs disagree for " .. plat .. "/" .. arch .. ": " .. auto_resolved .. " vs " .. xpm_resolved)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(allowed[arch], "unexpected arch on " .. plat .. ": " .. arch)
    end
end
assert(count == 5)
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_install_config_uninstall_posix_and_windows(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: POSIX install with pre-extracted flat .zip beside archive
local files, dirs, mvs, execs, adds, rms, cps = {}, {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "procs" end,
    version = function() return "0.14.12" end,
    install_file = function() return "/cache/procs-v0.14.12-x86_64-linux.zip" end,
    install_dir = function() return "/xpkgs/procs/0.14.12" end,
    dep_install_dir = function() return nil end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k == p or k:sub(1, #p + 1) == p .. "/" then
            files[k] = nil
        end
    end
end
os.mv = function(src, dst)
    table.insert(mvs, {src, dst})
    files[src] = nil
    files[dst] = true
end
os.cp = function(src, dst_dir)
    table.insert(cps, {src, dst_dir})
    local base = src:match("([^/]+)$")
    files[dst_dir .. "/" .. base] = true
end
fs = {
    mkdir_p = function(p) dirs[p] = true end,
    files = function() return {} end,
}
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
files["/cache/procs"] = true
assert(install())
assert(installed())
assert(#mvs == 1 and mvs[1][1] == "/cache/procs" and mvs[1][2] == "/xpkgs/procs/0.14.12/procs")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/procs/0.14.12/procs"')
assert(config())
assert(#adds == 1 and adds[1][1] == "procs" and adds[1][2].bindir == "/xpkgs/procs/0.14.12")
assert(uninstall())
assert(#rms == 1 and rms[1] == "procs")

-- Case 2: POSIX install fallback when .zip is not pre-extracted (unzip -q -o)
files, dirs, mvs, execs = {}, {}, {}, {}
files["/cache/procs-v0.14.12-x86_64-linux.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^unzip ") then
            files["/xpkgs/procs/0.14.12/procs"] = true
        end
    end,
}
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'unzip -q -o "/cache/procs-v0.14.12-x86_64-linux.zip" -d "/xpkgs/procs/0.14.12"')
assert(execs[2] == 'chmod +x "/xpkgs/procs/0.14.12/procs"')

-- Case 3: Windows install via libs/payload.lua + xim:vcruntime DLL copy
files, dirs, mvs, execs, adds, rms, cps = {}, {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "procs" end,
    version = function() return "0.14.12" end,
    install_file = function() return "C:/cache/procs-v0.14.12-x86_64-windows.zip" end,
    install_dir = function() return "C:/xpkgs/procs/0.14.12" end,
    dep_install_dir = function(dep)
        assert(dep == "xim:vcruntime")
        return "C:/xpkgs/vcruntime/latest"
    end,
}
files["C:/cache/procs-v0.14.12-x86_64-windows.zip"] = true
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
fs.files = function(d)
    assert(d == "C:/xpkgs/vcruntime/latest/bin")
    return { "C:/xpkgs/vcruntime/latest/bin/vcruntime140.dll" }
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/procs/0.14.12/procs.exe"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\procs-v0.14.12-x86_64-windows.zip" -C "C:\\\\xpkgs\\\\procs\\\\0.14.12"')
assert(#cps == 1 and cps[1][1] == "C:/xpkgs/vcruntime/latest/bin/vcruntime140.dll" and cps[1][2] == "C:/xpkgs/procs/0.14.12")
assert(files["C:/xpkgs/procs/0.14.12/vcruntime140.dll"])
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
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_procs_version(self):
        assert_command_output("procs --version", contains=VERSION)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_procs_lists_processes(self):
        assert_command_output("procs --pager disable --no-header", contains="1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists(PKG)
