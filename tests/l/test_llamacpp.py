"""Tests for the llama.cpp package (ggml-org/llama.cpp CPU inference binaries)."""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "llama.cpp"
PKG_FILE = "pkgs/l/llama.cpp.lua"


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run([lua, "-", *args], input=script, text=True,
                          capture_output=True, check=True).stdout


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
    def test_platforms_deps_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])

assert(package.spec == "2", "spec must be 2")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.programs and #package.programs == 2
       and package.programs[1] == "llama-cli"
       and package.programs[2] == "llama-server")

local linux = assert(package.xpm.linux)
assert(linux.deps and linux.deps.runtime, "linux must declare runtime deps")
local seen = {}
for _, d in ipairs(linux.deps.runtime) do seen[d] = true end
assert(seen["xim:glibc@>=2.39"], "linux must depend on xim:glibc@>=2.39")
assert(seen["xim:gcc-runtime"], "linux must depend on xim:gcc-runtime")
assert(seen["xim:openssl@3.1.5"], "linux must depend on xim:openssl@3.1.5")

local win = assert(package.xpm.windows)
assert(win.deps and win.deps.runtime, "windows must declare runtime deps")
assert(win.deps.runtime[1] == "xim:vcruntime", "windows must depend on xim:vcruntime")

local expected_assets = {
    linux = {
        x86_64 = "llama-b12720-bin-ubuntu-x64.tar.gz",
        aarch64 = "llama-b12720-bin-ubuntu-arm64.tar.gz",
    },
    macosx = {
        x86_64 = "llama-b12720-bin-macos-x64.tar.gz",
        aarch64 = "llama-b12720-bin-macos-arm64.tar.gz",
    },
    windows = {
        x86_64 = "llama-b12720-bin-win-cpu-x64.zip",
    },
}

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/ggml-org/llama.cpp/releases")
local global_au = assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.url)

for plat, arches in pairs(expected_assets) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.latest and p.latest.ref == "b12720", plat .. " latest must ref b12720")
    assert(type(p.source) == "string" and p.source:find("${version}", 1, true),
           plat .. " source must template ${version}")
    local v = assert(p["b12720"], "missing b12720 on " .. plat)
    assert(v.arch_alias and v.arch_alias.x86_64 == "x64", plat .. " x86_64 arch_alias must be x64")
    for arch, asset in pairs(arches) do
        local h = assert(v.sha256 and v.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(h) == "string" and #h == 64 and h:match("^%x+$"),
               "invalid sha256 for " .. plat .. "/" .. arch)
        local expected_url = "https://github.com/ggml-org/llama.cpp/releases/download/b12720/" .. asset
        local resolved = p.source:gsub("${version}", "b12720"):gsub("${arch_alias}", v.arch_alias[arch])
        assert(resolved == expected_url, plat .. "/" .. arch .. " resolved url mismatch: " .. resolved)
        local tmpl = assert(global_au[plat] and global_au[plat][arch],
                            "missing autoupdate template for " .. plat .. "/" .. arch)
        local au_url = tmpl:gsub("${tag}", "b12720"):gsub("${version}", "b12720")
        assert(au_url == expected_url, "autoupdate template mismatch for " .. plat .. "/" .. arch)
    end
