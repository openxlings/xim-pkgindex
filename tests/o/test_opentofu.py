"""Tests for the opentofu package (`tofu` CLI)."""
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

PKG = "opentofu"
PKG_FILE = "pkgs/o/opentofu.lua"


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

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_all_platforms_and_arches_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["tofu"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "opentofu")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/opentofu/opentofu/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)

for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "1.13.10")
    local ver = assert(section["1.13.10"], "missing 1.13.10 in " .. plat)
    assert(ver.arch_alias and ver.arch_alias.x86_64 == "amd64" and ver.arch_alias.aarch64 == "arm64")
    assert(ver.sha256)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        local tpl = assert(global_url[plat] and global_url[plat][arch], "missing autoupdate url for " .. plat .. "/" .. arch)
        assert(tpl:find("${tag}", 1, true) and tpl:find("${version}", 1, true), "missing ${tag}/${version} in " .. tpl)
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_posix_tar_and_group_registration(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
files["/cache/tofu_1.13.10_linux_amd64.tar.gz"] = true

pkginfo = {
    name = function() return "opentofu" end,
    version = function() return "1.13.10" end,
    install_file = function() return "/cache/tofu_1.13.10_linux_amd64.tar.gz" end,
    install_dir = function() return "/xpkgs/opentofu/1.13.10" end,
}
os.host = function() return "linux" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function(p) dirs[p] = true end }
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        if cmd:match("^tar %-xzf ") then
            files["/xpkgs/opentofu/1.13.10/tofu"] = true
            files["/xpkgs/opentofu/1.13.10/LICENSE"] = true
        end
    end,
}
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#execs == 2)
assert(execs[1] == 'tar -xzf "/cache/tofu_1.13.10_linux_amd64.tar.gz" -C "/xpkgs/opentofu/1.13.10"')
assert(execs[2] == 'chmod +x "/xpkgs/opentofu/1.13.10/tofu"')
assert(installed())

files["/xpkgs/opentofu/1.13.10/tofu"] = nil
assert(not installed(), "accepted missing tofu binary")
files["/xpkgs/opentofu/1.13.10/tofu"] = true
files["/xpkgs/opentofu/1.13.10/LICENSE"] = nil
assert(not installed(), "accepted missing LICENSE")
files["/xpkgs/opentofu/1.13.10/LICENSE"] = true

assert(config())
assert(#xvm_adds == 2)
assert(xvm_adds[1][1] == "tofu" and xvm_adds[1][2].bindir == "/xpkgs/opentofu/1.13.10")
assert(xvm_adds[2][1] == "opentofu" and xvm_adds[2][2].type == "group")

assert(uninstall())
assert(#xvm_rms == 2)
assert(xvm_rms[1] == "tofu" and xvm_rms[2] == "opentofu")
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_windows_zip_via_payload_module(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "opentofu" end,
    version = function() return "1.13.10" end,
    install_file = function() return "C:/cache/tofu_1.13.10_windows_amd64.zip" end,
    install_dir = function() return "C:/xpkgs/opentofu/1.13.10" end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\\\Windows" or nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}
system = {
    exec = function(cmd)
        table.insert(execs, cmd)
        files["C:/xpkgs/opentofu/1.13.10/tofu.exe"] = true
        files["C:/xpkgs/opentofu/1.13.10/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\tofu_1%.13%.10_windows_amd64%.zip" %-C "C:\\\\xpkgs\\\\opentofu\\\\1%.13%.10"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 2)
assert(xvm_adds[1][1] == "tofu" and xvm_adds[1][2].bindir == "C:/xpkgs/opentofu/1.13.10")
assert(xvm_adds[2][1] == "opentofu" and xvm_adds[2][2].type == "group")

assert(uninstall())
assert(#xvm_rms == 2)
assert(xvm_rms[1] == "tofu" and xvm_rms[2] == "opentofu")
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
    def _run_tofu(self, *args, cwd=None):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("tofu" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout + result.stderr

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        out = self._run_tofu("version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "1.13.10")
        assert f"OpenTofu v{expected}" in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("tofu")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_init_validate_and_apply_offline(self):
        with tempfile.TemporaryDirectory() as work:
            tf = Path(work) / "main.tf"
            tf.write_text(
                'locals {\n  greeting = "hello"\n}\noutput "msg" {\n  value = local.greeting\n}\n',
                encoding="utf-8",
            )
            self._run_tofu("init", "-backend=false", "-no-color", cwd=work)
            val_out = self._run_tofu("validate", "-no-color", cwd=work)
            assert "Success! The configuration is valid." in val_out, val_out
            apply_out = self._run_tofu("apply", "-auto-approve", "-no-color", cwd=work)
            assert 'msg = "hello"' in apply_out, apply_out
