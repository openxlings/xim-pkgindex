"""Portable headscale package: no daemon, credentials or system configuration."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "headscale"
PKG_FILE = "pkgs/h/headscale.lua"
VERSION = "0.29.8"
ROOT = Path(__file__).resolve().parents[2]
SUPPORTED = pytest.mark.skipif(
    sys.platform not in ("linux", "darwin"), reason="No upstream Windows binary"
)
HASHES = {
    "linux/x86_64": "4f55dc066924bdc234a4b300c7330df4fbd89d42ba180176b6335d4a3c19759b",
    "linux/aarch64": "0b02e6f23e0fc3cbe679f9fd3abf9933f6c579e1cb7fca94e2d921d15948b755",
    "macosx/x86_64": "0f169588fa533d5780d0bc13aca3b47c2a949c260e489db899679217bf793a47",
    "macosx/aarch64": "7348ad39eabc943dad14b78d268bd43c2189aae34756ee60e5f09ce36b54c4d3",
}


def _lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    result = subprocess.run(
        [lua, "-", str(ROOT / PKG_FILE), *args], input=script,
        cwd=ROOT, capture_output=True, text=True, timeout=20,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def _xlings(*args):
    # Native argv deliberately avoids bash -l and shell-profile home overrides.
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for index/lifecycle checks"
    result = subprocess.run(
        [command, *args], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=240,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def _shim():
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    names = [subos] if subos else ["current", "default"]
    for name in names:
        shim = Path(xlings_home()) / "subos" / name / "bin" / PKG
        if shim.is_file():
            return shim
    pytest.fail("Installed headscale shim is missing")


def _headscale(*args, cwd=None):
    env = {key: value for key, value in os.environ.items()
           if not key.startswith("HEADSCALE_")}
    env["HEADSCALE_DISABLE_CHECK_UPDATES"] = "true"
    return subprocess.run(
        [str(_shim()), *args], cwd=cwd, env=env, capture_output=True,
        text=True, encoding="utf-8", timeout=20,
    )


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)
        assert_no_typos(PKG_FILE)
        assert meta.name == PKG and meta.spec == "2"

    @pytest.mark.static
    def test_complete_pinned_matrix(self):
        output = _lua(r'''
function import() end
dofile(arg[1])
assert(table.concat(package.archs, ",") == "x86_64,aarch64")
assert(package.licenses[1] == "BSD-3-Clause")
assert(not package.xpm.windows and not package.xpm.freebsd)
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/juanfont/headscale/releases")
assert(auto.resources.GLOBAL.required == true and not auto.resources.CN)
for _, platform in ipairs({"linux", "macosx"}) do
    local p = package.xpm[platform]
    assert(p.latest.ref == "0.29.8")
    local entry = assert(p["0.29.8"])
    for _, arch in ipairs(package.archs) do
        local url = p.source:gsub("%${version}", "0.29.8")
                            :gsub("%${arch_alias}", entry.arch_alias[arch])
        local template = assert(auto.resources.GLOBAL.url[platform][arch])
        local resolved = template:gsub("%${tag}", "v0.29.8")
                                 :gsub("%${version}", "0.29.8")
        assert(resolved == url)
        print(platform .. "/" .. arch .. " " .. entry.sha256[arch])
    end
end
''')
        assert dict(line.split() for line in output.splitlines()) == HASHES

    @pytest.mark.static
    def test_lua_syntax(self):
        luac = shutil.which("luac5.4") or shutil.which("luac")
        if not luac:
            pytest.skip("luac is unavailable")
        result = subprocess.run([luac, "-p", str(ROOT / PKG_FILE)],
                                capture_output=True, text=True, timeout=20)
        assert result.returncode == 0, result.stderr

    @pytest.mark.static
    @pytest.mark.parametrize("missing", [False, True])
    def test_raw_payload_hooks(self, missing):
        _lua(r'''
function import() end
local files, chmod, added, removed = {}, false, false, false
pkginfo = {
    install_dir = function() return "/isolated home/headscale/0.29.8" end,
    install_file = function() return "/cache/headscale_0.29.8_linux_amd64" end,
}
fs = { mkdir_p = function(p) assert(p == pkginfo.install_dir()) end }
os.tryrm = function(p) assert(p == pkginfo.install_dir()) end
os.mv = function(src, dst)
    assert(src == pkginfo.install_file())
    assert(dst == pkginfo.install_dir() .. "/headscale")
    if arg[2] ~= "missing" then files[dst] = true end
end
os.isfile = function(p) return files[p] == true end
system = { exec = function(cmd)
    assert(cmd == 'chmod +x "/isolated home/headscale/0.29.8/headscale"')
    chmod = true
end }
xvm = {
    add = function(name, options)
        assert(name == "headscale" and options.bindir == pkginfo.install_dir())
        added = true
    end,
    remove = function(name) assert(name == "headscale"); removed = true end,
}
dofile(arg[1])
assert(not installed())
local ok, err = pcall(install)
if arg[2] == "missing" then
    assert(not ok and tostring(err):find("executable missing", 1, true))
    assert(not installed())
else
    assert(ok and installed() and chmod)
    assert(config() and added)
    assert(uninstall() and removed)
end
''', "missing" if missing else "present")


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_boundaries(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text()
        imports = re.findall(r'import\("([^"]+)"\)', source)
        assert imports and all(name.startswith("xim.libxpkg.") for name in imports)
        assert not re.search(r"\b(?:path\.|is_host\(|os\.(?:host|execv|curdir)\(|raise\()", source)
        hooks = source[source.index('import("xim.libxpkg.fs")'):]
        assert not re.search(r"\b(?:systemctl|launchctl|service|sudo|useradd)\b", hooks)
        assert "/etc/" not in hooks and "/var/" not in hooks


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        _xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in _xlings("search", PKG, "--agent")


@SUPPORTED
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        _xlings("install", under_test(PKG, version), "--yes", "--agent")
        assert _shim().is_file()


@SUPPORTED
class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        result = _headscale("version", "--output", "json")
        assert result.returncode == 0, result.stdout + result.stderr
        info = json.loads(result.stdout)
        assert info["version"].removeprefix("v") == os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert info["dirty"] is False

    @pytest.mark.verify
    def test_offline_completion(self, tmp_path):
        result = _headscale("completion", "bash", cwd=tmp_path)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "__headscale" in result.stdout
        assert "complete" in result.stdout
        assert list(tmp_path.iterdir()) == []

    @pytest.mark.verify
    def test_reject_malformed_config_without_state(self, tmp_path):
        # A valid configtest constructs a server and may create keys/database.
        # Exercise only YAML rejection, before server construction or networking.
        config = tmp_path / "invalid.yaml"
        config.write_text("disable_check_updates: true\nnoise: [\n", encoding="utf-8")
        result = _headscale("--config", str(config), "configtest", cwd=tmp_path)
        output = result.stdout + result.stderr
        assert result.returncode != 0
        assert "error loading config file" in output and "yaml" in output.lower(), output
        assert list(tmp_path.iterdir()) == [config]
