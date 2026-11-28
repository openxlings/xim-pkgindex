"""Tests for the taplo package (A TOML toolkit written in Rust)."""
import os
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
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "taplo"
PKG_FILE = "pkgs/t/taplo.lua"
VERSION = "0.10.0"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args], input=script, text=True, capture_output=True, check=True
    ).stdout


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def code(meta):
    return "\n".join(
        line for line in meta.raw_content.splitlines()
        if not line.lstrip().startswith("--")
    )


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
    def test_no_forbidden_xmake_apis(self, code):
        for pat in (r"\bpath\.", r"\bos\.host\s*\(", r"\bis_host\s*\(", r"\btry\s*\{", r"\braise\s*\("):
            assert not re.search(pat, code), f"forbidden xmake API pattern matched: {pat}"

    @pytest.mark.static
    def test_platforms_arches_sha256_and_autoupdate(self, meta):
        """Linux, macOS, and Windows (each x86_64/aarch64) are covered with
        pinned sha256s, zero runtime deps, and matching autoupdate templates."""
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)
        assert meta.programs == ["taplo"]
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "taplo")

local expected = {
    linux = {"x86_64", "aarch64"},
    macosx = {"x86_64", "aarch64"},
    windows = {"x86_64", "aarch64"},
}

for plat, arches in pairs(expected) do
    local sec = assert(package.xpm[plat], "missing platform " .. plat)
    assert(sec.latest and sec.latest.ref == ver, "latest mismatch on " .. plat)
    assert(sec.deps == nil, "unexpected runtime deps on " .. plat)
    assert(type(sec.source) == "string" and sec.source:find("${version}", 1, true))
    assert(sec.source:find("${arch}", 1, true))
    local entry = assert(sec[ver], "missing version " .. ver .. " on " .. plat)
    for _, arch in ipairs(arches) do
        local h = assert(entry.sha256 and entry.sha256[arch],
                         "missing sha256 on " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"),
               "invalid sha256 on " .. plat .. "/" .. arch)
    end
end

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/tamasfe/taplo/releases")
local global = assert(auto.resources and auto.resources.GLOBAL)
assert(global.required == true)
for plat, arches in pairs(expected) do
    for _, arch in ipairs(arches) do
        local tmpl = assert(global.url[plat] and global.url[plat][arch])
        assert(tmpl:find("${tag}", 1, true), "missing ${tag} on " .. plat .. "/" .. arch)
        assert(tmpl:find(arch, 1, true), "missing arch on " .. plat .. "/" .. arch)
    end
end
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_hooks_in_lua_sandbox(self):
        """Verify install/installed/config/uninstall for POSIX .gz and Windows .zip."""
        _run_lua('''
import = function() end
dofile(arg[1])

-- Case 1: POSIX .gz archive decompressed via gzip -dc
local files, execs, xvm_adds, xvm_rms = {}, {}, {}, {}
local install_file = "/tmp/cache/taplo-linux-x86_64.gz"
local install_dir = "/opt/xpkgs/taplo/0.10.0"

os.isfile = function(p) return files[p] == true end
os.isdir = function() return false end
os.tryrm = function() end
os.mv = function(src, dst)
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("gzip -dc", 1, true) then
            files[install_dir .. "/taplo"] = true
        end
    end,
}
pkginfo = {
    install_dir = function() return install_dir end,
    install_file = function() return install_file end,
}
payload = {
    unpack = function() error("unexpected payload.unpack on POSIX") end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

files[install_file] = true
assert(not installed())
assert(install())
assert(installed())
assert(files[install_dir .. "/taplo"])
assert(#execs == 2 and execs[1]:find("gzip -dc", 1, true) and execs[2]:find("chmod +x", 1, true))
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "taplo" and xvm_adds[1][2].bindir == install_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "taplo")

-- Case 2: POSIX pre-extracted binary beside archive
files, execs = {}, {}
files["/tmp/cache/taplo-linux-x86_64"] = true
assert(not installed())
assert(install())
assert(installed())
assert(files[install_dir .. "/taplo"])
assert(#execs == 1 and execs[1]:find("chmod +x", 1, true))

-- Case 3: Windows .zip containing flat taplo.exe unpacked via payload.unpack{}
files, execs, xvm_adds, xvm_rms = {}, {}, {}, {}
local unpack_calls = {}
install_file = "C:\\\\cache\\\\taplo-windows-x86_64.zip"
install_dir = "C:/xpkgs/taplo/0.10.0"
files[install_file] = true
payload.unpack = function(opt)
    table.insert(unpack_calls, opt)
    files[install_dir .. "/taplo.exe"] = true
end
assert(not installed())
assert(install())
assert(installed())
assert(#unpack_calls == 1 and unpack_calls[1].extracted == nil)
assert(files[install_dir .. "/taplo.exe"])
assert(#execs == 0)
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "taplo" and xvm_adds[1][2].bindir == install_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "taplo")

-- Case 4: Windows pre-extracted taplo.exe fallback
files, unpack_calls = {}, {}
files["C:/cache/taplo.exe"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#unpack_calls == 0)
assert(files[install_dir .. "/taplo.exe"])
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


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output("taplo --version", contains=f"taplo {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            from tests.lib.platform_utils import xlings_home
            subos_dir = Path(xlings_home()) / "subos"
            chosen = "current" if (subos_dir / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", chosen)
        assert_xvm_registered("taplo")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_shim_exists(self):
        from tests.lib.platform_utils import xlings_home
        subos_dir = Path(xlings_home()) / "subos"
        subos_name = os.environ.get("XLINGS_TEST_SUBOS") or (
            "current" if (subos_dir / "current" / "bin").is_dir() else "default"
        )
        shim = subos_dir / subos_name / "bin" / "taplo"
        assert shim.exists(), f"missing taplo shim at {shim}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_fmt_check_on_toml_snippet(self, tmp_path):
        good = tmp_path / "good.toml"
        good.write_text('[package]\nname = "taplo"\nversion = "0.10.0"\n', encoding="utf-8")
        proc = subprocess.run(
            ["bash", "-l", "-c", f'taplo fmt --check "{good}"'],
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        assert proc.returncode == 0, f"taplo fmt --check failed: {proc.stderr}"

        bad = tmp_path / "bad.toml"
        bad.write_text('[package]\nname="taplo"\n', encoding="utf-8")
        proc_bad = subprocess.run(
            ["bash", "-l", "-c", f'taplo fmt --check "{bad}"'],
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        assert proc_bad.returncode != 0, "expected taplo fmt --check to flag unformatted TOML"
