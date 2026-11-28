"""Tests for the ast-grep package."""
from pathlib import Path
import re
import shutil
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_valid_xvm_node_kinds,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "ast-grep"
PKG_FILE = "pkgs/a/ast-grep.lua"
VERSION = "0.51.3"
REPO = Path(__file__).resolve().parent.parent.parent


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


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
    def test_platforms_and_programs(self, meta):
        assert set(meta.platforms) >= {"linux", "macosx", "windows"}
        assert set(meta.programs) == {"ast-grep", "sg"}
        assert meta.has_xvm_enable
        assert meta.has_installed
        assert meta.has_install
        assert meta.has_config
        assert meta.has_uninstall

    @pytest.mark.static
    def test_platform_runtime_deps_and_sha256_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local expected = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
local ldeps = package.xpm.linux.deps and package.xpm.linux.deps.runtime or {}
assert(#ldeps == 2 and ldeps[1]:find("xim:glibc", 1, true) and ldeps[2]:find("xim:gcc-runtime", 1, true),
       "linux must declare xim:glibc and xim:gcc-runtime")
local wdeps = package.xpm.windows.deps and package.xpm.windows.deps.runtime or {}
assert(#wdeps == 1 and wdeps[1] == "xim:vcruntime",
       "windows must declare xim:vcruntime")
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "''' + VERSION + '''")
    local v = assert(p["''' + VERSION + '''"], "missing version on " .. plat)
    for _, arch in ipairs(arches) do
        local r = assert(v[arch], "missing " .. plat .. "/" .. arch)
        assert(type(r.url) == "string" and r.url:find("''' + VERSION + '''", 1, true))
        assert(type(r.sha256) == "string" and #r.sha256 == 64 and r.sha256:match("^%x+$"))
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_all_five_sha256_unique(self, meta):
        sha_matches = re.findall(r'sha256\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(sha_matches) == 5
        assert len(set(sha_matches)) == 5

    @pytest.mark.static
    def test_install_config_uninstall_posix_and_windows(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- 1. POSIX: pre-extracted flat archive in parent download dir
local files, execs, added, removed = {}, {}, {}, {}
pkginfo = {
    name = function() return "ast-grep" end,
    install_dir = function() return "/xpkgs/ast-grep/0.51.3" end,
    install_file = function() return "/cache/app-x86_64-unknown-linux-gnu.zip" end,
}
files["/cache/ast-grep"] = true
files["/cache/sg"] = true
os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function() end
fs = { mkdir_p = function() end, files = function() return {} end }
log = { info = function() end }
os.mv = function(src, dst)
    assert(files[src], "missing src: " .. src)
    files[src] = nil
    files[dst] = true
end
os.cp = function(src, dst) files[dst .. "/" .. src:match("([^/]+)$")] = true end
system = { exec = function(cmd) execs[#execs + 1] = cmd end }
xvm = {
    add = function(name, opts) added[#added + 1] = { name, opts } end,
    remove = function(name) removed[#removed + 1] = name end,
}

assert(installed() == false)
assert(install() == true)
assert(installed() == true)
assert(#execs == 1 and execs[1]:find("chmod +x", 1, true))
assert(config() == true)
assert(#added == 2 and added[1][1] == "ast-grep" and added[2][1] == "sg")
assert(uninstall() == true)
assert(#removed == 2 and removed[1] == "sg" and removed[2] == "ast-grep")

-- 2. Windows: flat zip + app-local xim:vcruntime DLL copy
files, execs = {}, {}
local copied = {}
pkginfo.install_dir = function() return "C:/xpkgs/ast-grep/0.51.3" end
pkginfo.install_file = function() return "C:/cache/app-x86_64-pc-windows-msvc.zip" end
pkginfo.dep_install_dir = function(dep)
    assert(dep == "xim:vcruntime")
    return "C:/xpkgs/vcruntime/14.44.35211"
end
files["C:/cache/ast-grep.exe"] = true
files["C:/cache/sg.exe"] = true
fs.files = function(d)
    assert(d == "C:/xpkgs/vcruntime/14.44.35211/bin")
    return { d .. "/crt_a.dll", d .. "/crt_b.dll" }
end
os.cp = function(src, dst) copied[#copied + 1] = { src, dst } end

assert(installed() == false)
assert(install() == true)
assert(installed() == true)
assert(#copied == 2 and copied[1][2] == "C:/xpkgs/ast-grep/0.51.3")
''', PKG_FILE)

    @pytest.mark.static
    @pytest.mark.skipif(shutil.which("luac") is None, reason="no luac on this machine")
    def test_lua_syntax(self):
        r = subprocess.run(["luac", "-p", str(REPO / PKG_FILE)],
                           capture_output=True, text=True)
        assert r.returncode == 0, r.stderr


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
    def test_no_forbidden_xmake_apis(self, meta):
        code = "\n".join(
            line for line in meta.raw_content.splitlines()
            if not line.lstrip().startswith("--")
        )
        for bad in ("os.arch", "os.curdir", "os.execv", "os.files", "os.host",
                    "path.", "is_host", "try {", "raise("):
            assert bad not in code, f"unexpected forbidden API {bad!r} in {PKG_FILE}"


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_ast_grep_version(self):
        assert_command_output("ast-grep --version", contains=f"ast-grep {VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_sg_version(self):
        assert_command_output("sg --version", contains=f"ast-grep {VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_shims(self):
        assert_xvm_shim_exists("ast-grep")
        assert_xvm_shim_exists("sg")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_ast_grep_pattern_match(self):
        proc = subprocess.run(
            ["bash", "-l", "-c", "ast-grep run -p '$A + $B' -l python --stdin"],
            input="result = foo + bar\n",
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert "foo + bar" in proc.stdout