end
''', PKG_FILE)

    @pytest.mark.static
    def test_installed_and_install_sandbox(self):
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

-- Case 1: Linux / macOS tarball extracts into `llama-b12720/` with bundled shared libs
local files, dirs, execs = {}, {}, {}
local host = "linux"
local install_file = "/tmp/cache/llama-b12720-bin-ubuntu-x64.tar.gz"
local install_dir = "/tmp/xpkgs/llama.cpp/b12720"
os.host = function() return host end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function() end
os.mv = function(src, dst)
    dirs[src] = nil
    dirs[dst] = true
    local prefix = src .. "/"
    local moved = {}
    for k, v in pairs(files) do
        if k:sub(1, #prefix) == prefix then
            moved[dst .. "/" .. k:sub(#prefix + 1)] = v
            files[k] = nil
        end
    end
    for k, v in pairs(moved) do files[k] = v end
end
fs = { mkdir_p = function() end, files = function() return {} end }
log = { info = function() end }
system = { exec = function(cmd) execs[#execs + 1] = cmd end }
pkginfo = {
    name = function() return "llama.cpp" end,
    version = function() return "b12720" end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
    dep_install_dir = function() return nil end,
}

dirs["/tmp/cache/llama-b12720"] = true
files["/tmp/cache/llama-b12720/llama-cli"] = true
files["/tmp/cache/llama-b12720/llama-server"] = true
files["/tmp/cache/llama-b12720/libllama.so.1"] = true
assert(not installed())
assert(install())
assert(installed())
assert(files["/tmp/xpkgs/llama.cpp/b12720/llama-cli"])
assert(files["/tmp/xpkgs/llama.cpp/b12720/llama-server"])
assert(files["/tmp/xpkgs/llama.cpp/b12720/libllama.so.1"])
assert(#execs == 2 and execs[1]:find("chmod +x", 1, true))

-- Case 2: Windows flat zip uses payload.unpack{extracted = nil} and copies xim:vcruntime DLLs
files, dirs, execs = {}, {}, {}
host = "windows"
install_file = "C:/cache/llama-b12720-bin-win-cpu-x64.zip"
install_dir = "C:/xpkgs/llama.cpp/b12720"
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
pkginfo.dep_install_dir = function(dep)
    assert(dep == "xim:vcruntime")
    return "C:/xpkgs/vcruntime/14.44.35211"
end
local copied = {}
fs.files = function(d)
    if d == "C:/xpkgs/vcruntime/14.44.35211/bin" then
        return { "C:/xpkgs/vcruntime/14.44.35211/bin/crt_a.dll" }
    end
    return {}
end
os.cp = function(src, dst) copied[#copied + 1] = { src, dst } end
system.exec = function(cmd)
    execs[#execs + 1] = cmd
    files["C:/xpkgs/llama.cpp/b12720/llama-cli.exe"] = true
    files["C:/xpkgs/llama.cpp/b12720/llama-server.exe"] = true
end
assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1 and execs[1]:find("System32\\\\tar.exe", 1, true))
assert(#copied == 1 and copied[1][2] == install_dir)
''', PKG_FILE)

    @pytest.mark.static
    def test_config_and_uninstall(self):
        _run_lua('''
import = function() end
dofile(arg[1])
local adds, rms, execs = {}, {}, {}
os.isfile = function(p) return p == "/pkg/libllama.so.1.0.0" or p == "/patchelf/bin/patchelf" end
pkginfo = {
    install_dir = function() return "/pkg" end,
    build_dep = function(dep)
        if dep == "xim:patchelf" then return { bin = "/patchelf/bin" } end
        return nil
    end,
}
system = { exec = function(cmd) table.insert(execs, cmd) end }
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(config())
assert(#execs == 1 and execs[1]:find("/patchelf/bin/patchelf", 1, true))
assert(execs[1]:find("--force-rpath", 1, true))
assert(#adds == 3)
assert(adds[1][1] == "llama-cli" and adds[1][2].bindir == "/pkg")
assert(adds[2][1] == "llama-server" and adds[2][2].bindir == "/pkg")
assert(adds[3][1] == "llama.cpp" and adds[3][2].type == "group")

assert(uninstall())
assert(#rms == 3)
assert(rms[1] == "llama-cli" and rms[2] == "llama-server" and rms[3] == "llama.cpp")
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
    def test_portable_lua_and_libxpkg_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
            "xim.libxpkg.system", "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_llama_cli_version(self):
        assert_command_output("llama-cli --version", contains="build 12720")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_llama_server_version(self):
        assert_command_output("llama-server --version", contains="build 12720")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("llama-cli")
        assert_xvm_registered("llama-server")
        assert_xvm_registered("llama.cpp")
