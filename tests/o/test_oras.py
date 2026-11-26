"""Tests for the oras package."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_platform_supported,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "oras"
PKG_FILE = "pkgs/o/oras.lua"
VERSION = "1.4.0"
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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_supported_platforms(self, meta):
        assert meta.programs == ["oras"]
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_platforms_archs_sha256_and_autoupdate_pinned(self):
        _run_lua(
            '''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "oras")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/oras-project/oras/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
local seen_filenames = {}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    assert(p.deps == nil, "unexpected runtime deps on " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == ver, platform .. " latest should be " .. ver)
    local tag = "v" .. version
    local entry = assert(p[version], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256 and entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), platform .. "/" .. arch)
        local auto = au.resources.GLOBAL.url[platform][arch]
        assert(auto:find("${tag}", 1, true), "autoupdate URL must contain ${tag}")
        local resolved_auto = auto:gsub("%${tag}", tag):gsub("%${version}", version)
        local resolved_xpm = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(resolved_auto == resolved_xpm, "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        local fname = resolved_xpm:match("([^/]+)$")
        assert(not seen_filenames[fname], "duplicate asset filename: " .. fname)
        seen_filenames[fname] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_installed_install_config_uninstall_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local ver = arg[2]

-- Case 1: POSIX flat .tar.gz extracted directly into install_dir + chmod +x
local files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "oras" end,
    version = function() return ver end,
    install_file = function() return "/cache/oras_" .. ver .. "_linux_amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/oras/" .. ver end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k:sub(1, #p) == p then files[k] = nil end
    end
end
os.mv = function(src, dst)
    assert(files[src], "missing mv src: " .. src)
    table.insert(mvs, {src, dst})
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:find("^tar %-xzf") then
            files["/xpkgs/oras/" .. ver .. "/oras"] = true
            files["/xpkgs/oras/" .. ver .. "/LICENSE"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
files["/cache/oras_" .. ver .. "_linux_amd64.tar.gz"] = true
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/oras_' .. ver .. '_linux_amd64.tar.gz" -C "/xpkgs/oras/' .. ver .. '"')
assert(execs[2] == 'chmod +x "/xpkgs/oras/' .. ver .. '/oras"')

files["/xpkgs/oras/" .. ver .. "/LICENSE"] = nil
assert(not installed(), "installed() must reject missing LICENSE")
files["/xpkgs/oras/" .. ver .. "/LICENSE"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "oras" and adds[1][2].bindir == "/xpkgs/oras/" .. ver)
assert(uninstall())
assert(#rms == 1 and rms[1] == "oras")

-- Case 2: POSIX fallback when archive was pre-extracted and removed
files, dirs, mvs, execs = {}, {}, {}, {}
files["/cache/oras"] = true
files["/cache/LICENSE"] = true
assert(install())
assert(#mvs == 2)
assert(mvs[1][1] == "/cache/oras" and mvs[1][2] == "/xpkgs/oras/" .. ver .. "/oras")
assert(mvs[2][1] == "/cache/LICENSE" and mvs[2][2] == "/xpkgs/oras/" .. ver .. "/LICENSE")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/oras/' .. ver .. '/oras"')
assert(installed())

-- Case 3: Windows install via libs/payload.lua (.zip -> System32\\tar.exe)
files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "oras" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/oras_" .. ver .. "_windows_amd64.zip" end,
    install_dir = function() return "C:/xpkgs/oras/" .. ver end,
}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
files["C:/cache/oras_" .. ver .. "_windows_amd64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/oras/" .. ver .. "/oras.exe"] = true
        files["C:/xpkgs/oras/" .. ver .. "/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\oras_' .. ver .. '_windows_amd64.zip" -C "C:\\\\xpkgs\\\\oras\\\\' .. ver .. '"')

-- Case 4: Windows pre-extracted fallback
files, dirs, mvs, execs = {}, {}, {}, {}
files["C:/cache/oras.exe"] = true
files["C:/cache/LICENSE"] = true
assert(install())
assert(installed())
assert(#execs == 0)
assert(#mvs == 2)

-- Case 5: Missing archive and extracted binary must fail
files = {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither archive nor extracted binary exists")
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
        src = (REPO / PKG_FILE).read_text(encoding="utf-8")
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
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    def _oras_bin(self) -> str:
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("oras" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("oras")
        assert found, f"Missing installed oras shim at {shim} or in PATH"
        return found

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        proc = subprocess.run(
            [self._oras_bin(), "version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert proc.returncode == 0, out
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered_and_shim(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            cur_json = Path(xlings_home()) / "subos" / "current" / ".xlings.json"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if cur_json.is_file() else "default")
        assert_xvm_registered("oras")
        subos = os.environ["XLINGS_TEST_SUBOS"]
        shim = Path(xlings_home()) / "subos" / subos / "bin" / "oras"
        assert shim.is_file(), f"missing oras shim in {shim.parent}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_completion_offline_smoke(self):
        proc = subprocess.run(
            [self._oras_bin(), "completion", "bash"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert proc.returncode == 0, out
        assert "__oras_init_completion" in out or "complete" in out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_oci_layout_push_manifest_and_pull_offline(self, tmp_path):
        oras_bin = self._oras_bin()
        src_file = tmp_path / "payload.txt"
        src_content = "hello xim-pkgindex oras\n"
        src_file.write_text(src_content, encoding="utf-8")

        layout_ref = f"{tmp_path / 'oci-layout'}:v1"
        push_proc = subprocess.run(
            [oras_bin, "push", "--oci-layout", layout_ref, "payload.txt:text/plain"],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert push_proc.returncode == 0, push_proc.stdout + push_proc.stderr

        manifest_proc = subprocess.run(
            [oras_bin, "manifest", "fetch", "--oci-layout", layout_ref],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=15,
        )
        assert manifest_proc.returncode == 0, manifest_proc.stdout + manifest_proc.stderr
        manifest = json.loads(manifest_proc.stdout)
        assert manifest["schemaVersion"] == 2
        assert manifest["layers"][0]["annotations"]["org.opencontainers.image.title"] == "payload.txt"

        out_dir = tmp_path / "pulled"
        out_dir.mkdir()
        pull_proc = subprocess.run(
            [oras_bin, "pull", "--oci-layout", layout_ref, "-o", str(out_dir)],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert pull_proc.returncode == 0, pull_proc.stdout + pull_proc.stderr
        assert (out_dir / "payload.txt").read_text(encoding="utf-8") == src_content
