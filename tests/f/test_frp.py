"""Tests for the frp package (`frpc` and `frps` CLIs)."""
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

PKG = "frp"
PKG_FILE = "pkgs/f/frp.lua"
VERSION = "0.72.0"


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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["frpc", "frps"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.name == "frp")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/fatedier/frp/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

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
        assert(tpl:find("${tag}", 1, true) and tpl:find("${version}", 1, true), "missing ${tag}/${version} in " .. tpl)
    end
end
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_linux_and_macosx(self):
        for plat, archive in [
            ("linux", f"/cache/frp_{VERSION}_linux_amd64.tar.gz"),
            ("macosx", f"/cache/frp_{VERSION}_darwin_arm64.tar.gz"),
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

local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
dirs["/cache/" .. stem] = true

pkginfo = {
    name = function() return "frp" end,
    version = function() return ver end,
    install_file = function() return archive_path end,
    install_dir = function() return "/xpkgs/frp/" .. ver end,
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
    files[dst .. "/frpc"] = true
    files[dst .. "/frps"] = true
    files[dst .. "/LICENSE"] = true
end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/" .. stem and moved[1][2] == "/xpkgs/frp/" .. ver)
assert(installed())

for _, required in ipairs({ "/frpc", "/frps", "/LICENSE" }) do
    files["/xpkgs/frp/" .. ver .. required] = nil
    assert(not installed(), "accepted missing " .. required)
    files["/xpkgs/frp/" .. ver .. required] = true
end

assert(config())
assert(#xvm_adds == 3)
assert(xvm_adds[1][1] == "frp" and xvm_adds[1][2].type == "group")
assert(xvm_adds[2][1] == "frpc" and xvm_adds[2][2].bindir == "/xpkgs/frp/" .. ver and xvm_adds[2][2].binding == "frp@" .. ver)
assert(xvm_adds[3][1] == "frps" and xvm_adds[3][2].bindir == "/xpkgs/frp/" .. ver and xvm_adds[3][2].binding == "frp@" .. ver)

assert(uninstall())
assert(#xvm_rms == 3)
assert(xvm_rms[1] == "frps" and xvm_rms[2] == "frpc" and xvm_rms[3] == "frp")
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
    name = function() return "frp" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/frp_" .. ver .. "_windows_amd64.zip" end,
    install_dir = function() return "C:/xpkgs/frp/" .. ver end,
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
        files["C:/xpkgs/frp/" .. ver .. "/frpc.exe"] = true
        files["C:/xpkgs/frp/" .. ver .. "/frps.exe"] = true
        files["C:/xpkgs/frp/" .. ver .. "/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\frp_0%.72%.0_windows_amd64%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\frp\\\\0%.72%.0"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 3)
assert(xvm_adds[1][1] == "frp" and xvm_adds[1][2].type == "group")
assert(xvm_adds[2][1] == "frpc" and xvm_adds[2][2].bindir == "C:/xpkgs/frp/" .. ver and xvm_adds[2][2].binding == "frp@" .. ver)
assert(xvm_adds[3][1] == "frps" and xvm_adds[3][2].bindir == "C:/xpkgs/frp/" .. ver and xvm_adds[3][2].binding == "frp@" .. ver)

assert(uninstall())
assert(#xvm_rms == 3)
assert(xvm_rms[1] == "frps" and xvm_rms[2] == "frpc" and xvm_rms[3] == "frp")
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
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    def _shim(self, prog: str) -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / (prog + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_prog(self, prog: str, *args: str, check: bool = True) -> subprocess.CompletedProcess:
        shim = self._shim(prog)
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
    def test_versions(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert expected in self._run_prog("frpc", "--version").stdout
        assert expected in self._run_prog("frps", "--version").stdout

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        for prog in ("frp", "frpc", "frps"):
            assert_xvm_registered(prog)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_verify_configs_offline(self):
        with tempfile.TemporaryDirectory() as work:
            frpc_cfg = Path(work) / "frpc.toml"
            frpc_cfg.write_text(
                'serverAddr = "127.0.0.1"\nserverPort = 7000\n\n'
                '[[proxies]]\nname = "ssh"\ntype = "tcp"\nlocalIP = "127.0.0.1"\n'
                'localPort = 22\nremotePort = 6000\n',
                encoding="utf-8",
            )
            frps_cfg = Path(work) / "frps.toml"
            frps_cfg.write_text("bindPort = 7000\n", encoding="utf-8")

            res_c = self._run_prog("frpc", "verify", "-c", str(frpc_cfg))
            assert "syntax is ok" in (res_c.stdout + res_c.stderr)

            res_s = self._run_prog("frps", "verify", "-c", str(frps_cfg))
            assert "syntax is ok" in (res_s.stdout + res_s.stderr)

            bad_cfg = Path(work) / "bad.toml"
            bad_cfg.write_text("unknownField = 123\n", encoding="utf-8")
            bad_res = self._run_prog("frpc", "verify", "-c", str(bad_cfg), check=False)
            assert bad_res.returncode != 0
