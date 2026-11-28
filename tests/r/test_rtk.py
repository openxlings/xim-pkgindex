"""Official RTK OSS resources and an offline JSON-filtering lifecycle."""
import json
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification, assert_no_direct_path_modification,
    assert_no_direct_pkg_manager, assert_no_exec_xvm, assert_no_typos,
    assert_required_fields, assert_uses_new_api, assert_valid_spec,
    assert_valid_type, assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

ROOT = Path(__file__).resolve().parents[2]
PKG_FILE = "pkgs/r/rtk.lua"
VERSION = "1.2.1"


def run_xlings(*args):
    assert os.environ.get("XLINGS_HOME"), "Set an isolated XLINGS_HOME for native checks"
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required"
    result = subprocess.run([command, *args], text=True, capture_output=True,
                            encoding="utf-8", errors="replace", timeout=120)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def shim():
    suffix = ".exe" if os.name == "nt" else ""
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    for name in ([subos] if subos else ["current", "default"]):
        if (base / name / "bin").is_dir():
            return base / name / "bin" / ("rtk" + suffix)
    pytest.fail("No active subos bin directory")


def assert_json_filter(tmp_path):
    private = tmp_path / "profile"
    private.mkdir(exist_ok=True)
    env = os.environ.copy()
    for key in ("HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA",
                "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
        env[key] = str(private)
    document = tmp_path / "sample.json"
    document.write_text(json.dumps({"account": "synthetic-private-value", "enabled": True,
                                    "nested": {"count": 42}}), encoding="utf-8")
    result = subprocess.run([str(shim()), "json", str(document), "--keys-only"],
                            cwd=tmp_path, env=env, text=True, capture_output=True, timeout=20)
    assert result.returncode == 0, result.stdout + result.stderr
    compact = "".join(result.stdout.split())
    assert "account:string" in compact and "enabled:bool" in compact, compact
    assert "nested:{count:int}" in compact, compact
    assert "synthetic-private-value" not in result.stdout


class TestStatic:
    @pytest.mark.static
    def test_package_contract(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_valid_xvm_node_kinds(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_resources_and_windows_runtime(self):
        lua = shutil.which("lua5.4") or shutil.which("lua")
        assert lua, "Lua is required to evaluate resources"
        source = r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2" and package.ci.mirror)
assert(package.licenses[1] == "Apache-2.0")
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    local p = package.xpm[platform]
    assert(p.source:match("github.com/rtk%-ai/rtk/releases/") and p.source:match("rtk%-oss%-"))
    local entry = p[p.latest.ref]
    for arch, hash in pairs(entry.sha256) do
        assert(arch == "x86_64" or arch == "aarch64")
        assert(#hash == 64 and hash:match("^[a-f0-9]+$"))
    end
    assert(entry.sha256.x86_64)
    if platform ~= "windows" then assert(entry.sha256.aarch64) end
end
assert(package.xpm.windows.deps.runtime[1] == "xim:vcruntime")
assert(package.xpm.windows[package.xpm.windows.latest.ref].sha256.aarch64 == nil)
'''
        subprocess.run([lua, "-", PKG_FILE], cwd=ROOT, input=source, text=True,
                       capture_output=True, check=True, timeout=10)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_global_changes(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_uses_new_api(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        run_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert "rtk" in run_xlings("search", under_test("rtk"), "--agent")


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install_reinstall_and_remove(self, tmp_path):
        target = under_test("rtk", os.environ.get("XLINGS_TEST_VERSION", VERSION))
        run_xlings("install", target, "--yes", "--agent")
        assert shim().is_file()
        exe = "rtk.exe" if os.name == "nt" else "rtk"
        payloads = [p for p in (Path(xlings_home()) / "data" / "xpkgs").glob("*-x-rtk/*")
                    if (p / exe).is_file()]
        assert payloads, "Install must provide real package files"
        for p in payloads:
            assert (p / "LICENSE").is_file()
            if os.name == "nt":
                assert (p / "vcruntime140.dll").is_file(), "The CRT must be app-local"
        assert_json_filter(tmp_path)
        run_xlings("list", "rtk", "--agent")
        run_xlings("install", target, "--yes", "--agent")
        assert_json_filter(tmp_path)
        route = shim()
        run_xlings("remove", target, "--yes", "--agent")
        assert not route.exists() and not route.is_symlink()
        assert all(not p.exists() for p in payloads)
        registry = json.loads((route.parent.parent / ".xlings.json").read_text(encoding="utf-8"))
        assert not (registry.get("workspace") or {}).get("rtk")
        run_xlings("list", "rtk", "--agent")
        # Keep it installed for the verify level and CI's own final cleanup.
        run_xlings("install", target, "--yes", "--agent")


class TestVerify:
    @pytest.mark.verify
    def test_version_and_filter(self, tmp_path):
        result = subprocess.run([str(shim()), "--version"], text=True,
                                capture_output=True, timeout=20)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "rtk " + os.environ.get("XLINGS_TEST_VERSION", VERSION) in result.stdout
        assert_json_filter(tmp_path)
