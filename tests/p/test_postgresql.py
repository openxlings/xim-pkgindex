"""postgresql"""
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "postgresql"
PKG_FILE = "pkgs/p/postgresql.lua"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


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
    def test_all_platforms_deps_and_sha256_pinned(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local expected = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64"},
}
assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime[1] == "xim:vcruntime",
       "windows must depend on xim:vcruntime")
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "19.0.0")
    assert(p["19"] and p["19"].ref == "19.0.0")
    assert(p["18"] and p["18"].ref == "18.7.0")
    assert(p["17"] and p["17"].ref == "17.12.0")
    for _, ver in ipairs({"19.0.0", "18.7.0", "17.12.0"}) do
        local v = assert(p[ver], "missing version " .. ver .. " on " .. plat)
        for _, arch in ipairs(arches) do
            local r = assert(v[arch], "missing " .. plat .. "/" .. arch .. "@" .. ver)
            assert(type(r.url) == "string" and r.url:find("postgresql%-" .. ver, 1, false))
            assert(type(r.sha256) == "string" and #r.sha256 == 64 and r.sha256:match("^%x+$"))
        end
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_and_windows_vcruntime_copy(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, copied = {}, {}, {}
pkginfo = {
    name = function() return "postgresql" end,
    install_dir = function() return "C:/xpkgs/postgresql/19.0.0" end,
    install_file = function() return "C:/cache/postgresql-19.0.0-x86_64-pc-windows-msvc.zip" end,
    dep_install_dir = function(dep)
        assert(dep == "xim:vcruntime")
        return "C:/xpkgs/vcruntime/14.44.35211"
    end,
}
dirs["C:/cache/postgresql-19.0.0-x86_64-pc-windows-msvc"] = true
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = {
    mkdir_p = function() end,
    files = function(d)
        assert(d == "C:/xpkgs/vcruntime/14.44.35211/bin")
        return { d .. "/crt_a.dll", d .. "/crt_b.dll" }
    end,
}
os.mv = function(src, dst)
    dirs[src] = nil
    dirs[dst] = true
    for _, p in ipairs(package.programs) do
        files[dst .. "/bin/" .. p .. ".exe"] = true
    end
end
os.cp = function(src, dst)
    table.insert(copied, {src, dst})
end

assert(not installed())
assert(install())
assert(installed())
assert(#copied == 2)
assert(copied[1][2] == "C:/xpkgs/postgresql/19.0.0/bin")

files["C:/xpkgs/postgresql/19.0.0/bin/pg_basebackup.exe"] = nil
assert(not installed())
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
    def test_portable_lua_and_libxpkg_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm", "xim.pkgindex.payload",
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
    def test_psql_version(self):
        assert_command_output("psql --version", contains="19.0")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_postgres_version(self):
        assert_command_output("postgres --version", contains="19.0")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("psql")
        assert_xvm_registered("postgres")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_initdb_start_select_and_stop(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pgdata = root / "pgdata"
            sockdir = root / "sock"
            sockdir.mkdir()
            logfile = root / "postgres.log"
            port = _free_port()

            subprocess.run(
                ["initdb", "-D", str(pgdata), "-U", "postgres", "--auth=trust", "--locale=C", "-E", "UTF8"],
                check=True, capture_output=True, text=True,
            )
            opts = f"-h '' -k {sockdir} -p {port}"
            subprocess.run(
                ["pg_ctl", "-D", str(pgdata), "-l", str(logfile), "-o", opts, "start"],
                check=True, capture_output=True, text=True,
            )
            try:
                res = subprocess.run(
                    ["psql", "-h", str(sockdir), "-p", str(port), "-U", "postgres", "-d", "postgres", "-tAc", "SELECT 1"],
                    check=True, capture_output=True, text=True,
                )
                assert res.stdout.strip() == "1"
            finally:
                subprocess.run(
                    ["pg_ctl", "-D", str(pgdata), "stop", "-m", "immediate"],
                    check=True, capture_output=True, text=True,
                )
