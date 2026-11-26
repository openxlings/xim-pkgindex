"""Tests for the age package."""
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

PKG = "age"
PKG_FILE = "pkgs/a/age.lua"
VERSION = "1.3.2"
PROGRAMS = [
    "age",
    "age-keygen",
    "age-inspect",
    "age-plugin-batchpass",
    "age-plugin-pq",
    "age-plugin-tag",
    "age-plugin-tagpq",
]


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
    def test_platforms_archs_sha256_and_autoupdate_pinned(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == PROGRAMS
        _run_lua(
            '''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.ci and package.ci.mirror == true)
assert(package.xvm_enable == true)

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/FiloSottile/age/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)
local global_url = assert(auto.resources.GLOBAL.url)

for _, plat in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    assert(section.latest and section.latest.ref == ver)
    local entry = assert(section[ver], "missing " .. ver .. " in " .. plat)
    assert(entry.arch_alias and entry.arch_alias.x86_64 == "amd64")
    assert(entry.arch_alias.aarch64 == "arm64")
    assert(entry.sha256)
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local h = assert(entry.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(#h == 64 and h:match("^%x+$"), "invalid sha256 for " .. plat .. "/" .. arch)
        assert(global_url[plat] and type(global_url[plat][arch]) == "string")
        assert(global_url[plat][arch]:find("${tag}", 1, true))
        assert(global_url[plat][arch]:find("${version}", 1, true))
    end
end
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_posix_linux_and_macosx(self):
        for plat, archive in [
            ("linux", f"/cache/age-v{VERSION}-linux-amd64.tar.gz"),
            ("macosx", f"/cache/age-v{VERSION}-darwin-arm64.tar.gz"),
        ]:
            _run_lua(
                '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local plat = arg[2]
local archive_path = arg[3]
local ver = arg[4]
local bins = {
    "age",
    "age-keygen",
    "age-inspect",
    "age-plugin-batchpass",
    "age-plugin-pq",
    "age-plugin-tag",
    "age-plugin-tagpq",
}

local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
dirs["/cache/age"] = true

pkginfo = {
    name = function() return "age" end,
    version = function() return ver end,
    install_file = function() return archive_path end,
    install_dir = function() return "/xpkgs/age/" .. ver end,
}
os.host = function() return plat end
os.getenv = function() return nil end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    for _, b in ipairs(bins) do
        files[dst .. "/" .. b] = true
    end
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
assert(#moved == 1 and moved[1][1] == "/cache/age" and moved[1][2] == "/xpkgs/age/" .. ver)
assert(installed())

files["/xpkgs/age/" .. ver .. "/age-plugin-tagpq"] = nil
assert(not installed(), "accepted missing age-plugin-tagpq binary")
files["/xpkgs/age/" .. ver .. "/age-plugin-tagpq"] = true
files["/xpkgs/age/" .. ver .. "/LICENSE"] = nil
assert(not installed(), "accepted missing LICENSE")
files["/xpkgs/age/" .. ver .. "/LICENSE"] = true

assert(config())
assert(#xvm_adds == #bins)
assert(xvm_adds[1][1] == "age" and xvm_adds[1][2].bindir == "/xpkgs/age/" .. ver and xvm_adds[1][2].binding == nil)
for i = 2, #bins do
    assert(xvm_adds[i][1] == bins[i])
    assert(xvm_adds[i][2].bindir == "/xpkgs/age/" .. ver)
    assert(xvm_adds[i][2].binding == "age@" .. ver)
end

assert(uninstall())
assert(#xvm_rms == #bins)
assert(xvm_rms[#xvm_rms] == "age")
''',
                PKG_FILE,
                plat,
                archive,
                VERSION,
            )

    @pytest.mark.static
    def test_hooks_windows_zip(self):
        _run_lua(
            '''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])

local ver = arg[2]
local bins = {
    "age",
    "age-keygen",
    "age-inspect",
    "age-plugin-batchpass",
    "age-plugin-pq",
    "age-plugin-tag",
    "age-plugin-tagpq",
}
local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "age" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/age-v" .. ver .. "-windows-amd64.zip" end,
    install_dir = function() return "C:/xpkgs/age/" .. ver end,
}
os.host = function() return "windows" end
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
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
        for _, b in ipairs(bins) do
            files["C:/xpkgs/age/" .. ver .. "/" .. b .. ".exe"] = true
        end
        files["C:/xpkgs/age/" .. ver .. "/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\\\Windows\\\\System32\\\\tar%.exe %-xf "C:\\\\cache\\\\age%-v1%.3%.2%-windows%-amd64%.zip" %-%-strip%-components=1 %-C "C:\\\\xpkgs\\\\age\\\\1%.3%.2"$'))
assert(installed())

assert(config())
assert(#xvm_adds == #bins)
assert(xvm_adds[1][1] == "age" and xvm_adds[1][2].binding == nil)
for i = 2, #bins do
    assert(xvm_adds[i][1] == bins[i] and xvm_adds[i][2].binding == "age@" .. ver)
end

assert(uninstall())
assert(#xvm_rms == #bins)
assert(xvm_rms[#xvm_rms] == "age")
''',
            PKG_FILE,
            VERSION,
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
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    def _shim(self, prog: str) -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / (prog + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_prog(self, prog: str, *args: str) -> str:
        shim = self._shim(prog)
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
    def test_versions(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        for prog in PROGRAMS:
            out = self._run_prog(prog, "--version")
            assert expected in out, f"{prog} --version: {out!r}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        for prog in PROGRAMS:
            assert_xvm_registered(prog)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_keygen_encrypt_inspect_decrypt_roundtrip(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            key_file = root / "key.txt"
            plain_file = root / "plain.txt"
            cipher_file = root / "secret.age"
            out_file = root / "decrypted.txt"

            payload_text = "xlings age roundtrip verification\n"
            plain_file.write_text(payload_text, encoding="utf-8")

            self._run_prog("age-keygen", "-o", str(key_file))
            key_text = key_file.read_text(encoding="utf-8")
            m = re.search(r"#\s*public key:\s*(age1[0-9a-z]+)", key_text)
            assert m, f"Missing public key in age-keygen output: {key_text!r}"
            recipient = m.group(1)

            self._run_prog("age", "-r", recipient, "-o", str(cipher_file), str(plain_file))
            assert cipher_file.is_file() and cipher_file.stat().st_size > 0

            inspect_out = self._run_prog("age-inspect", str(cipher_file))
            assert "X25519" in inspect_out, f"Unexpected age-inspect output: {inspect_out!r}"

            self._run_prog("age", "-d", "-i", str(key_file), "-o", str(out_file), str(cipher_file))
            assert out_file.read_text(encoding="utf-8") == payload_text
