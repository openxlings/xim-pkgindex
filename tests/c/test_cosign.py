"""Tests for the cosign package."""
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

PKG = "cosign"
PKG_FILE = "pkgs/c/cosign.lua"
RELEASE_VERSION = "3.1.6"
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


def _cosign_bin() -> str:
    suffix = ".exe" if os.name == "nt" else ""
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    candidates = [subos] if subos else ["current", "default"]
    for name in candidates:
        candidate = Path(xlings_home()) / "subos" / name / "bin" / f"cosign{suffix}"
        if candidate.is_file():
            return str(candidate)
    found = shutil.which("cosign")
    assert found, "cosign binary not found in subos bin or PATH"
    return found


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
    def test_supported_platforms(self, meta):
        assert meta.programs == ["cosign"]
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping_and_autoupdate(self):
        _run_lua('''
import = function() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and package.programs[1] == "cosign")

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64" },
}
local count = 0
local seen_filenames = {}
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest ref: " .. platform)
    assert(version == "3.1.6", "unexpected latest ref: " .. version)
    local entry = assert(p[version], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"),
               "invalid sha256 for " .. platform .. "/" .. arch)
        local auto = package.extensions.autoupdate.resources.GLOBAL.url[platform][arch]
        local resolved_auto = auto:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local resolved_xpm = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(resolved_auto == resolved_xpm,
               "installer/updater URLs disagree for " .. platform .. "/" .. arch)
        local fname = resolved_xpm:match("([^/]+)$")
        assert(not seen_filenames[fname], "duplicate asset filename: " .. fname)
        seen_filenames[fname] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 5)
''', PKG_FILE)

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        _run_lua('''
local files, dirs, execs, xvm_calls = {}, {}, {}, {}
local cur_install_file = ""
local cur_install_dir = ""

local mods = {
    ["xim.libxpkg.fs"] = function()
        fs = { mkdir_p = function(d) dirs[d] = true end }
    end,
    ["xim.libxpkg.pkginfo"] = function()
        pkginfo = {
            install_file = function() return cur_install_file end,
            install_dir = function() return cur_install_dir end,
        }
    end,
    ["xim.libxpkg.system"] = function()
        system = { exec = function(cmd) table.insert(execs, cmd) end }
    end,
    ["xim.libxpkg.xvm"] = function()
        xvm = {
            add = function(name, opts) table.insert(xvm_calls, {"add", name, opts}) end,
            remove = function(name) table.insert(xvm_calls, {"remove", name}) end,
        }
    end,
}

function import(name)
    assert(mods[name], "unexpected import: " .. name)()
end

os.isfile = function(p) return files[p] == true end
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

assert(loadfile(arg[1]))()

-- Unix case
cur_install_file = "/tmp/dl/cosign-linux-amd64"
cur_install_dir = "/store/xpkgs/xim-x-cosign/3.1.6"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(files["/store/xpkgs/xim-x-cosign/3.1.6/cosign"] == true)
assert(#execs == 1 and execs[1] == 'chmod +x "/store/xpkgs/xim-x-cosign/3.1.6/cosign"')
assert(installed() == true)

-- Windows case
files, dirs, execs = {}, {}, {}
cur_install_file = "C:\\\\dl\\\\cosign-windows-amd64.exe"
cur_install_dir = "C:\\\\store\\\\xpkgs\\\\xim-x-cosign\\\\3.1.6"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(files["C:\\\\store\\\\xpkgs\\\\xim-x-cosign\\\\3.1.6/cosign.exe"] == true)
assert(#execs == 0, "must not run chmod on Windows")
assert(installed() == true)

-- config & uninstall
assert(config() == true)
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "cosign" and xvm_calls[1][3].bindir == cur_install_dir)
assert(uninstall() == true)
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "cosign")
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

    @pytest.mark.isolation
    def test_portable_lua_and_libxpkg_only(self):
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG, RELEASE_VERSION), timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", RELEASE_VERSION)
        cosign_bin = _cosign_bin()
        proc = subprocess.run(
            [cosign_bin, "version"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        out = proc.stdout + proc.stderr
        assert proc.returncode == 0, out
        assert f"v{expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered_and_shim(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            cur_json = Path(xlings_home()) / "subos" / "current" / ".xlings.json"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if cur_json.is_file() else "default")
        assert_xvm_registered("cosign")
        subos = os.environ["XLINGS_TEST_SUBOS"]
        shim = Path(xlings_home()) / "subos" / subos / "bin" / "cosign"
        assert shim.is_file(), f"missing cosign shim in {shim.parent}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_offline_keygen_sign_and_verify_blob(self, tmp_path):
        cosign_bin = _cosign_bin()
        env = {**os.environ, "COSIGN_PASSWORD": "xlings-test-password"}

        subprocess.run(
            [cosign_bin, "generate-key-pair"],
            cwd=tmp_path,
            env=env,
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        assert (tmp_path / "cosign.key").is_file()
        assert (tmp_path / "cosign.pub").is_file()

        subprocess.run(
            [cosign_bin, "signing-config", "create", "--out", "signing-config.json"],
            cwd=tmp_path,
            env=env,
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )

        blob = tmp_path / "artifact.txt"
        blob.write_text("hello xim-pkgindex cosign\n", encoding="utf-8")
        bundle = tmp_path / "artifact.sigstore.json"

        sign_proc = subprocess.run(
            [
                cosign_bin, "sign-blob", "--yes",
                "--key", "cosign.key",
                "--signing-config", "signing-config.json",
                "--bundle", str(bundle),
                str(blob),
            ],
            cwd=tmp_path,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert sign_proc.returncode == 0, sign_proc.stdout + sign_proc.stderr
        assert bundle.is_file()

        verify_proc = subprocess.run(
            [
                cosign_bin, "verify-blob",
                "--insecure-ignore-tlog",
                "--key", "cosign.pub",
                "--bundle", str(bundle),
                str(blob),
            ],
            cwd=tmp_path,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        verify_out = verify_proc.stdout + verify_proc.stderr
        assert verify_proc.returncode == 0, verify_out
        assert "Verified OK" in verify_out, verify_out

        # Tampered blob must fail verification.
        blob.write_text("tampered content\n", encoding="utf-8")
        tamper_proc = subprocess.run(
            [
                cosign_bin, "verify-blob",
                "--insecure-ignore-tlog",
                "--key", "cosign.pub",
                "--bundle", str(bundle),
                str(blob),
            ],
            cwd=tmp_path,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert tamper_proc.returncode != 0
