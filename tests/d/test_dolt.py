"""Tests for the dolt package."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_valid_xvm_node_kinds,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "dolt"
PKG_FILE = "pkgs/d/dolt.lua"
VERSION = "2.7.7"
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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["dolt"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.name == "dolt")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/dolthub/dolt/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

assert(package.xpm.linux.deps == nil, "dolt linux binaries are statically linked")
assert(package.xpm.windows.deps == nil, "dolt windows binary imports only OS DLLs")

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64" },
}
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(type(section.source) == "string" and section.source:find("${version}", 1, true))
    assert(section.latest and section.latest.ref == ver)
    local entry = assert(section[ver], "missing " .. ver .. " in " .. plat)
    assert(entry.arch_alias, "missing arch_alias in " .. plat)
    assert(entry.sha256, "missing sha256 in " .. plat)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, "alias mismatch for " .. plat .. "/" .. arch)
        local h = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        assert(tpl:find("${tag}", 1, true), "missing ${tag} in " .. tpl)
        local auto_resolved = tpl:gsub("%${tag}", "v" .. ver)
        local src_resolved = section.source:gsub("%${version}", ver):gsub("%${arch_alias}", alias)
        assert(auto_resolved == src_resolved, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch in " .. plat .. ": " .. arch)
    end
end
assert(package.xpm.windows[ver].sha256.aarch64 == nil, "windows/aarch64 not published upstream")
assert(global_url.windows.aarch64 == nil)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_all_five_sha256_unique(self, meta):
        sha_matches = re.findall(r'(?:x86_64|aarch64)\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(sha_matches) == 5
        assert len(set(sha_matches)) == 5

    @pytest.mark.static
    def test_hooks_posix_linux_and_macosx(self):
        for plat, archive in [
            ("linux", "/cache/dolt-linux-amd64.tar.gz"),
            ("macosx", "/cache/dolt-darwin-arm64.tar.gz"),
        ]:
            stem = archive.rsplit("/", 1)[-1].removesuffix(".tar.gz")
            _run_lua(
                '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local plat = arg[2]
local archive_path = arg[3]
local stem = arg[4]
local ver = arg[5]

local files, dirs, moved, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}, {}
dirs["/cache/" .. stem] = true

pkginfo = {
    name = function() return "dolt" end,
    version = function() return ver end,
    install_file = function() return archive_path end,
    install_dir = function() return "/xpkgs/xim-x-dolt/" .. ver end,
}
os.host = function() return plat end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/bin/dolt"] = true
    files[dst .. "/LICENSES"] = true
end
log = { info = function() end }
fs = { mkdir_p = function() end }
system = { exec = function(cmd) table.insert(execs, cmd) end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/" .. stem and moved[1][2] == "/xpkgs/xim-x-dolt/" .. ver)
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/xim-x-dolt/' .. ver .. '/bin/dolt"')
assert(installed())

files["/xpkgs/xim-x-dolt/" .. ver .. "/bin/dolt"] = nil
assert(not installed(), "accepted missing bin/dolt binary")
files["/xpkgs/xim-x-dolt/" .. ver .. "/bin/dolt"] = true

assert(config())
assert(#xvm_adds == 1)
assert(xvm_adds[1][1] == "dolt" and xvm_adds[1][2].bindir == "/xpkgs/xim-x-dolt/" .. ver .. "/bin")

assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "dolt")
''',
                PKG_FILE,
                plat,
                archive,
                stem,
                VERSION,
            )

    @pytest.mark.static
    def test_hooks_windows_zip(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local ver = arg[2]
local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "dolt" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/dolt-windows-amd64.zip" end,
    install_dir = function() return "C:/xpkgs/xim-x-dolt/" .. ver end,
}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/xim-x-dolt/" .. ver .. "/bin/dolt.exe"] = true
        files["C:/xpkgs/xim-x-dolt/" .. ver .. "/LICENSES"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\dolt%-windows%-amd64%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\xim%-x%-dolt\\\\2%.7%.7"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 1)
assert(xvm_adds[1][1] == "dolt" and xvm_adds[1][2].bindir == "C:/xpkgs/xim-x-dolt/" .. ver .. "/bin")

assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "dolt")
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_proxy_stub_fallback(self):
        _run_lua(
            '''
import = function() end
dofile(arg[1])
payload = setmetatable({}, { __index = function() return setmetatable({}, { __call = function() end }) end })

local ver = arg[2]
local files, dirs, moved, execs = {}, {}, {}, {}
dirs["/cache/dolt-linux-amd64"] = true

pkginfo = {
    name = function() return "dolt" end,
    version = function() return ver end,
    install_file = function() return "/cache/dolt-linux-amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/local-x-dolt/" .. ver end,
}
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/bin/dolt"] = true
end
fs = { mkdir_p = function() end }
system = { exec = function(cmd) table.insert(execs, cmd) end }

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/dolt-linux-amd64" and moved[1][2] == "/xpkgs/local-x-dolt/" .. ver)
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/local-x-dolt/' .. ver .. '/bin/dolt"')
assert(installed())
''',
            PKG_FILE,
            VERSION,
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
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    def _shim_path(self) -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / "default" / "bin"
        shim = bindir / ("dolt" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_dolt(self, *args: str, cwd: str | None = None) -> str:
        res = subprocess.run(
            [str(self._shim_path()), *args],
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert res.returncode == 0, res.stdout + res.stderr
        return res.stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        out = self._run_dolt("version")
        assert f"dolt version {expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current")
        assert_xvm_registered("dolt")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_init_sql_and_commit_roundtrip(self):
        with tempfile.TemporaryDirectory() as work:
            self._run_dolt("init", "--name", "Test", "--email", "test@example.com", cwd=work)
            self._run_dolt(
                "sql",
                "-q",
                "CREATE TABLE items (id INT PRIMARY KEY, name VARCHAR(32)); INSERT INTO items VALUES (1, 'xlings');",
                cwd=work,
            )
            self._run_dolt("add", "items", cwd=work)
            self._run_dolt("commit", "-m", "add items", cwd=work)
            out = self._run_dolt("sql", "-q", "SELECT name FROM items WHERE id = 1;", cwd=work)
            assert "xlings" in out, out
            log_out = self._run_dolt("log", "-n", "1", cwd=work)
            assert "add items" in log_out, log_out
