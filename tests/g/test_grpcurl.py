"""Tests for the grpcurl package."""
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
    assert_platform_supported,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "grpcurl"
PKG_FILE = "pkgs/g/grpcurl.lua"
REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_xlings(*args: str, timeout: int = 180) -> str:
    """Invoke xlings directly so XLINGS_HOME is never overwritten by login profiles."""
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for package index and lifecycle checks"
    result = subprocess.run(
        [command, *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def _run_lua(script: str, *args: str) -> str:
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
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping(self):
        source = r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(#package.programs == 1 and package.programs[1] == "grpcurl", "programs must be {grpcurl}")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/fullstorydev/grpcurl/releases")
local global_res = assert(auto.resources and auto.resources.GLOBAL)
assert(global_res.required == true)

local expected = {
    linux = { x86_64 = "x86_64", aarch64 = "arm64" },
    macosx = { x86_64 = "x86_64", aarch64 = "arm64" },
    windows = { x86_64 = "x86_64", aarch64 = "arm64" },
}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing xpm." .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest.ref for " .. platform)
    local entry = assert(p[version], "missing version entry for " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local digest = assert(entry.sha256[arch], "missing sha256 for " .. platform .. "/" .. arch)
        assert(#digest == 64 and digest:match("^[0-9a-f]+$"), platform .. "/" .. arch)
        local auto_tmpl = assert(global_res.url[platform] and global_res.url[platform][arch])
        assert(auto_tmpl:find("${tag}", 1, true), "autoupdate URL must use ${tag}")
        assert(auto_tmpl:find("${version}", 1, true), "autoupdate URL must use ${version}")
        local auto_resolved = auto_tmpl:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local xpm_resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved, "installer/updater URLs disagree for " .. platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
'''
        _run_lua(source, PKG_FILE)

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        source = r'''
function import() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()

local files = {}
local execs = {}
local xvm_calls = {}
local cur_install_file = ""
local cur_install_dir = ""
local cur_host = "linux"

pkginfo = {
    name = function() return "grpcurl" end,
    version = function() return "1.9.4" end,
    install_file = function() return cur_install_file end,
    install_dir = function() return cur_install_dir end,
}
os.host = function() return cur_host end
os.getenv = function(k) return k == "SystemRoot" and "C:\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function(d)
    for k in pairs(files) do
        if k:sub(1, #d) == d then files[k] = nil end
    end
end
os.mv = function(src, dst)
    assert(files[src], "missing src: " .. src)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function() end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cur_host == "windows" then
            files[cur_install_dir .. "/grpcurl.exe"] = true
            files[cur_install_dir .. "/LICENSE"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_calls, {"add", name, opts}) end,
    remove = function(name) table.insert(xvm_calls, {"remove", name}) end,
}

assert(loadfile(arg[1]))()

-- Unix case (pre-extracted flat tarball)
cur_host = "linux"
cur_install_file = "/tmp/dl/grpcurl_1.9.4_linux_x86_64.tar.gz"
cur_install_dir = "/store/xpkgs/xim-x-grpcurl/1.9.4"
files["/tmp/dl/grpcurl"] = true
files["/tmp/dl/LICENSE"] = true
assert(installed() == false)
assert(install() == true)
assert(files[cur_install_dir .. "/grpcurl"] == true)
assert(files[cur_install_dir .. "/LICENSE"] == true)
assert(#execs == 1 and execs[1]:match('chmod %+x "/store/xpkgs/xim%-x%-grpcurl/1%.9%.4/grpcurl"'))
assert(installed() == true)

-- Windows case (zip extracted via payload.unpack / System32 tar.exe)
files = {}
execs = {}
cur_host = "windows"
cur_install_file = "C:/dl/grpcurl_1.9.4_windows_x86_64.zip"
cur_install_dir = "C:/store/xpkgs/xim-x-grpcurl/1.9.4"
assert(installed() == false)
assert(install() == true)
assert(#execs == 1)
assert(execs[1]:match('^C:\\Windows\\System32\\tar%.exe %-xf "C:\\dl\\grpcurl_1%.9%.4_windows_x86_64%.zip" %-C "C:\\store\\xpkgs\\xim%-x%-grpcurl\\1%.9%.4"$'))
assert(installed() == true)

-- config & uninstall
assert(config() == true)
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "grpcurl" and xvm_calls[1][3].bindir == cur_install_dir)
assert(uninstall() == true)
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "grpcurl")
'''
        _run_lua(source, PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        _run_xlings("config", "--add-xpkg", str(REPO_ROOT / PKG_FILE), timeout=45)


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
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|try\s*\{|raise\()', src)


@skip_if_not("linux")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _run_xlings("install", under_test(PKG), "-y", timeout=90)


@skip_if_not("linux")
class TestVerify:
    @staticmethod
    def _grpcurl_bin() -> str:
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("grpcurl" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("grpcurl")
        assert found, f"Missing grpcurl shim ({shim}) and not found on PATH"
        return found

    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "1.9.4")
        proc = subprocess.run(
            [self._grpcurl_bin(), "-version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert f"grpcurl v{expected}" in out, out

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos_name = "current" if (subos_dir / "current").is_dir() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos_name)
        assert_xvm_registered("grpcurl")

    @pytest.mark.verify
    def test_describe_local_proto(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            proto = Path(tmpdir) / "echo.proto"
            proto.write_text(
                'syntax = "proto3";\n'
                'package test.v1;\n'
                'message EchoRequest { string message = 1; }\n'
                'message EchoResponse { string message = 1; }\n'
                'service EchoService {\n'
                '  rpc Echo(EchoRequest) returns (EchoResponse);\n'
                '}\n',
                encoding="utf-8",
            )
            proc = subprocess.run(
                [self._grpcurl_bin(), "-import-path", tmpdir, "-proto", "echo.proto", "describe", "test.v1.EchoService"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                check=True,
                timeout=15,
            )
            assert "service EchoService" in proc.stdout, proc.stdout
            assert "rpc Echo" in proc.stdout, proc.stdout
