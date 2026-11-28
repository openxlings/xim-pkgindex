"""Portable minikube CLI tests; never create a cluster or invoke a driver."""
import os
from pathlib import Path
import re
import shutil
import subprocess

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

PKG = "minikube"
PKG_FILE = "pkgs/m/minikube.lua"
VERSION = "1.39.0"
ROOT = Path(__file__).resolve().parents[2]


def _lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    subprocess.run(
        [lua, "-", PKG_FILE], input=script, cwd=ROOT,
        text=True, capture_output=True, check=True, timeout=30,
    )


def _xlings(*args):
    # Native argv invocation deliberately avoids login-shell startup files,
    # which may override the caller's disposable XLINGS_HOME.
    command = shutil.which("xlings")
    if not command:
        pytest.skip("xlings is unavailable")
    result = subprocess.run(
        [command, *args], cwd=ROOT, text=True, capture_output=True, timeout=300,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "[error]" not in result.stdout + result.stderr
    return result.stdout + result.stderr


def _binary():
    suffix = ".exe" if os.name == "nt" else ""
    home = Path(xlings_home())
    for subos in ("current", "default"):
        binary = home / "subos" / subos / "bin" / (PKG + suffix)
        if binary.is_file():
            return binary
    pytest.fail("minikube xvm shim is missing")


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)
        assert_config_registers_package_name(meta)
        assert_valid_xvm_node_kinds(meta)
        assert meta.spec == "2"
        assert meta.programs == [PKG]
        assert set(meta.platforms) == {"linux", "macosx", "windows"}

    @pytest.mark.static
    def test_exact_resource_matrix_and_updater(self):
        _lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.xvm_enable and package.ci.mirror)
assert(table.concat(package.archs, ",") == "x86_64,aarch64")
local expected = {
    linux = {
        x86_64 = {"amd64", "b738496da01be06bbaf80c688f57ce25acd3849fbb518155f3a88e03ef555aa4"},
        aarch64 = {"arm64", "202f331cb677761c5aec81c58472d16d65707358b9f66226210be3fe3275b1c3"},
    },
    macosx = {
        x86_64 = {"amd64", "12247c653b6f1b58ac7bb634f6d1e31a1d33f7c63a6f99cbdaef160de15d2175"},
        aarch64 = {"arm64", "78ad8f2f3b35a81e9c2501b1a65961c1521aa4c76fbbe1b5409053db49e29bcd"},
    },
    windows = {
        x86_64 = {"amd64", "776386465ded2cf610ae397fe302de32c44d12134b5ce7ce98ab05bd7713b360"},
    },
}
local au = assert(package.extensions.autoupdate)
assert(au.source == "https://github.com/kubernetes/minikube/releases")
assert(au.resources.GLOBAL.required and not au.resources.CN)
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    assert(p.latest.ref == "1.39.0" and not p.deps)
    local release = assert(p["1.39.0"])
    for arch, values in pairs(arches) do
        assert(release.arch_alias[arch] == values[1])
        assert(release.sha256[arch] == values[2])
        local actual = p.source:gsub("%${version}", "1.39.0"):gsub("%${arch_alias}", values[1])
        local upstream_os = platform == "macosx" and "darwin" or platform
        local filename = "minikube-" .. upstream_os .. "-" .. values[1] .. (platform == "windows" and ".exe" or "")
        assert(actual == "https://github.com/kubernetes/minikube/releases/download/v1.39.0/" .. filename)
        local auto = assert(au.resources.GLOBAL.url[platform][arch])
        assert(auto:gsub("%${tag}", "v1.39.0") == actual)
        count = count + 1
    end
    for arch in pairs(release.sha256) do assert(arches[arch]) end
    for arch in pairs(au.resources.GLOBAL.url[platform]) do assert(arches[arch]) end
end
assert(count == 5)
''')

    @pytest.mark.static
    def test_hooks_only_install_and_route_the_cli(self):
        _lua(r'''
local files, dirs, commands, registrations = {}, {}, {}, {}
local src, dest
function import(name)
    assert(name:match("^xim%.libxpkg%."))
