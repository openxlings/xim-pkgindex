"""Tealdeer: pinned portable assets, tldr routing, and offline local rendering."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_valid_xvm_node_kinds,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG_FILE = "pkgs/t/tealdeer.lua"
VERSION = "1.9.1"


def _lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to validate recipe contracts"
    subprocess.run([lua, "-", PKG_FILE], input=script, text=True,
                   capture_output=True, check=True, timeout=15)


def _xlings(*args):
    executable = Path(xlings_home()) / "bin" / ("xlings.exe" if os.name == "nt" else "xlings")
    if not executable.is_file():
        executable = shutil.which("xlings.exe" if os.name == "nt" else "xlings")
    assert executable, "native xlings executable missing"
    return subprocess.run([str(executable), *args], capture_output=True, text=True,
                          env=os.environ.copy(), timeout=180, check=True)


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_valid_xvm_node_kinds(meta)
        assert_no_typos(PKG_FILE)
        assert meta.spec == "2"
        assert meta.programs == ["tldr"]

    @pytest.mark.static
    def test_portable_api_boundary(self, meta):
        code = "\n".join(line for line in meta.raw_content.splitlines()
                         if not line.lstrip().startswith("--"))
        for pattern in (r"\bpath\.", r"\bos\.(host|arch|exists|curdir)\s*\(",
                        r"\bis_host\s*\(", r"\btry\s*\{", r"\braise\s*\("):
            assert not re.search(pattern, code), pattern
        imports = re.findall(r'import\("([^"]+)"\)', code)
        assert all(name.startswith("xim.libxpkg.") or name == "xim.pkgindex.payload"
                   for name in imports)
        assert "--update" not in code
        assert "--seed-config" not in code
        assert "TEALDEER_CONFIG_DIR" not in code
        assert "TEALDEER_CACHE_DIR" not in code

    @pytest.mark.static
    def test_resource_and_update_matrix(self):
        _lua('''
import = function() end
dofile(arg[1])
assert(package.licenses[1] == "MIT" and package.licenses[2] == "Apache-2.0")
assert(package.xvm_enable and package.programs[1] == "tldr")
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/tealdeer-rs/tealdeer/releases")
assert(auto.resources.CN == nil and package.ci == nil)
local expected = {
    linux = { x86_64 = "5a9c3f0691b9cf375ee5c99de802885f3d50498cf686a539e2ddda028eb6b4f6",
              aarch64 = "247746dd2d18f0135da79b849bb6b49e45262e2fe4318adfc3082dc6ce3ee968" },
    macosx = { x86_64 = "06189e82d407d2f3193b9a22d2b6a289a271677142b993af2cee0c2120e12111",
               aarch64 = "5c0a088880d83faf098e2716abbc373a5607addf76a7e1b7ebbe206bde4ebd35" },
    windows = { x86_64 = "f75a3e4b43e7b03d30bac88eccf928af90b8993cd354fe207aec1c643910736f" },
}
for platform, hashes in pairs(expected) do
    local sec = package.xpm[platform]
    assert(sec.latest.ref == "1.9.1")
    for arch, hash in pairs(hashes) do
        assert(sec["1.9.1"].sha256[arch] == hash)
        local url = sec.source:gsub("%${version}", "1.9.1"):gsub("%${arch}", arch)
        local update = auto.resources.GLOBAL.url[platform][arch]:gsub("%${tag}", "v1.9.1")
        assert(url == update, platform .. "/" .. arch)
    end
    for arch in pairs(sec["1.9.1"].sha256) do assert(hashes[arch]) end
    for arch in pairs(auto.resources.GLOBAL.url[platform]) do assert(hashes[arch]) end
end
assert(package.xpm.windows.deps.runtime[1] == "xim:vcruntime")
assert(package.xpm.linux.deps == nil and package.xpm.macosx.deps == nil)
''')

    @pytest.mark.static
    def test_hooks_require_actual_payload(self):
        _lua('''
import = function() end
dofile(arg[1])
local source, dir = "/cache/tealdeer-linux-x86_64-musl", "/packages/tealdeer/1.9.1"
local files, commands, added, removed = {}, {}, nil, nil
pkginfo = {
    install_file = function() return source end,
    install_dir = function() return dir end,
    dep_install_dir = function(name) assert(name == "xim:vcruntime"); return "/runtime" end,
}
os.isfile = function(path) return files[path] == true end
os.tryrm = function() end
os.mv = function(src, dst) assert(files[src]); files[src] = nil; files[dst] = true end
os.cp = function(src, dst) assert(files[src]); files[dst] = true end
fs = {
    mkdir_p = function() end,
    files = function() return {"/runtime/bin/vcruntime140.dll", "/runtime/bin/msvcp140.dll"} end,
}
system = { exec = function(command) commands[#commands + 1] = command end }
payload = {
    present = function(required)
        for _, f in ipairs(required) do if not files[dir .. "/" .. f] then return false end end
        return true
    end,
    require = function(required)
        assert(payload.present(required), "missing payload")
        return true
    end,
}
xvm = {
    add = function(name, opt) added = name; assert(opt.bindir == dir) end,
    remove = function(name) removed = name end,
}
for _, asset in ipairs({"tealdeer-linux-x86_64-musl", "tealdeer-linux-aarch64-musl",
                        "tealdeer-macos-x86_64", "tealdeer-macos-aarch64",
                        "tealdeer-windows-x86_64-msvc.exe"}) do
    files, commands = {}, {}
    source = "/cache/" .. asset
    local windows = asset:match("%.exe$") ~= nil
    local binary = dir .. (windows and "/tldr.exe" or "/tldr")
    files[source], files["/runtime/bin/vcruntime140.dll"], files["/runtime/bin/msvcp140.dll"] = true, true, true
    assert(not installed())
    assert(install() and installed() and files[binary])
    if windows then
        assert(#commands == 0)
        assert(files[dir .. "/msvcp140.dll"])
        files[dir .. "/vcruntime140.dll"] = nil
        assert(not installed(), "missing app-local CRT must invalidate installed()")
    else
        assert(#commands == 1 and commands[1] == 'chmod +x "' .. dir .. '/tldr"')
    end
    files[binary] = nil
    assert(not installed())
    assert(config() and added == "tldr")
    assert(uninstall() and removed == "tldr")
end
fs.files = function() return {} end
assert(not pcall(installed), "empty CRT provider inventory must fail closed")
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_only(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_registration(self):
        _xlings("config", "--add-xpkg", str(Path(PKG_FILE).resolve()))


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _xlings("install", under_test("tealdeer", os.environ.get("XLINGS_TEST_VERSION", VERSION)), "-y")


@pytest.fixture
def tldr_shim():
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS") or (
        "current" if (base / "current" / "bin").is_dir() else "default"
    )
    shim = base / subos / "bin" / ("tldr.exe" if os.name == "nt" else "tldr")
    assert shim.is_file(), f"missing real tldr shim: {shim}"
    return shim


class TestVerify:
    @pytest.mark.verify
    def test_payload_and_version(self, tldr_shim):
        version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        store = Path(xlings_home()) / "data" / "xpkgs"
        payloads = list(store.glob(f"*-x-tealdeer/{version}"))
        assert payloads, "tealdeer payload directory missing"
        required = ["tldr.exe", "vcruntime140.dll"] if os.name == "nt" else ["tldr"]
        if os.name == "nt":
            providers = list(store.glob("*-x-vcruntime/*/bin"))
            assert providers, "CRT provider payload missing"
            runtime_files = [file.name for file in providers[0].iterdir() if file.is_file()]
            assert "vcruntime140.dll" in runtime_files
            required.extend(runtime_files)
        assert any(all((root / f).is_file() for f in required) for root in payloads)
        proc = subprocess.run([str(tldr_shim), "--version"], capture_output=True,
                              text=True, timeout=20, check=True)
        assert f"tealdeer {version}" in proc.stdout

    @pytest.mark.verify
    def test_offline_render(self, tldr_shim, tmp_path):
        page = tmp_path / "xlings-proof.md"
        page.write_text("# xlings-proof\n\n> Render a local example without a cache.\n\n"
                        "- Print the isolated fixture:\n\n`printf {{portable-proof}}`\n",
                        encoding="utf-8")
        config = tmp_path / "config.toml"
        config.write_text("[updates]\nauto_update = false\n", encoding="utf-8")
        cache = tmp_path / "cache"
        env = os.environ.copy()
        env.update(TEALDEER_CONFIG_DIR=str(tmp_path / "config"),
                   TEALDEER_CACHE_DIR=str(cache), NO_COLOR="1", PAGER="")
        proc = subprocess.run(
            [str(tldr_shim), "--config-path", str(config), "--no-auto-update",
             "--color", "never", "--render", str(page)],
            env=env, capture_output=True, text=True, timeout=20, check=True,
        )
        assert "Render a local example without a cache." in proc.stdout
        assert "Print the isolated fixture:" in proc.stdout
        assert "printf portable-proof" in proc.stdout
        assert not cache.exists() or not any(cache.rglob("*.md")), "unexpected page-cache download"
