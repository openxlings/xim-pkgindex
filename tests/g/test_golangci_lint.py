"""Tests for the golangci-lint package."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_config_registers_package_name,
    assert_valid_xvm_node_kinds,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "golangci-lint"
PKG_FILE = "pkgs/g/golangci-lint.lua"
REPO = Path(__file__).resolve().parents[2]


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    res = subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        cwd=REPO,
    )
    assert res.returncode == 0, f"Lua exited {res.returncode}:\n{res.stderr}\n{res.stdout}"
    return res.stdout


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
dofile(arg[1])
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
assert(package.programs and #package.programs == 1 and package.programs[1] == "golangci-lint")

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/golangci/golangci-lint/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)
assert(auto.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}

local count = 0
for plat, arches in pairs(expected) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    local version = assert(section.latest and section.latest.ref, "missing latest.ref in " .. plat)
    assert(version == "2.15.0", plat .. " latest should be 2.15.0")
    local tag = "v" .. version
    local ver = assert(section[version], "missing " .. version .. " in " .. plat)
    for arch, alias in pairs(arches) do
        assert(ver.arch_alias[arch] == alias, plat .. "/" .. arch .. " alias mismatch")
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tmpl = assert(global_url[plat] and global_url[plat][arch])
        local resolved_au = tmpl:gsub("%${tag}", tag):gsub("%${version}", version)
        local resolved_xpm = section.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(resolved_au == resolved_xpm, "autoupdate/xpm URL mismatch for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(ver.sha256) do
        assert(arches[arch], "unexpected arch " .. arch .. " in " .. plat)
    end
end
assert(count == 6)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_posix_and_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local function populate(root, exe, files)
    files[root .. "/" .. exe] = true
    files[root .. "/LICENSE"] = true
    files[root .. "/README.md"] = true
end

-- 1. POSIX pre-extracted wrapper directory moved by payload.unpack
local files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
dirs["/cache/golangci-lint-2.15.0-linux-amd64"] = true
pkginfo = {
    name = function() return "golangci-lint" end,
    version = function() return "2.15.0" end,
    install_file = function() return "/cache/golangci-lint-2.15.0-linux-amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/golangci-lint/2.15.0" end,
}
os.host = function() return "linux" end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(mvs, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    populate(dst, "golangci-lint", files)
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xzf") then
            populate("/xpkgs/golangci-lint/2.15.0", "golangci-lint", files)
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
assert(install())
assert(#mvs == 1 and mvs[1][1] == "/cache/golangci-lint-2.15.0-linux-amd64" and mvs[1][2] == "/xpkgs/golangci-lint/2.15.0")
assert(#execs == 1 and execs[1] == 'chmod +x "/xpkgs/golangci-lint/2.15.0/golangci-lint"')
assert(installed())

files["/xpkgs/golangci-lint/2.15.0/README.md"] = nil
assert(not installed(), "accepted missing README.md")
files["/xpkgs/golangci-lint/2.15.0/README.md"] = true

assert(config())
assert(#adds == 1 and adds[1][1] == "golangci-lint" and adds[1][2].bindir == "/xpkgs/golangci-lint/2.15.0")
assert(uninstall())
assert(#rms == 1 and rms[1] == "golangci-lint")

-- 2. POSIX archive fallback when pre-extracted dir is absent
files, dirs, mvs, execs = {}, {}, {}, {}
files["/cache/golangci-lint-2.15.0-linux-amd64.tar.gz"] = true
assert(install())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/golangci-lint-2.15.0-linux-amd64.tar.gz" --strip-components=1 -C "/xpkgs/golangci-lint/2.15.0"')
assert(execs[2] == 'chmod +x "/xpkgs/golangci-lint/2.15.0/golangci-lint"')
assert(installed())

-- 3. Windows .zip via libs/payload.lua (System32\\tar.exe with --strip-components=1)
files, dirs, mvs, execs, adds, rms = {}, {}, {}, {}, {}, {}
pkginfo = {
    name = function() return "golangci-lint" end,
    version = function() return "2.15.0" end,
    install_file = function() return "C:/cache/golangci-lint-2.15.0-windows-amd64.zip" end,
    install_dir = function() return "C:/xpkgs/golangci-lint/2.15.0" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
files["C:/cache/golangci-lint-2.15.0-windows-amd64.zip"] = true
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        populate("C:/xpkgs/golangci-lint/2.15.0", "golangci-lint.exe", files)
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\golangci-lint-2.15.0-windows-amd64.zip" --strip-components=1 -C "C:\\\\xpkgs\\\\golangci-lint\\\\2.15.0"')
assert(installed())
assert(config())
assert(#adds == 1 and adds[1][1] == "golangci-lint" and adds[1][2].bindir == "C:/xpkgs/golangci-lint/2.15.0")
assert(uninstall())
assert(#rms == 1 and rms[1] == "golangci-lint")

-- 4. Missing archive and extracted directory must fail
files, dirs = {}, {}
local ok = pcall(install)
assert(not ok, "install() must fail when neither extracted directory nor archive exists")
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
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs",
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.system",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    def _run_golangci_lint(self, *args, check_rc=0):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("golangci-lint" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        out = result.stdout + result.stderr
        if check_rc is not None:
            assert result.returncode == check_rc, f"rc={result.returncode}: {out}"
        return result.returncode, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        _, out = self._run_golangci_lint("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "2.15.0")
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("golangci-lint")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_config_verify_and_linters_offline(self):
        _, linters_out = self._run_golangci_lint("linters")
        assert "errcheck" in linters_out, linters_out

        with tempfile.TemporaryDirectory() as work:
            valid_cfg = Path(work) / "valid.yml"
            valid_cfg.write_text('version: "2"\nlinters:\n  default: standard\n', encoding="utf-8")
            self._run_golangci_lint("config", "verify", "-c", str(valid_cfg))

            bad_cfg = Path(work) / "bad.yml"
            bad_cfg.write_text('version: "2"\nunknown_key: true\n', encoding="utf-8")
            rc, bad_out = self._run_golangci_lint("config", "verify", "-c", str(bad_cfg), check_rc=None)
            assert rc != 0, f"expected non-zero exit on invalid config, got {rc}: {bad_out}"
