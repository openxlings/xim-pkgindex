"""Tests for the gitui package."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
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
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "gitui"
PKG_FILE = "pkgs/g/gitui.lua"
VERSION = "0.28.1"
REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=True,
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
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_platforms_archs_deps_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["gitui"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])

assert(package.spec == "2")
assert(package.name == "gitui")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "gitui")

local au = assert(package.extensions and package.extensions.autoupdate)
assert(au.source == "https://github.com/gitui-org/gitui/releases")
local global_url = assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.url)

local ldeps = assert(package.xpm.linux.deps and package.xpm.linux.deps.runtime)
assert(#ldeps == 2 and ldeps[1] == "xim:glibc@>=2.39" and ldeps[2] == "xim:gcc-runtime")
local wdeps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime")
assert(not package.xpm.macosx.deps)

local expected = {
    linux = {
        x86_64 = "gitui-linux-x86_64.tar.gz",
        aarch64 = "gitui-linux-aarch64.tar.gz",
    },
    macosx = {
        x86_64 = "gitui-mac-x86.tar.gz",
        aarch64 = "gitui-mac.tar.gz",
    },
    windows = {
        x86_64 = "gitui-win.tar.gz",
    },
}

local sha_seen = {}
local total = 0
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(p.latest and p.latest.ref == "''' + VERSION + '''")
    local ver = assert(p["''' + VERSION + '''"])
    for arch, asset in pairs(arches) do
        local h = assert(ver.sha256 and ver.sha256[arch], "missing sha256: " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256: " .. plat .. "/" .. arch)
        assert(not sha_seen[h], "duplicate sha256: " .. h)
        sha_seen[h] = true
        local alias = ver.arch_alias and ver.arch_alias[arch] or arch
        local xpm_url = p.source:gsub("%${version}", "''' + VERSION + '''")
                                :gsub("%${arch_alias}", alias)
                                :gsub("%${arch}", arch)
        local expected_url = "https://github.com/gitui-org/gitui/releases/download/v''' + VERSION + '''/" .. asset
        assert(xpm_url == expected_url, plat .. "/" .. arch .. " xpm url mismatch: " .. xpm_url)
        local au_tmpl = assert(global_url[plat] and global_url[plat][arch])
        assert(au_tmpl:gsub("%${tag}", "v''' + VERSION + '''") == expected_url,
               plat .. "/" .. arch .. " autoupdate url mismatch")
        total = total + 1
    end
    for arch in pairs(ver.sha256) do
        assert(arches[arch], "unexpected arch in " .. plat .. ": " .. arch)
    end
end
assert(total == 5)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_posix_and_windows_in_lua_sandbox(self):
        _run_lua(
            '''
local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local cur_file, cur_dir = "", ""
local cur_crt = "C:\\\\store\\\\xpkgs\\\\xim-x-vcruntime\\\\14.44.35211"

local mods = {
    ["xim.libxpkg.fs"] = function()
        fs = {
            mkdir_p = function(p) dirs[p] = true end,
            files = function(d)
                local out = {}
                for p in pairs(files) do
                    if p:sub(1, #d + 1) == d .. "/" then
                        table.insert(out, p)
                    end
                end
                table.sort(out)
                return out
            end,
        }
    end,
    ["xim.libxpkg.pkginfo"] = function()
        pkginfo = {
            name = function() return "gitui" end,
            install_file = function() return cur_file end,
            install_dir = function() return cur_dir end,
            dep_install_dir = function(dep)
                if dep == "xim:vcruntime" then return cur_crt end
                return nil
            end,
        }
    end,
    ["xim.libxpkg.system"] = function()
        system = {
            exec = function(cmd)
                table.insert(execs, cmd)
                if cmd:find("System32\\\\tar%.exe", 1, false) then
                    files[cur_dir .. "/gitui.exe"] = true
                elseif cmd:find("^tar %-xzf") then
                    files[cur_dir .. "/gitui"] = true
                end
            end,
        }
    end,
    ["xim.libxpkg.log"] = function()
        log = { info = function() end, warn = function() end, error = function() end }
    end,
    ["xim.libxpkg.xvm"] = function()
        xvm = {
            add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
            remove = function(name) table.insert(xvm_rms, name) end,
        }
    end,
}

function import(name)
    if name == "xim.pkgindex.payload" then
        if not payload then payload = assert(loadfile("libs/payload.lua"))() end
        return
    elseif name == "xim.pkgindex.winpath" then
        if not winpath then winpath = assert(loadfile("libs/winpath.lua"))() end
        return
    end
    assert(mods[name], "unexpected import: " .. name)()
end

os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(d)
    dirs[d] = nil
    for k in pairs(files) do
        if k:sub(1, #d) == d then files[k] = nil end
    end
end
os.mv = function(src, dst)
    assert(files[src], "missing src: " .. src)
    files[src] = nil
    files[dst] = true
end
os.cp = function(src, dst_dir)
    assert(files[src], "missing cp src: " .. src)
    local base = src:match("([^/\\\\]+)$")
    files[dst_dir .. "/" .. base] = true
end

assert(loadfile(arg[1]))()

-- 1. POSIX archive extraction + chmod +x
cur_file = "/cache/gitui-linux-x86_64.tar.gz"
cur_dir = "/xpkgs/xim-x-gitui/0.28.1"
files[cur_file] = true
assert(not installed())
assert(install())
assert(files[cur_dir .. "/gitui"])
assert(#execs == 2 and execs[1]:find("^tar %-xzf") and execs[2]:find("chmod %+x"))
assert(installed())

-- 2. POSIX pre-extracted fallback
files, dirs, execs = {}, {}, {}
files["/cache/gitui"] = true
assert(install())
assert(files[cur_dir .. "/gitui"])
assert(#execs == 1 and execs[1]:find("chmod %+x"))

-- 3. Windows .tar.gz via System32\\tar.exe + app-local vcruntime DLLs
files, dirs, execs = {}, {}, {}
cur_file = "C:\\\\cache\\\\gitui-win.tar.gz"
cur_dir = "C:\\\\xpkgs\\\\xim-x-gitui\\\\0.28.1"
files[cur_file] = true
files[cur_crt .. "/bin/vcruntime140.dll"] = true
files[cur_crt .. "/bin/msvcp140.dll"] = true
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or (k == "OS" and "Windows_NT" or nil) end
assert(not installed())
assert(install())
assert(files[cur_dir .. "/gitui.exe"])
assert(files[cur_dir .. "/vcruntime140.dll"])
assert(files[cur_dir .. "/msvcp140.dll"])
assert(#execs == 1 and execs[1]:find("System32\\\\tar%.exe", 1, false))
assert(installed())

-- 4. Missing both archive and pre-extracted binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor pre-extracted binary exists")

-- 5. config & uninstall
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "gitui" and xvm_adds[1][2].bindir == cur_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "gitui")
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
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
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
        assert_install_succeeds(under_test(PKG, VERSION), timeout=300)


class TestVerify:
    def _shim_path(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / "default" / "bin"
        shim = bindir / f"gitui{suffix}"
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version_and_help(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        shim = str(self._shim_path())
        res = subprocess.run(
            [shim, "--version"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert res.returncode == 0, res.stdout + res.stderr
        assert f"gitui {expected}" in res.stdout, res.stdout

        help_res = subprocess.run(
            [shim, "--help"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert help_res.returncode == 0, help_res.stdout + help_res.stderr
        assert "Usage: gitui" in help_res.stdout, help_res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            cur_json = Path(xlings_home()) / "subos" / "current" / ".xlings.json"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if cur_json.is_file() else "default")
        assert_xvm_registered("gitui")