end
fs = {mkdir_p = function(p) dirs[p] = true end}
pkginfo = {
    install_file = function() return src end,
    install_dir = function() return dest end,
}
system = {exec = function(cmd) table.insert(commands, cmd) end}
xvm = {
    add = function(name, opts) table.insert(registrations, {"add", name, opts}) end,
    remove = function(name) table.insert(registrations, {"remove", name}) end,
}
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.tryrm = function(p)
    for f in pairs(files) do
        if f:sub(1, #p + 1) == p .. "/" then files[f] = nil end
    end
end
os.mv = function(from, to)
    assert(files[from])
    files[from], files[to] = nil, true
end
assert(loadfile(arg[1]))()
for _, case in ipairs({
    {"/downloads/windows-name/minikube-linux-amd64", "/store/minikube", "minikube", 1},
    {"/downloads/minikube-darwin-arm64", "/store/minikube", "minikube", 1},
    {"C:\\downloads\\minikube-windows-amd64.exe", "C:/store/minikube", "minikube.exe", 0},
}) do
    files, dirs, commands = {}, {}, {}
    src, dest = case[1], case[2]
    assert(not installed())
    files[src] = true
    assert(install())
    assert(dirs[dest] and files[dest .. "/" .. case[3]])
    assert(#commands == case[4])
    if case[4] == 1 then
        assert(commands[1] == 'chmod +x "' .. dest .. '/minikube"')
    end
    assert(installed())
    files[dest .. "/" .. case[3]] = nil
    assert(not installed())
end
assert(config() and uninstall())
assert(#registrations == 2)
assert(registrations[1][1] == "add" and registrations[1][2] == "minikube")
assert(registrations[1][3].bindir == dest)
assert(registrations[2][1] == "remove" and registrations[2][2] == "minikube")
files = {}
assert(not pcall(install), "missing download must fail")
files[src] = true
os.mv = function() end
assert(not pcall(install), "missing installed payload must fail")
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_and_public_api_only(self):
        for assertion in (
            assert_no_exec_xvm, assert_no_bashrc_modification,
            assert_no_direct_path_modification, assert_no_direct_pkg_manager,
            assert_uses_new_api,
        ):
            assertion(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text()
        assert all(name.startswith("xim.libxpkg.") for name in re.findall(r'import\("([^"]+)"\)', source))
        assert not re.search(r'\b(?:path\.|is_host\(|os\.(?:host|execv|curdir)\(|raise\(|core\.)', source)
        hooks = source[source.index("function installed()") :]
        assert not re.search(r'(?:system\.exec|os\.exec)\([^\n]*(?:start|driver|docker|sudo|kubectl)', hooks)


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        _xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in _xlings("search", PKG)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install_payload_and_route(self):
        _xlings("install", under_test(PKG, VERSION), "-y")
        assert _binary().is_file()
        stores = list((Path(xlings_home()) / "data" / "xpkgs").glob(f"*-x-{PKG}/{VERSION}"))
        assert stores, "installation directory missing"
        suffix = ".exe" if os.name == "nt" else ""
        assert any((store / (PKG + suffix)).is_file() for store in stores)


class TestVerify:
    @pytest.mark.verify
    def test_version_and_disposable_configuration(self, tmp_path):
        env = os.environ.copy()
        env.update({
            "MINIKUBE_HOME": str(tmp_path / "minikube"),
            "KUBECONFIG": str(tmp_path / "kubeconfig"),
            "MINIKUBE_WANTUPDATENOTIFICATION": "false",
            "MINIKUBE_WANTREPORTERRORPROMPT": "false",
        })
        version = subprocess.run(
            [str(_binary()), "version", "--short"], env=env,
            text=True, capture_output=True, check=True, timeout=30,
        )
        assert version.stdout.strip() == "v" + VERSION
        config = subprocess.run(
            [str(_binary()), "config", "view"], env=env,
            text=True, capture_output=True, check=True, timeout=30,
        )
        assert not config.stdout.strip(), "disposable configuration must be empty"
        assert not (tmp_path / "kubeconfig").exists()
        # minikube initializes empty state directories even for read-only CLI
        # commands; no profile or machine payload may have been created.
        for name in ("profiles", "machines"):
            for directory in tmp_path.rglob(name):
                assert directory.is_dir() and not list(directory.iterdir())
