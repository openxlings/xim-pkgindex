"""Portable fnm resources, isolation, registration, and offline functionality."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "fnm"
PKG_FILE = "pkgs/f/fnm.lua"
ROOT = Path(__file__).resolve().parents[2]


def run_xlings(*args):
    suffix = ".exe" if os.name == "nt" else ""
    native = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(native) if native.is_file() else shutil.which("xlings")
    assert command, "xlings is required for native package checks"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def executable():
    suffix = ".exe" if os.name == "nt" else ""
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    for name in ([subos] if subos else ["current", "default"]):
        binary = Path(xlings_home()) / "subos" / name / "bin" / (PKG + suffix)
        if binary.is_file():
            return str(binary)
    pytest.fail("Installed fnm shim is missing")


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_official_resource_and_update_matrix(self):
        lua = shutil.which("lua5.4") or shutil.which("lua")
        assert lua, "Lua is required to evaluate V2 resource declarations"
        source = r'''
function import() end
assert(loadfile(arg[1]))()
local expected = {
    linux = {x86_64="linux", aarch64="arm64"},
    macosx = {x86_64="macos", aarch64="macos"},
    windows = {x86_64="windows"},
}
local auto = package.extensions.autoupdate
assert(package.spec == "2")
assert(auto.source == "https://github.com/Schniz/fnm/releases")
assert(auto.resources.CN == nil)
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    for arch, asset in pairs(arches) do
        local resource = entry[arch] or entry
        local hash = type(resource.sha256) == "table" and resource.sha256[arch] or resource.sha256
        assert(type(hash) == "string" and #hash == 64 and hash:match("^[a-f0-9]+$"))
        local wanted = "https://github.com/Schniz/fnm/releases/download/v" .. version .. "/fnm-" .. asset .. ".zip"
        assert(resource.url == wanted)
        assert(auto.resources.GLOBAL.url[platform][arch]:gsub("%${version}", version) == wanted)
    end
    for arch in pairs(auto.resources.GLOBAL.url[platform]) do assert(arches[arch]) end
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        if not arches[arch] then
            assert(entry[arch] == nil)
            assert(type(entry.sha256) ~= "table" or entry.sha256[arch] == nil)
        end
    end
end
'''
        subprocess.run([lua, "-", PKG_FILE], input=source, cwd=ROOT, text=True,
                       capture_output=True, check=True, timeout=30)


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_compliance(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text()
        assert set(re.findall(r'import\("([^\"]+)"\)', source)) == {
            "xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|os\.(?:host|curdir|execv)\(|is_host\(|raise\()', source)


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        run_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in run_xlings("search", under_test(PKG), "--agent")


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        run_xlings("install", under_test(PKG), "--yes", "--agent")
        assert Path(executable()).is_file()


class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        result = subprocess.run([executable(), "--version"], capture_output=True,
                                text=True, timeout=30)
        assert result.returncode == 0, result.stderr
        match = re.fullmatch(r"fnm (\d+\.\d+\.\d+)\s*", result.stdout)
        assert match, result.stdout
        if os.environ.get("XLINGS_TEST_VERSION"):
            assert match[1] == os.environ["XLINGS_TEST_VERSION"]

    @pytest.mark.verify
    def test_offline_environment_setup(self, tmp_path):
        # fnm's shell setup is opt-in and must work without installing Node.
        env = {k: v for k, v in os.environ.items() if not k.startswith("FNM_")}
        runtime = tmp_path / "runtime"
        runtime.mkdir(mode=0o700)
        store = tmp_path / "versions"
        env.update(HOME=str(tmp_path), USERPROFILE=str(tmp_path),
                   APPDATA=str(tmp_path / "appdata"), LOCALAPPDATA=str(tmp_path / "local"),
                   XDG_DATA_HOME=str(tmp_path / "data"), XDG_RUNTIME_DIR=str(runtime))
        result = subprocess.run(
            [executable(), "--fnm-dir", str(store), "env", "--json"],
            env=env, capture_output=True, text=True, timeout=30,
        )
        assert result.returncode == 0, result.stderr
        settings = json.loads(result.stdout)
        assert Path(settings["FNM_DIR"]).resolve() == store.resolve()
        versions = store / "node-versions"
        assert not versions.exists() or not any(versions.iterdir())
