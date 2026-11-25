"""Tests for the buf package."""
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

PKG = "buf"
PKG_FILE = "pkgs/b/buf.lua"


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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_all_platforms_and_arches_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["buf"]
        _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)
local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/bufbuild/buf/releases")
local global_url = assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.url)

local expected_aliases = {
    linux = { x86_64 = "x86_64", aarch64 = "aarch64" },
    macosx = { x86_64 = "x86_64", aarch64 = "arm64" },
    windows = { x86_64 = "x86_64", aarch64 = "arm64" },
}

for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == "1.75.0")
    local ver = assert(section["1.75.0"], "missing 1.75.0 in " .. plat)
    assert(ver.arch_alias)
    assert(ver.arch_alias.x86_64 == expected_aliases[plat].x86_64)
    assert(ver.arch_alias.aarch64 == expected_aliases[plat].aarch64)
    assert(ver.sha256)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(ver.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(global_url[plat] and type(global_url[plat][arch]) == "string")
    end
end
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_posix(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
dirs["/cache/buf"] = true

pkginfo = {
    name = function() return "buf" end,
    version = function() return "1.75.0" end,
    install_file = function() return "/cache/buf-Linux-x86_64.tar.gz" end,
    install_dir = function() return "/xpkgs/buf/1.75.0" end,
}
os.host = function() return "linux" end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/bin/buf"] = true
    files[dst .. "/bin/protoc-gen-buf-lint"] = true
    files[dst .. "/bin/protoc-gen-buf-breaking"] = true
    files[dst .. "/LICENSE"] = true
end
log = { info = function() end }
fs = { mkdir_p = function() end }
xvm = {
    add = function(name, opts) table.insert(xvm_adds, {name, opts}) end,
    remove = function(name) table.insert(xvm_rms, name) end,
}

assert(not installed())
assert(install())
assert(#moved == 1 and moved[1][1] == "/cache/buf" and moved[1][2] == "/xpkgs/buf/1.75.0")
assert(installed())

files["/xpkgs/buf/1.75.0/bin/protoc-gen-buf-lint"] = nil
assert(not installed(), "accepted missing protoc-gen-buf-lint")
files["/xpkgs/buf/1.75.0/bin/protoc-gen-buf-lint"] = true
files["/xpkgs/buf/1.75.0/LICENSE"] = nil
assert(not installed(), "accepted missing LICENSE")
files["/xpkgs/buf/1.75.0/LICENSE"] = true

assert(config())
assert(#xvm_adds == 3)
assert(xvm_adds[1][1] == "buf" and xvm_adds[1][2].bindir == "/xpkgs/buf/1.75.0/bin")
assert(xvm_adds[2][1] == "protoc-gen-buf-lint" and xvm_adds[2][2].binding == "buf@1.75.0")
assert(xvm_adds[3][1] == "protoc-gen-buf-breaking" and xvm_adds[3][2].binding == "buf@1.75.0")
assert(uninstall())
assert(#xvm_rms == 3)
''',
            PKG_FILE,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_windows(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "buf" end,
    version = function() return "1.75.0" end,
    install_file = function() return "C:/cache/buf-Windows-x86_64.zip" end,
    install_dir = function() return "C:/xpkgs/buf/1.75.0" end,
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
        files["C:/xpkgs/buf/1.75.0/bin/buf.exe"] = true
        files["C:/xpkgs/buf/1.75.0/bin/protoc-gen-buf-lint.exe"] = true
        files["C:/xpkgs/buf/1.75.0/bin/protoc-gen-buf-breaking.exe"] = true
        files["C:/xpkgs/buf/1.75.0/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\buf%-Windows%-x86_64%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\buf\\\\1%.75%.0"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 3)
assert(xvm_adds[1][1] == "buf" and xvm_adds[1][2].bindir == "C:/xpkgs/buf/1.75.0/bin")
assert(uninstall())
assert(#xvm_rms == 3)
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
            "xim.libxpkg.pkginfo",
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
    def _run_buf(self, *args):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("buf" + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        result = subprocess.run(
            [str(shim), *args],
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
        out = self._run_buf("--version")
        expected = os.environ.get("XLINGS_TEST_VERSION", "1.75.0")
        assert expected in out, out

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("buf")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_lint_proto(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            (root / "buf.yaml").write_text("version: v2\n", encoding="utf-8")
            proto_dir = root / "hello" / "v1"
            proto_dir.mkdir(parents=True)
            (proto_dir / "hello.proto").write_text(
                'syntax = "proto3";\n\npackage hello.v1;\n\nmessage HelloRequest {\n  string name = 1;\n}\n',
                encoding="utf-8",
            )
            out = self._run_buf("lint", str(root))
            assert out.strip() == "", out
