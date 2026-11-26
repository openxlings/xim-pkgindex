"""Tests for the sops package."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_command_output,
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
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "sops"
PKG_FILE = "pkgs/s/sops.lua"
VERSION = "3.13.3"
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
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping_and_autoupdate(self):
        _run_lua(
            r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "sops")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/getsops/sops/releases")
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
    assert(not p.deps, "static binary should not declare runtime deps on " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest.ref: " .. platform)
    assert(version == "3.13.3")
    local entry = assert(p[version], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256 and entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^[0-9a-f]+$"), platform .. "/" .. arch)
        local auto = assert(au.resources.GLOBAL.url[platform] and au.resources.GLOBAL.url[platform][arch])
        assert(auto:find("${tag}", 1, true) and auto:find("${version}", 1, true),
               "autoupdate template must use ${tag} and ${version}: " .. platform .. "/" .. arch)
        local auto_resolved = auto:gsub("%${tag}", "v" .. version):gsub("%${version}", version):gsub("%${arch_alias}", alias)
        local xpm_resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved,
               "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        local filename = xpm_resolved:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        _run_lua(
            r'''
local files = {}
local dirs = {}
local execs = {}
local xvm_calls = {}
local cur_install_file = ""
local cur_install_dir = ""

local mods = {
    ["xim.libxpkg.fs"] = function()
        fs = {
            mkdir_p = function(d) dirs[d] = true end,
        }
    end,
    ["xim.libxpkg.pkginfo"] = function()
        pkginfo = {
            install_file = function() return cur_install_file end,
            install_dir = function() return cur_install_dir end,
        }
    end,
    ["xim.libxpkg.xvm"] = function()
        xvm = {
            add = function(name, opts) table.insert(xvm_calls, {"add", name, opts}) end,
            remove = function(name) table.insert(xvm_calls, {"remove", name}) end,
        }
    end,
    ["xim.libxpkg.system"] = function()
        system = {
            exec = function(cmd) table.insert(execs, cmd) end,
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
cur_install_file = "/tmp/dl/sops-v3.13.3.linux.amd64"
cur_install_dir = "/store/xpkgs/xim-x-sops/3.13.3"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(dirs[cur_install_dir] == true)
assert(files["/store/xpkgs/xim-x-sops/3.13.3/sops"] == true)
assert(#execs == 1 and execs[1] == 'chmod +x "/store/xpkgs/xim-x-sops/3.13.3/sops"')
assert(installed() == true)

-- Windows case
files = {}
dirs = {}
execs = {}
cur_install_file = "C:\\dl\\sops-v3.13.3.amd64.exe"
cur_install_dir = "C:\\store\\xpkgs\\xim-x-sops\\3.13.3"
files[cur_install_file] = true
assert(installed() == false)
assert(install() == true)
assert(dirs[cur_install_dir] == true)
assert(files["C:\\store\\xpkgs\\xim-x-sops\\3.13.3/sops.exe"] == true)
assert(#execs == 0, "must not run chmod on Windows")
assert(installed() == true)

-- config & uninstall
assert(config() == true)
assert(xvm_calls[1][1] == "add" and xvm_calls[1][2] == "sops" and xvm_calls[1][3].bindir == cur_install_dir)
assert(uninstall() == true)
assert(xvm_calls[2][1] == "remove" and xvm_calls[2][2] == "sops")
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
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    def _sops_bin(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("sops" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("sops")
        assert found, f"Missing installed sops shim at {shim} or in PATH"
        return found

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output(f'"{self._sops_bin()}" --version --disable-version-check', contains=expected)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help(self):
        assert_command_output(f'"{self._sops_bin()}" --help', contains="encrypted file editor")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = "current" if (Path(xlings_home()) / "subos" / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS")
        if subos:
            shim = Path(xlings_home()) / "subos" / subos / "bin" / ("sops" + suffix)
            assert shim.is_file(), f"shim not found at {shim}"
        else:
            assert_xvm_shim_exists(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_encrypt_decrypt_age_roundtrip(self, tmp_path):
        # Deterministic test-only age keypair (derived from 0x01..0x20) for offline encryption smoke test.
        pub = "age1q73he0q5yzfu3d64msd3p6rvksnrwjk3d2598mgtmlqt9wrdr37q2vrn72"
        sec = "AGE-SECRET-" + "KEY-1QYPQXPQ9QCRSSZG2PVXQ6RS0ZQG3YYC5Z5TPWXQERGD3C8G7RUSQGPQYEE"

        plain = tmp_path / "secret.yaml"
        plain.write_text("hello: world\n", encoding="utf-8")

        enc_proc = subprocess.run(
            [self._sops_bin(), "encrypt", "--age", pub, str(plain)],
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )
        assert "ENC[AES256_GCM," in enc_proc.stdout

        enc = tmp_path / "secret.enc.yaml"
        enc.write_text(enc_proc.stdout, encoding="utf-8")

        env = {**os.environ, "SOPS_AGE_KEY": sec, "HOME": str(tmp_path)}
        dec_proc = subprocess.run(
            [self._sops_bin(), "decrypt", str(enc)],
            capture_output=True,
            text=True,
            env=env,
            check=True,
            timeout=15,
        )
        assert dec_proc.stdout == "hello: world\n"
