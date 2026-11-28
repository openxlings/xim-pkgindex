"""Tests for the kubeseal package."""
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
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "kubeseal"
PKG_FILE = "pkgs/k/kubeseal.lua"
VERSION = "0.41.2"
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
    def test_platforms_arches_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua(
            '''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "kubeseal")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/bitnami/sealed-secrets/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64" },
}
local count = 0
for plat, arches in pairs(expected) do
    local p = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(p.latest and p.latest.ref == ver, "latest.ref mismatch in " .. plat)
    local entry = assert(p[ver], "missing " .. ver .. " in " .. plat)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias, plat .. "/" .. arch)
        local sha = assert(entry.sha256 and entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local auto_tpl = assert(global_url[plat] and global_url[plat][arch])
        assert(auto_tpl:find("${tag}", 1, true), "autoupdate must use ${tag}: " .. plat .. "/" .. arch)
        local auto_resolved = auto_tpl:gsub("%${tag}", "v" .. ver):gsub("%${version}", ver)
        local xpm_resolved = p.source:gsub("%${version}", ver):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved, "installer/updater URLs disagree for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 5)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local ver = arg[2]

-- Case 1: POSIX flat .tar.gz extracted directly into install_dir + chmod +x
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "kubeseal" end,
    version = function() return ver end,
    install_file = function() return "/cache/kubeseal-" .. ver .. "-linux-amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/kubeseal/" .. ver end,
}
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
    files[src] = nil
    files[dst] = true
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xzf") then
            files["/xpkgs/kubeseal/" .. ver .. "/kubeseal"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

files["/cache/kubeseal-" .. ver .. "-linux-amd64.tar.gz"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/kubeseal-' .. ver .. '-linux-amd64.tar.gz" -C "/xpkgs/kubeseal/' .. ver .. '"')
assert(execs[2] == 'chmod +x "/xpkgs/kubeseal/' .. ver .. '/kubeseal"')

files["/xpkgs/kubeseal/" .. ver .. "/kubeseal"] = nil
assert(not installed(), "accepted missing kubeseal binary")
files["/xpkgs/kubeseal/" .. ver .. "/kubeseal"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "kubeseal" and adds[1][2].bindir == "/xpkgs/kubeseal/" .. ver)
assert(uninstall())
assert(#rms == 1 and rms[1] == "kubeseal")

-- Case 2: Windows flat .tar.gz extracted via System32\\tar.exe
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "kubeseal" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/kubeseal-" .. ver .. "-windows-amd64.tar.gz" end,
    install_dir = function() return "C:/xpkgs/kubeseal/" .. ver end,
}
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/kubeseal/" .. ver .. "/kubeseal.exe"] = true
    end,
}

files["C:/cache/kubeseal-" .. ver .. "-windows-amd64.tar.gz"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\kubeseal-' .. ver .. '-windows-amd64.tar.gz" -C "C:\\\\xpkgs\\\\kubeseal\\\\' .. ver .. '"')
assert(config())
assert(#adds == 1 and adds[1][1] == "kubeseal" and adds[1][2].bindir == "C:/xpkgs/kubeseal/" .. ver)
assert(uninstall())
assert(#rms == 1 and rms[1] == "kubeseal")

-- Case 3: Windows fallback when binary was pre-extracted into parent dir
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
files["C:/cache/kubeseal.exe"] = true
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 0)

-- Case 4: Missing archive and extracted binary must fail
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
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


@skip_if_not("linux")
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


@skip_if_not("linux")
class TestVerify:
    @staticmethod
    def _kubeseal_bin() -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("kubeseal" + suffix)
        if shim.is_file():
            return shim
        found = shutil.which("kubeseal")
        assert found, f"Missing installed shim at {shim} or in PATH"
        return Path(found)

    def _run_kubeseal(self, *args: str) -> str:
        result = subprocess.run(
            [str(self._kubeseal_bin()), *args],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        out = self._run_kubeseal("--version")
        assert f"kubeseal version: {expected}" in out, out

    @pytest.mark.verify
    def test_slash_query_does_not_block(self):
        result = subprocess.run(
            [str(self._kubeseal_bin()), "/?"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=10,
        )
        assert result.returncode in (0, 1)

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos_name = "current" if (subos_dir / "current").is_dir() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos_name)
        assert_xvm_registered("kubeseal")

    @pytest.mark.verify
    def test_seal_and_recovery_unseal_offline(self, tmp_path):
        openssl = shutil.which("openssl")
        if not openssl:
            pytest.skip("openssl is unavailable for generating ephemeral test keypair")
        key = tmp_path / "key.pem"
        cert = tmp_path / "cert.pem"
        subprocess.run(
            [
                openssl,
                "req",
                "-x509",
                "-newkey",
                "rsa:2048",
                "-keyout",
                str(key),
                "-out",
                str(cert),
                "-days",
                "1",
                "-nodes",
                "-subj",
                "/CN=sealed-secret",
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        secret = tmp_path / "secret.yaml"
        secret.write_text(
            "apiVersion: v1\n"
            "kind: Secret\n"
            "metadata:\n"
            "  name: mysecret\n"
            "  namespace: default\n"
            "type: Opaque\n"
            "stringData:\n"
            "  foo: bar\n",
            encoding="utf-8",
        )
        sealed_yaml = self._run_kubeseal("--cert", str(cert), "-f", str(secret), "-o", "yaml")
        assert "kind: SealedSecret" in sealed_yaml, sealed_yaml
        assert "encryptedData:" in sealed_yaml, sealed_yaml

        sealed = tmp_path / "sealed.yaml"
        sealed.write_text(sealed_yaml, encoding="utf-8")
        unsealed_yaml = self._run_kubeseal(
            "--recovery-unseal",
            "--recovery-private-key",
            str(key),
            "-f",
            str(sealed),
            "-o",
            "yaml",
        )
        assert "kind: Secret" in unsealed_yaml, unsealed_yaml
        assert "foo: YmFy" in unsealed_yaml, unsealed_yaml
