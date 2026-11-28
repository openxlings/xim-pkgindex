"""Official ouch release matrix, isolated lifecycle, and archive functionality."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "ouch"
PKG_FILE = "pkgs/o/ouch.lua"
ROOT = Path(__file__).resolve().parents[2]
VERSION = os.environ.get("XLINGS_TEST_VERSION", "")
RESOURCES = {
    "linux": {
        "x86_64": ("ouch-x86_64-unknown-linux-musl.tar.gz",
                   "eaab9b997a823f584557ac5f85205105ae577a4c4fbd23926b686469cfa19881"),
        "aarch64": ("ouch-aarch64-unknown-linux-musl.tar.gz",
                    "4619158de69e65e8d23147c3d8b46b116feb0259c8a1704df7d792394c2b5847"),
    },
    "macosx": {
        "x86_64": ("ouch-x86_64-apple-darwin.tar.gz",
                   "c97188f4c09fb959ea0d3117781ae524431b62fcd8f1b8d19323550773cd438a"),
        "aarch64": ("ouch-aarch64-apple-darwin.tar.gz",
                    "969c1bd9105b5033cc9cac0a37c011d23482948d681b43f97c6f79311f3263d0"),
    },
    "windows": {
        "x86_64": ("ouch-x86_64-pc-windows-msvc.zip",
                   "6383a95987894412d5c9c4172e3d1d87c86aa322acb2b7ffcad42f492abc5dfe"),
        "aarch64": ("ouch-aarch64-pc-windows-msvc.zip",
                    "2ffacd22c03a5a73cf4084ef8d70f13788268dfa7148242ad9fc5002e167c4c7"),
    },
}


def run_lua(source):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to evaluate the package declaration"
    return subprocess.run([lua, "-", PKG_FILE], input=source, cwd=ROOT,
                          text=True, capture_output=True, check=True, timeout=30)


def isolated_env():
    home = Path(xlings_home()).resolve()
    user_home = Path(os.environ.get("XPKG_ISOLATED_USER_HOME", home / "user-home"))
    subos = os.environ.get("XLINGS_TEST_SUBOS") or (
        "current" if (home / "subos" / "current").is_dir() else "default"
    )
    env = os.environ.copy()
    env.update({
        "HOME": str(user_home),
        "XLINGS_HOME": str(home),
        "XLINGS_BIN": str(home / "subos" / subos / "bin"),
        "XLINGS_SUBOS_LIB": str(home / "subos" / subos / "lib"),
    })
    env["PATH"] = os.pathsep.join((str(home / "bin"), str(home / "subos" / subos / "bin"), env.get("PATH", "")))
    return env


def run_xlings(*args):
    env = isolated_env()
    # Prefer the native CLI installed in the isolated XLINGS_HOME, otherwise
    # use the already installed CLI from PATH without invoking a login shell.
    suffix = ".exe" if os.name == "nt" else ""
    candidate = Path(env["XLINGS_HOME"]) / "bin" / ("xlings" + suffix)
    command = str(candidate) if candidate.is_file() else shutil.which("xlings", path=env["PATH"])
    assert command, "xlings is required for lifecycle checks"
    result = subprocess.run([command, *args], env=env, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=240)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def executable():
    suffix = ".exe" if os.name == "nt" else ""
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    candidates = [subos] if subos else ["current", "default"]
    for name in candidates:
        shim = base / name / "bin" / (PKG + suffix)
        if shim.is_file():
            resolved = shim.resolve()
            assert Path(xlings_home()).resolve() in resolved.parents, resolved
            return str(shim)
    pytest.fail("Missing ouch shim under the isolated XLINGS_HOME")


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
        assert meta.name == PKG and meta.programs == [PKG]
        assert re.search(r'licenses\s*=\s*\{"MIT",\s*"LGPL-3\.0-only",\s*"LicenseRef-UnRAR"\}', meta.raw_content)

    @pytest.mark.static
    def test_official_release_matrix_and_updater(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
local expected = {
    linux = {
        x86_64 = {"ouch-x86_64-unknown-linux-musl.tar.gz", "eaab9b997a823f584557ac5f85205105ae577a4c4fbd23926b686469cfa19881"},
        aarch64 = {"ouch-aarch64-unknown-linux-musl.tar.gz", "4619158de69e65e8d23147c3d8b46b116feb0259c8a1704df7d792394c2b5847"},
    },
    macosx = {
        x86_64 = {"ouch-x86_64-apple-darwin.tar.gz", "c97188f4c09fb959ea0d3117781ae524431b62fcd8f1b8d19323550773cd438a"},
        aarch64 = {"ouch-aarch64-apple-darwin.tar.gz", "969c1bd9105b5033cc9cac0a37c011d23482948d681b43f97c6f79311f3263d0"},
    },
    windows = {
        x86_64 = {"ouch-x86_64-pc-windows-msvc.zip", "6383a95987894412d5c9c4172e3d1d87c86aa322acb2b7ffcad42f492abc5dfe"},
        aarch64 = {"ouch-aarch64-pc-windows-msvc.zip", "2ffacd22c03a5a73cf4084ef8d70f13788268dfa7148242ad9fc5002e167c4c7"},
    },
}
local updates = package.extensions.autoupdate
assert(updates.source == "https://github.com/ouch-org/ouch/releases")
assert(updates.resources.CN == nil)
assert(updates.resources.GLOBAL.required == true)
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    assert(p[p.latest.ref], "latest must resolve to a declared release")
    local entry = assert(p["0.8.3"])
    for arch, record in pairs(arches) do
        local asset, digest = record[1], record[2]
        assert(entry.sha256[arch] == digest)
        assert(#digest == 64 and digest:match("^[a-f0-9]+$"))
        local url = p.source:gsub("%${version}", "0.8.3"):gsub("%${arch}", arch)
        assert(url == "https://github.com/ouch-org/ouch/releases/download/0.8.3/" .. asset, url)
        assert(updates.resources.GLOBAL.url[platform][arch]:gsub("%${version}", "0.8.3") == url)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unexpected binary architecture") end
    for arch in pairs(updates.resources.GLOBAL.url[platform]) do assert(arches[arch], "unexpected updater architecture") end
end
assert(count == 6)
assert(package.licenses[1] == "MIT" and package.licenses[2] == "LGPL-3.0-only")
assert(package.licenses[3] == "LicenseRef-UnRAR")
''')

    @pytest.mark.static
    def test_archive_layout_and_hooks(self):
        names = [asset for arches in RESOURCES.values() for asset, _ in arches.values()]
        lua_names = ",\n".join(f'"{name}"' for name in names)
        run_lua(f'''
function import() end
assert(loadfile(arg[1]))()
local archive, windows, files = "", false, {{}}
pkginfo = {{
    install_dir = function() return "/isolated/ouch" end,
    install_file = function() return archive end,
}}
os.getenv = function(name) return name == "OS" and (windows and "Windows_NT" or nil) or nil end
os.isfile = function(p) return files[p] == true end
payload = {{
    unpack = function(opt)
        local basename = archive:match("([^/]+)$")
        local extracted = basename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
        assert(opt.extracted == extracted and opt.strip == 1)
        files = {{}}
        for _, f in ipairs({{windows and "ouch.exe" or "ouch", "LICENSE", "README.md"}}) do
            files["/isolated/ouch/" .. f] = true
        end
    end,
    present = function(wanted)
        for _, f in ipairs(wanted) do
            if not files["/isolated/ouch/" .. f] then return false end
        end
        return true
    end,
}}
payload.require = function(wanted) assert(payload.present(wanted)) end
xvm = {{
    add = function(name, opt) assert(name == "ouch" and opt.bindir == "/isolated/ouch") end,
    remove = function(name) assert(name == "ouch") end,
}}
for _, filename in ipairs({{{lua_names}}}) do
    archive = "/download/" .. filename
    windows = filename:match("windows%-msvc%.zip$") ~= nil
    assert(install() and installed() and config() and uninstall())
    files["/isolated/ouch/README.md"] = nil
    assert(not installed(), "incomplete archive must not count as installed")
end
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_compliance(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text()
        imports = re.findall(r'import\("([^"]+)"\)', source)
        assert set(imports) == {"xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload"}
        assert not re.search(r'\b(?:path\.|os\.(?:host|curdir|execv)\(|is_host\(|raise\()', source)
        assert "system.exec" not in source and "os.exec" not in source


class TestIndex:
    @pytest.mark.index
    def test_register(self):
        run_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in run_xlings("search", under_test(PKG), "--agent")


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install_reinstall_uninstall(self):
        package = under_test(PKG, VERSION)
        run_xlings("install", package, "--yes", "--agent")
        shim = Path(executable())
        assert shim.is_file()
        run_xlings("install", package, "--yes", "--agent")
        assert shim.is_file()
        run_xlings("remove", package, "--yes", "--agent")
        assert not shim.exists()


class TestVerify:
    @pytest.mark.verify
    def test_compress_and_decompress_round_trip(self):
        run_xlings("install", under_test(PKG, VERSION), "--yes", "--agent")
        command = executable()
        content = b"ouch round trip\x00 with binary bytes\n" * 4096
        with tempfile.TemporaryDirectory(prefix="ouch-verify-") as tmp:
            root = Path(tmp)
            source = root / "payload.txt"
            archive = root / "payload.tar.gz"
            restored = root / "restored"
            source.write_bytes(content)
            subprocess.run([command, "compress", str(source), str(archive), "--yes"],
                           check=True, capture_output=True, text=True, timeout=60)
            assert archive.is_file() and archive.stat().st_size > 0
            subprocess.run([command, "decompress", str(archive), "--dir", str(restored), "--yes"],
                           check=True, capture_output=True, text=True, timeout=60)
            assert (restored / "payload.txt").read_bytes() == content
