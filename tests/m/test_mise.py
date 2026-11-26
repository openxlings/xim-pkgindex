"""Tests for the mise package."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "mise"
PKG_FILE = "pkgs/m/mise.lua"
VERSION = "2026.11.14"
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
    def test_platforms_arches_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["mise"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "mise")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "mise")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/jdx/mise/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local count = 0
for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(not section.deps, plat .. " should not declare runtime deps for static binaries")
    assert(type(section.source) == "string" and section.source:find("${version}", 1, true))
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    assert(ver.arch_alias and ver.arch_alias.x86_64 == "x64" and ver.arch_alias.aarch64 == "arm64")
    assert(ver.sha256, "missing sha256 table in " .. plat)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        assert(tpl:find("${tag}", 1, true), "missing ${tag} in " .. tpl)
        local auto_resolved = tpl:gsub("%${tag}", "v''' + VERSION + '''")
        local xpm_resolved = section.source
            :gsub("%${version}", "''' + VERSION + '''")
            :gsub("%${arch_alias}", ver.arch_alias[arch])
        assert(auto_resolved == xpm_resolved, "xpm and autoupdate URLs disagree for " .. plat .. "/" .. arch)
        count = count + 1
    end
end
assert(count == 6)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_all_six_sha256_unique(self, meta):
        sha_matches = re.findall(r'(?:x86_64|aarch64)\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(sha_matches) == 6
        assert len(set(sha_matches)) == 6

    @pytest.mark.static
    @pytest.mark.skipif(shutil.which("luac") is None, reason="no luac on this machine")
    def test_lua_syntax(self):
        r = subprocess.run(["luac", "-p", str(REPO / PKG_FILE)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr

    @pytest.mark.static
    def test_hooks_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- POSIX install via pre-extracted `mise/` directory
local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
dirs["/cache/mise"] = true

pkginfo = {
    name = function() return "mise" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "/cache/mise-v''' + VERSION + '''-linux-x64-musl.tar.gz" end,
    install_dir = function() return "/xpkgs/mise/''' + VERSION + '''" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/bin/mise"] = true
    files[dst .. "/LICENSE"] = true
end
log = { info = function() end }
fs = { mkdir_p = function(p) dirs[p] = true end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/mise" and moved[1][2] == "/xpkgs/mise/''' + VERSION + '''")
assert(installed())

files["/xpkgs/mise/''' + VERSION + '''/bin/mise"] = nil
assert(not installed(), "accepted missing mise binary")
files["/xpkgs/mise/''' + VERSION + '''/bin/mise"] = true
files["/xpkgs/mise/''' + VERSION + '''/LICENSE"] = nil
assert(not installed(), "accepted missing LICENSE")
files["/xpkgs/mise/''' + VERSION + '''/LICENSE"] = true

assert(config())
assert(#xvm_adds == 1)
assert(xvm_adds[1][1] == "mise" and xvm_adds[1][2].bindir == "/xpkgs/mise/''' + VERSION + '''/bin")

assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "mise")

-- Windows install via libs/payload.lua (.zip -> System32\\tar.exe --strip-components=1)
files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files["C:/cache/mise-v''' + VERSION + '''-windows-x64.zip"] = true
pkginfo = {
    name = function() return "mise" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "C:/cache/mise-v''' + VERSION + '''-windows-x64.zip" end,
    install_dir = function() return "C:/xpkgs/mise/''' + VERSION + '''" end,
}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "OS" then return "Windows_NT" end
    if k == "SystemRoot" then return "C:\\\\Windows" end
    return nil
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if files["C:/cache/mise-v''' + VERSION + '''-windows-x64.zip"] then
            files["C:/xpkgs/mise/''' + VERSION + '''/bin/mise.exe"] = true
            files["C:/xpkgs/mise/''' + VERSION + '''/bin/mise-shim.exe"] = true
            files["C:/xpkgs/mise/''' + VERSION + '''/LICENSE"] = true
        end
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\mise-v''' + VERSION + '''-windows-x64.zip" --strip-components=1 -C "C:\\\\xpkgs\\\\mise\\\\''' + VERSION + '''"')
assert(installed())

files["C:/xpkgs/mise/''' + VERSION + '''/bin/mise-shim.exe"] = nil
assert(not installed(), "accepted missing mise-shim.exe")
files["C:/xpkgs/mise/''' + VERSION + '''/bin/mise-shim.exe"] = true

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "mise" and xvm_adds[1][2].bindir == "C:/xpkgs/mise/''' + VERSION + '''/bin")
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "mise")

-- Missing archive and extracted dir must fail
files, dirs = {}, {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted dir exists")
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
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=180)


class TestVerify:
    def _shim_path(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("mise" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_mise(self, *args, env=None):
        result = subprocess.run(
            [str(self._shim_path()), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=env,
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        out = self._run_mise("--version")
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_non_blocking(self):
        out = self._run_mise("--help")
        assert "The front-end to your dev env" in out or "Usage: mise" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_env_and_task_runner(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            proj = root / "proj"
            proj.mkdir()
            (proj / "mise.toml").write_text(
                '[env]\nMISE_VERIFY_KEY = "mise-ok"\n\n[tasks.hello]\nrun = "echo mise-task-ok"\n',
                encoding="utf-8",
            )
            env = {
                **os.environ,
                "HOME": str(root),
                "MISE_DATA_DIR": str(root / "data"),
                "MISE_CONFIG_DIR": str(root / "config"),
                "MISE_CACHE_DIR": str(root / "cache"),
                "MISE_STATE_DIR": str(root / "state"),
            }
            self._run_mise("-C", str(proj), "trust", env=env)
            env_json = json.loads(self._run_mise("-C", str(proj), "env", "--json", env=env))
            assert env_json.get("MISE_VERIFY_KEY") == "mise-ok", env_json
            task_out = self._run_mise("-C", str(proj), "run", "hello", env=env)
            assert "mise-task-ok" in task_out, task_out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("mise")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists("mise")
