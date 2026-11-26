"""Tests for the playwright-webkit package."""
import os
from pathlib import Path
import re
import shutil
import subprocess

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

PKG = "playwright-webkit"
PKG_FILE = "pkgs/p/playwright-webkit.lua"
VERSION = "27.2"
REVISION = "2388"
ARCHIVES = ['webkit-ubuntu-22.04.zip', 'webkit-ubuntu-22.04-arm64.zip', 'webkit-mac-15.zip', 'webkit-mac-15-arm64.zip', 'webkit-win64.zip']
EXECUTABLES = ['minibrowser-gtk/MiniBrowser', 'Playwright.app/Contents/MacOS/Playwright', 'Playwright.exe']


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
    def test_matrix_urls_and_checksums(self):
        """Every platform and arch is pinned, GLOBAL is Playwright's CDN, CN is the GitCode copy."""
        out = _run_lua(
            '''
import = function() end
dofile(arg[1])
assert(package.spec == "2")
assert(package.name == "playwright-webkit")
assert(package.xvm_enable == true)
assert(#package.programs == 0, "a GUI browser is not probed by CI")
assert(not (package.ci and package.ci.mirror), "the CN copy already exists, ci.mirror is not declared")
assert(not (package.extensions and package.extensions.autoupdate), "no release feed: manual updates")
local seen = {}
for plat, arches in pairs({linux = {"x86_64", "aarch64"}, macosx = {"x86_64", "aarch64"}, windows = {"x86_64"}}) do
    local section = assert(package.xpm[plat], "missing xpm." .. plat)
    if plat == "linux" then
        assert(section.deps and section.deps.runtime and #section.deps.runtime == 1
               and section.deps.runtime[1] == "xim:libavif@0.9.3", "linux needs xim:libavif@0.9.3")
    else
        assert(not section.deps, plat .. ": the bundle is self-contained")
    end
    assert(section.latest and section.latest.ref == "''' + VERSION + '''")
    local ver = assert(section["''' + VERSION + '''"], "missing version in " .. plat)
    for _, arch in ipairs(arches) do
        local e = assert(ver[arch], "missing " .. plat .. "/" .. arch)
        assert(#e.sha256 == 64 and e.sha256:match("^%x+$"), "bad sha256 " .. plat .. "/" .. arch)
        assert(not seen[e.sha256], "duplicate sha256 " .. plat .. "/" .. arch)
        seen[e.sha256] = true
        local g, c = e.url.GLOBAL, e.url.CN
        assert(g:find("^https://cdn.playwright.dev/builds/"), g)
        local base = g:match("([^/]+)$")
        assert(c == "https://gitcode.com/xlings-res/playwright-webkit/releases/download/''' + VERSION + '''/" .. base, c)
        assert(base:match("%.zip$"), g)
    end
    assert(not ver.windows_aarch64)
end
print("ok")
''',
            PKG_FILE,
        )
        assert out.strip() == "ok"

    @pytest.mark.static
    def test_only_the_declared_platforms(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == []

    @pytest.mark.static
    def test_sha256_count(self, meta):
        shas = re.findall(r'sha256\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(shas) == 5 and len(set(shas)) == 5

    @pytest.mark.static
    def test_each_platform_names_its_executable(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        for rel in EXECUTABLES:
            assert f'"{rel}"' in src, rel

    @pytest.mark.static
    def test_hooks_register_one_shim_and_remove_it(self):
        out = _run_lua(
            '''
import = function() end
payload = { unpack = function() end, require = function() end, present = function() return true end }
shell = { exec = function() end }
local files = {}
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return true end
os.tryrm = function() end
fs = { mkdir_p = function() end }
local adds, rms = {}, {}
xvm = { add = function(n, o) adds[#adds + 1] = { n = n, o = o } end, remove = function(n) rms[#rms + 1] = n end }
pkginfo = {
    name = function() return "playwright-webkit" end,
    version = function() return "''' + VERSION + '''" end,
    install_file = function() return "/cache/x.zip" end,
    install_dir = function() return "/xpkgs/playwright-webkit/''' + VERSION + '''" end,
}
dofile(arg[1])
-- pick each platform's executable in turn
local layouts = {}
for rel in string.gmatch(arg[2], "[^|]+") do layouts[#layouts + 1] = rel end
for _, rel in ipairs(layouts) do
    files = {}
    files["/xpkgs/playwright-webkit/''' + VERSION + '''/" .. rel] = true
    for extra in string.gmatch(arg[3] or "", "[^|]+") do
        files["/xpkgs/playwright-webkit/''' + VERSION + '''/" .. extra] = true
    end
    assert(installed() == true, rel)
    adds = {}
    assert(config() == true)
    assert(#adds == 1 and adds[1].n == "playwright-webkit", rel)
    assert(adds[1].o.alias == rel:match("([^/]+)$"), rel)
end
files = {}
assert(installed() == false)
rms = {}
assert(uninstall() == true and #rms == 1 and rms[1] == "playwright-webkit")
print("ok")
''',
            PKG_FILE,
            "|".join(EXECUTABLES),
            "minibrowser-gtk/sys/lib/libavif.so.13",
        )
        assert out.strip() == "ok"


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
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=300)


class TestVerify:
    def _shim(self):
        suffix = ".exe" if os.name == "nt" else ""
        bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "current") / "bin"
        if not bindir.is_dir():
            bindir = bindir.parent.parent / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / (PKG + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)
        self._shim()

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_payload_has_the_launchers_and_libavif(self):
        # MiniBrowser's closure beyond libavif (GTK 4, GStreamer, ...) is the host's, so the
        # browser is not opened here; the payload and the one supplied library are checked.
        self._shim()
        install = Path(xlings_home()) / "data" / "xpkgs"
        found = list(install.glob("*-x-" + PKG + "/*/minibrowser-gtk/MiniBrowser"))
        assert found, "minibrowser-gtk/MiniBrowser missing from the install directory"
        root = found[0].parents[1]
        assert (root / "pw_run.sh").is_file()
        assert (root / "protocol.json").is_file()
        link = root / "minibrowser-gtk" / "sys" / "lib" / "libavif.so.13"
        assert link.is_file(), "libavif.so.13 is not linked into sys/lib"
        env = dict(os.environ)
        env["LD_LIBRARY_PATH"] = f"{root}/minibrowser-gtk/lib:{root}/minibrowser-gtk/sys/lib"
        out = subprocess.run(["ldd", str(root / "minibrowser-gtk" / "bin" / "MiniBrowser")],
                             capture_output=True, text=True, env=env).stdout
        missing = [l for l in out.splitlines() if "not found" in l]
        assert not any("libavif" in l or "libaom" in l for l in missing), missing
