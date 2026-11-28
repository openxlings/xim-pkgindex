"""Tests for the migrate package (golang-migrate/migrate CLI)."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_no_typos,
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

PKG = "migrate"
PKG_FILE = "pkgs/m/migrate.lua"
VERSION = "4.20.1"
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
        check=True,
        cwd=REPO_ROOT,
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
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["migrate"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.name == "migrate")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/golang-migrate/migrate/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local seen_filenames = {}
for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == ver)
    local entry = assert(section[ver], "missing " .. ver .. " in " .. plat)
    assert(entry.arch_alias and entry.arch_alias.x86_64 == "amd64" and entry.arch_alias.aarch64 == "arm64")
    assert(entry.sha256)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        assert(tpl:find("${tag}", 1, true), "missing ${tag} in " .. tpl)
        local resolved_auto = tpl:gsub("%${tag}", "v" .. ver)
        local resolved_xpm = section.source:gsub("%${version}", ver):gsub("%${arch_alias}", entry.arch_alias[arch])
        assert(resolved_auto == resolved_xpm, "autoupdate and xpm URLs disagree for " .. plat .. "/" .. arch)
        local fname = resolved_xpm:match("([^/]+)$")
        assert(not seen_filenames[fname], "duplicate asset filename: " .. fname)
        seen_filenames[fname] = true
    end
end
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_tar_and_fallback(self):
        for plat, archive in [
            ("linux", "/cache/migrate.linux-amd64.tar.gz"),
            ("macosx", "/cache/migrate.darwin-arm64.tar.gz"),
        ]:
            _run_lua(
                '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local plat = arg[2]
local archive_path = arg[3]
local ver = arg[4]

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files[archive_path] = true

pkginfo = {
    name = function() return "migrate" end,
    version = function() return ver end,
    install_file = function() return archive_path end,
    install_dir = function() return "/xpkgs/migrate/" .. ver end,
}
os.host = function() return plat end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst) files[src] = nil; files[dst] = true end
log = { info = function() end }
fs = { mkdir_p = function(d) dirs[d] = true end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xzf") then
            files["/xpkgs/migrate/" .. ver .. "/migrate"] = true
            files["/xpkgs/migrate/" .. ver .. "/LICENSE"] = true
            files["/xpkgs/migrate/" .. ver .. "/README.md"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "' .. archive_path .. '" -C "/xpkgs/migrate/' .. ver .. '"')
assert(execs[2] == 'chmod +x "/xpkgs/migrate/' .. ver .. '/migrate"')
assert(installed())

for _, required in ipairs({ "/migrate", "/LICENSE", "/README.md" }) do
    files["/xpkgs/migrate/" .. ver .. required] = nil
    assert(not installed(), "accepted missing " .. required)
    files["/xpkgs/migrate/" .. ver .. required] = true
end

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "migrate" and xvm_adds[1][2].bindir == "/xpkgs/migrate/" .. ver)

assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "migrate")
''',
                PKG_FILE,
                plat,
                archive,
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
local archive_path = "C:/cache/migrate.windows-amd64.zip"
local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files[archive_path] = true

pkginfo = {
    name = function() return "migrate" end,
    version = function() return ver end,
    install_file = function() return archive_path end,
    install_dir = function() return "C:/xpkgs/migrate/" .. ver end,
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
fs = { mkdir_p = function(d) dirs[d] = true end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/migrate/" .. ver .. "/migrate.exe"] = true
        files["C:/xpkgs/migrate/" .. ver .. "/LICENSE"] = true
        files["C:/xpkgs/migrate/" .. ver .. "/README.md"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\migrate.windows-amd64.zip" -C "C:\\\\xpkgs\\\\migrate\\\\' .. ver .. '"')
assert(installed())

assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "migrate" and xvm_adds[1][2].bindir == "C:/xpkgs/migrate/" .. ver)

assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "migrate")
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
        assert_install_succeeds(under_test(PKG, VERSION), timeout=120)


class TestVerify:
    def _shim(self) -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("migrate" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_prog(self, *args: str, check: bool = True) -> subprocess.CompletedProcess:
        shim = self._shim()
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        if check:
            assert result.returncode == 0, result.stdout + result.stderr
        return result

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        res = self._run_prog("-version")
        assert expected in (res.stdout + res.stderr)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_and_drivers(self):
        res = self._run_prog("-help")
        out = res.stdout + res.stderr
        assert "Source drivers:" in out
        assert "Database drivers:" in out
        assert "stub" in out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            cur_json = Path(xlings_home()) / "subos" / "current" / ".xlings.json"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if cur_json.is_file() else "default")
        assert_xvm_registered("migrate")
        assert self._shim().is_file()

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_create_and_stub_up_offline(self, tmp_path):
        migrations_dir = tmp_path / "migrations"
        res_create = self._run_prog(
            "create", "-ext", "sql", "-dir", str(migrations_dir), "-seq", "init_schema"
        )
        up_file = migrations_dir / "000001_init_schema.up.sql"
        down_file = migrations_dir / "000001_init_schema.down.sql"
        assert up_file.is_file(), res_create.stdout + res_create.stderr
        assert down_file.is_file(), res_create.stdout + res_create.stderr

        up_file.write_text("CREATE TABLE example (id INT);\n", encoding="utf-8")
        down_file.write_text("DROP TABLE example;\n", encoding="utf-8")

        res_up = self._run_prog(
            "-source", f"file://{migrations_dir}", "-database", "stub://", "up"
        )
        assert "1/u init_schema" in (res_up.stdout + res_up.stderr)
