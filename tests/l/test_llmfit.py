"""llmfit resources, isolated hooks, and offline embedded-catalog verification."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type, assert_no_typos,
    assert_platform_supported, assert_valid_xvm_node_kinds, assert_no_exec_xvm,
    assert_no_bashrc_modification, assert_no_direct_path_modification,
    assert_uses_new_api, assert_no_direct_pkg_manager, assert_xim_add_succeeds,
    assert_install_succeeds, assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home

PKG = "llmfit"
PKG_FILE = "pkgs/l/llmfit.lua"
REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_lua(script: str) -> None:
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    subprocess.run(
        [lua, "-", PKG_FILE], input=script, text=True, capture_output=True,
        check=True, cwd=REPO_ROOT,
    )


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert meta.spec == "2"
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)
        assert_valid_xvm_node_kinds(meta)
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_six_target_resources_and_autoupdate(self):
        _run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.name == "llmfit" and package.spec == "2")
assert(package.ci.mirror == true and package.xvm_enable == true)
assert(#package.programs == 1 and package.programs[1] == "llmfit")
assert(#package.archs == 2 and package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
local auto = assert(package.extensions.autoupdate)
assert(auto.source == "https://github.com/AlexsJones/llmfit/releases")
assert(auto.resources.CN == nil)
assert(auto.resources.GLOBAL.required == true)
local targets = {
    linux = "unknown-linux-musl.tar.gz",
    macosx = "apple-darwin.tar.gz",
    windows = "pc-windows-msvc.zip",
}
local count = 0
for platform, target in pairs(targets) do
    local p = assert(package.xpm[platform])
    assert(p.deps == nil)
    local version = assert(p.latest.ref)
    assert(version == "1.1.21")
    local entry = assert(p[version])
    for _, arch in ipairs(package.archs) do
        local hash = assert(entry.sha256[arch])
        assert(#hash == 64 and hash:match("^[0-9a-f]+$"))
        local expected = "https://github.com/AlexsJones/llmfit/releases/download/v" .. version
            .. "/llmfit-v" .. version .. "-" .. arch .. "-" .. target
        local url = p.source:gsub("%${version}", version):gsub("%${arch}", arch)
        assert(url == expected, url)
        local update = assert(auto.resources.GLOBAL.url[platform][arch])
        update = update:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        assert(update == expected, update)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arch == "x86_64" or arch == "aarch64") end
end
assert(count == 6)
''')

    @pytest.mark.static
    def test_payload_and_hook_contracts(self):
        _run_lua(r'''
function import() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
system = {}
shell = assert(loadfile("libs/shell.lua"))()
local files, dirs, execs, calls = {}, {}, {}, {}
local archive, dest, host, incomplete
pkginfo = {
    name = function() return "llmfit" end,
    install_file = function() return archive end,
    install_dir = function() return dest end,
}
os.host = function() return host end
os.getenv = function(k) return k == "SystemRoot" and "C:\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(d)
    dirs[d] = nil
    for p in pairs(files) do if p:sub(1, #d + 1) == d .. "/" then files[p] = nil end end
end
os.mv = function(src, dst)
    assert(dirs[src])
    dirs[src], dirs[dst] = nil, true
    local moved = {}
    for p in pairs(files) do
        if p:sub(1, #src + 1) == src .. "/" then
            moved[dst .. p:sub(#src + 1)] = true
            files[p] = nil
        end
    end
    for p in pairs(moved) do files[p] = true end
end
fs = { mkdir_p = function(d) dirs[d] = true end }
log = { info = function() end }
system.exec = function(cmd)
    execs[#execs + 1] = cmd
    if host == "windows" then
        files[dest .. "/llmfit.exe"] = true
        files[dest .. "/README.md"] = true
        if not incomplete then files[dest .. "/LICENSE"] = true end
    end
end
xvm = {
    add = function(name, opts) calls[#calls + 1] = {"add", name, opts} end,
    remove = function(name) calls[#calls + 1] = {"remove", name} end,
}
assert(loadfile(arg[1]))()
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        files, dirs, execs = {}, {}, {}
        host = platform
        local target = platform == "linux" and "unknown-linux-musl"
            or (platform == "macosx" and "apple-darwin" or "pc-windows-msvc")
        local stem = "llmfit-v1.1.21-" .. arch .. "-" .. target
        archive = (host == "windows" and "C:/dl/" or "/tmp/dl/") .. stem
            .. (host == "windows" and ".zip" or ".tar.gz")
        dest = host == "windows" and "C:/store/llmfit/1.1.21" or "/store/llmfit/1.1.21"
        local exe = host == "windows" and "llmfit.exe" or "llmfit"
        if host ~= "windows" then
            local src = "/tmp/dl/" .. stem
            dirs[src] = true
            for _, f in ipairs({exe, "LICENSE", "README.md"}) do files[src .. "/" .. f] = true end
        end
        assert(not installed())
        assert(install() and installed())
        assert(#execs == 1)
        if host == "windows" then
            assert(execs[1]:find("C:\\Windows\\System32\\tar.exe", 1, true) == 1)
            assert(execs[1]:find("--strip-components=1", 1, true))
        else
            assert(execs[1] == "'chmod' '+x' '/store/llmfit/1.1.21/llmfit'")
        end
        for _, f in ipairs({exe, "LICENSE", "README.md"}) do
            files[dest .. "/" .. f] = nil
            assert(not installed(), "missing " .. f .. " must invalidate installed()")
            files[dest .. "/" .. f] = true
        end
    end
end
assert(config())
assert(#calls == 1 and calls[1][1] == "add" and calls[1][2] == "llmfit")
assert(calls[1][3].bindir == dest)
assert(uninstall())
assert(#calls == 2 and calls[2][1] == "remove" and calls[2][2] == "llmfit")
incomplete = true
local ok, err = pcall(install)
assert(not ok and tostring(err):find("LICENSE", 1, true), "missing payload must fail by name")
archive = ""
assert(not pcall(install), "empty install_file must fail")
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_isolation(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) == {
            "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|try\s*\{|raise\()', src)


class TestIndex:
    @pytest.mark.index
    def test_register(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    @staticmethod
    def _shim() -> str:
        suffix = ".exe" if os.name == "nt" else ""
        subos = Path(xlings_home()) / "subos"
        names = (os.environ.get("XLINGS_TEST_SUBOS", "current"), "default")
        for name in names:
            shim = subos / name / "bin" / (PKG + suffix)
            if shim.is_file():
                return str(shim)
        pytest.fail(f"Missing isolated llmfit xvm shim below {subos}")

    @pytest.mark.verify
    def test_version(self):
        proc = subprocess.run([self._shim(), "--version"], capture_output=True,
                              text=True, check=True, timeout=10)
        assert f"llmfit {os.environ.get('XLINGS_TEST_VERSION', '1.1.21')}" in proc.stdout

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            root = Path(xlings_home()) / "subos"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if (root / "current").is_dir() else "default")
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_offline_model_catalog(self):
        # `list` reads the embedded catalog: no GPU, model downloads, provider
        # connections, hardware probing or dashboard server are needed.
        with tempfile.TemporaryDirectory() as tmp:
            env = {**os.environ, "HOME": tmp, "USERPROFILE": tmp,
                   "XDG_CONFIG_HOME": tmp, "XDG_DATA_HOME": tmp,
                   "XDG_CACHE_HOME": tmp}
            proc = subprocess.run(
                [self._shim(), "list", "--json", "--no-cluster", "--no-dashboard"],
                stdin=subprocess.DEVNULL, capture_output=True, text=True,
                encoding="utf-8", env=env, check=True, timeout=15,
            )
        models = json.loads(proc.stdout)
        assert isinstance(models, list) and models
        assert all(isinstance(m.get("name"), str) and m["name"] for m in models)
        assert any("qwen" in m["name"].lower() for m in models)
        assert all(m["context_length"] > 0 and m["min_ram_gb"] > 0 for m in models)
