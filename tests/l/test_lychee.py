"""Tests for the lychee package."""
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
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "lychee"
PKG_FILE = "pkgs/l/lychee.lua"
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


@pytest.fixture(scope="module")
def code(meta):
    return "\n".join(
        line for line in meta.raw_content.splitlines()
        if not line.lstrip().startswith("--")
    )


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
    def test_expected_platforms(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}

    @pytest.mark.static
    def test_no_forbidden_xmake_apis(self, code):
        for pat in (r"\bpath\.", r"\bos\.host\s*\(", r"\bis_host\s*\(", r"\btry\s*\{", r"\braise\s*\("):
            assert not re.search(pat, code), f"forbidden xmake API pattern matched: {pat}"

    @pytest.mark.static
    def test_resource_matrix_and_autoupdate_parity(self):
        _run_lua(
            r'''
import = function() end
assert(loadfile(arg[1]))()
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "lychee")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/lycheeverse/lychee/releases")
assert(auto.tag == "lychee-v${version}")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

local expected = {
    linux = { arches = { "x86_64", "aarch64" }, ext = "tar.gz" },
    macosx = { arches = { "x86_64", "aarch64" }, ext = "tar.gz" },
    windows = { arches = { "x86_64" }, ext = "zip" },
}
local count = 0
local seen_filenames = {}

for platform, spec in pairs(expected) do
    local p = assert(package.xpm[platform], "missing platform: " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest.ref: " .. platform)
    assert(version == "0.24.2", platform .. " latest should be 0.24.2")
    local entry = assert(p[version], "missing version entry: " .. platform)
    local arch_set = {}
    for _, arch in ipairs(spec.arches) do
        arch_set[arch] = true
        local sum = assert(entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sum) == "string" and #sum == 64 and sum:match("^[0-9a-f]+$"),
               "invalid sha256: " .. platform .. "/" .. arch)
        local xpm_resolved = p.source
            :gsub("%${version}", version)
            :gsub("%${arch}", arch)
            :gsub("%${ext}", spec.ext)
        local tag = auto.tag:gsub("%${version}", version)
        local auto_tpl = assert(global_url[platform] and global_url[platform][arch],
                                "missing autoupdate url: " .. platform .. "/" .. arch)
        local auto_resolved = auto_tpl:gsub("%${tag}", tag):gsub("%${version}", version)
        assert(auto_resolved == xpm_resolved,
               "installer/updater URLs disagree for " .. platform .. "/" .. arch)
        local filename = xpm_resolved:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arch_set[arch], "unexpected arch in " .. platform .. ": " .. arch)
    end
end
assert(count == 5, "expected 5 platform/arch assets")
assert(package.xpm.linux.deps == nil, "musl static Linux binaries should not declare runtime deps")
local win_deps = assert(package.xpm.windows.deps and package.xpm.windows.deps.runtime)
assert(#win_deps == 1 and win_deps[1] == "xim:vcruntime")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_behavior_in_lua_sandbox(self):
        _run_lua(
            r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
system = {}
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
local cur_install_file = ""
local cur_install_dir = ""
local vcruntime_dir = "C:/store/xpkgs/xim-x-vcruntime/14.44.35211"

pkginfo = {
    name = function() return "lychee" end,
    version = function() return "0.24.2" end,
    install_file = function() return cur_install_file end,
    install_dir = function() return cur_install_dir end,
    dep_install_dir = function(dep)
        if dep == "xim:vcruntime" then return vcruntime_dir end
        return nil
    end,
}
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    if dirs[src] then
        dirs[src] = nil
        dirs[dst] = true
        local prefix = src .. "/"
        local to_move = {}
        for k, v in pairs(files) do
            if k:sub(1, #prefix) == prefix and v then
                table.insert(to_move, k)
            end
        end
        for _, k in ipairs(to_move) do
            files[k] = nil
            files[dst .. "/" .. k:sub(#prefix + 1)] = true
        end
    end
end
os.cp = function(src, dst)
    local name = src:match("([^/\\]+)$")
    files[dst .. "/" .. name] = true
end
log = { info = function() end }
fs = {
    mkdir_p = function(p) dirs[p] = true end,
    files = function(d)
        if d == vcruntime_dir .. "/bin" then
            return { vcruntime_dir .. "/bin/vcruntime140.dll" }
        end
        return {}
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

-- POSIX case: archive not pre-extracted -> shell.exec runs tar -xzf, payload.unpack moves stem, chmod +x runs
os.host = function() return "linux" end
os.getenv = function() return nil end
cur_install_file = "/tmp/dl/lychee-x86_64-unknown-linux-musl.tar.gz"
cur_install_dir = "/store/xpkgs/xim-x-lychee/0.24.2"
files[cur_install_file] = true
system.exec = function(cmd)
    table.insert(execs, cmd)
    if cmd:match("^'tar' '%-xzf'") then
        dirs["/tmp/dl/lychee-x86_64-unknown-linux-musl"] = true
        files["/tmp/dl/lychee-x86_64-unknown-linux-musl/lychee"] = true
    end
end

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == "'tar' '-xzf' '/tmp/dl/lychee-x86_64-unknown-linux-musl.tar.gz' '-C' '/tmp/dl'")
assert(execs[2] == "'chmod' '+x' '/store/xpkgs/xim-x-lychee/0.24.2/lychee'")
assert(installed())
files[cur_install_dir .. "/lychee"] = nil
assert(not installed(), "installed() must reject missing lychee binary")

-- Windows case: payload.unpack extracts .zip via System32\tar.exe + copies xim:vcruntime DLLs
files, dirs, execs = {}, {}, {}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
cur_install_file = "C:/dl/lychee-x86_64-pc-windows-msvc.zip"
cur_install_dir = "C:/store/xpkgs/xim-x-lychee/0.24.2"
files[cur_install_file] = true
system.exec = function(cmd)
    table.insert(execs, cmd)
    files[cur_install_dir .. "/lychee.exe"] = true
end

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\Windows\\System32\\tar.exe -xf "C:\\dl\\lychee-x86_64-pc-windows-msvc.zip" --strip-components=1 -C "C:\\store\\xpkgs\\xim-x-lychee\\0.24.2"')
assert(installed())
assert(files[cur_install_dir .. "/vcruntime140.dll"] == true, "install() must copy xim:vcruntime DLLs app-local")
files[cur_install_dir .. "/lychee.exe"] = nil
assert(not installed(), "installed() must reject missing lychee.exe")

-- config & uninstall
assert(config())
assert(#xvm_adds == 1 and xvm_adds[1][1] == "lychee" and xvm_adds[1][2].bindir == cur_install_dir)
assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "lychee")
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
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
        }


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    def _lychee_bin(self):
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        candidate = bindir / "lychee"
        if candidate.is_file():
            return str(candidate)
        found = shutil.which("lychee")
        assert found, "lychee binary not found in subos bin or PATH"
        return found

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", "0.24.2")
        assert_command_output("lychee --version", contains=f"lychee {expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_non_blocking(self):
        lychee = self._lychee_bin()
        for arg in ("--help", "/?"):
            res = subprocess.run([lychee, arg], capture_output=True, text=True, timeout=15)
            assert res.returncode == 0, f"{arg} exited with {res.returncode}: {res.stdout}\n{res.stderr}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_offline_markdown_link_check(self, tmp_path):
        lychee = self._lychee_bin()
        target = tmp_path / "target.md"
        target.write_text("# Target\n", encoding="utf-8")
        valid_md = tmp_path / "valid.md"
        valid_md.write_text("# Valid\n\n[target](target.md)\n", encoding="utf-8")
        broken_md = tmp_path / "broken.md"
        broken_md.write_text("# Broken\n\n[missing](missing.md)\n", encoding="utf-8")

        ok = subprocess.run(
            [lychee, "--offline", str(valid_md)],
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert ok.returncode == 0, ok.stdout + ok.stderr

        bad = subprocess.run(
            [lychee, "--offline", str(broken_md)],
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert bad.returncode == 2, f"expected exit code 2 for broken link, got {bad.returncode}: {bad.stdout}\n{bad.stderr}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = Path(xlings_home()) / "subos"
            monkeypatch.setenv(
                "XLINGS_TEST_SUBOS",
                "current" if (subos / "current").is_dir() else "default",
            )
        assert_xvm_registered("lychee")
