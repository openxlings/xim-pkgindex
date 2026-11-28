"""Tests for the step package."""
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
    assert_platform_supported,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "step"
PKG_FILE = "pkgs/s/step.lua"
VERSION = "0.31.0"
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
    def test_supported_platforms(self, meta):
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_architecture_mapping_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        assert meta.programs == ["step"]
        _run_lua(
            r'''
import = function() end
assert(loadfile(arg[1]))()
local ver = arg[2]
assert(package.spec == "2", "spec must be 2")
assert(package.ci and package.ci.mirror == true, "ci.mirror must be true")
assert(package.xvm_enable == true, "xvm_enable must be true")
assert(package.programs and #package.programs == 1 and package.programs[1] == "step")

local au = assert(package.extensions and package.extensions.autoupdate, "missing extensions.autoupdate")
assert(au.source == "https://github.com/smallstep/cli/releases")
assert(au.resources and au.resources.GLOBAL and au.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { x86_64 = "amd64", aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}
local seen_filenames = {}
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform], "missing xpm." .. platform)
    assert(not p.deps, "static binary should not declare runtime deps on " .. platform)
    local version = assert(p.latest and p.latest.ref, "missing latest.ref: " .. platform)
    assert(version == ver)
    local entry = assert(p[version], "missing version entry: " .. platform)
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias and entry.arch_alias[arch] == alias, platform .. "/" .. arch)
        local sha = assert(entry.sha256 and entry.sha256[arch], "missing sha256: " .. platform .. "/" .. arch)
        assert(type(sha) == "string" and #sha == 64 and sha:match("^[0-9a-f]+$"), platform .. "/" .. arch)
        local auto = assert(au.resources.GLOBAL.url[platform] and au.resources.GLOBAL.url[platform][arch])
        assert(auto:find("${tag}", 1, true) and auto:find("${version}", 1, true),
               "autoupdate template must use ${tag} and ${version}: " .. platform .. "/" .. arch)
        assert(not auto:find("${arch_alias}", 1, true),
               "autoupdate template must not use runtime placeholder ${arch_alias}: " .. platform .. "/" .. arch)
        local auto_resolved = auto:gsub("%${tag}", "v" .. version):gsub("%${version}", version)
        local xpm_resolved = p.source:gsub("%${version}", version):gsub("%${arch_alias}", alias)
        assert(auto_resolved == xpm_resolved,
               "installer/updater URLs disagree: " .. platform .. "/" .. arch)
        local filename = xpm_resolved:match("([^/]+)$")
        assert(not seen_filenames[filename], "duplicate asset filename: " .. filename)
        seen_filenames[filename] = true
        count = count + 1
    end
    for arch in pairs(entry.sha256) do
        assert(arches[arch], "unexpected arch: " .. arch)
    end
end
assert(count == 6)
''',
            PKG_FILE,
            VERSION,
        )

    @pytest.mark.static
    def test_hooks_via_payload_module_posix(self):
        for plat, archive in [
            ("linux", f"/cache/step_linux_{VERSION}_amd64.tar.gz"),
            ("macosx", f"/cache/step_darwin_{VERSION}_arm64.tar.gz"),
        ]:
            _run_lua(
                r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
assert(loadfile(arg[1]))()

local plat = arg[2]
local archive_path = arg[3]
local ver = arg[4]
local files, dirs, moved, xvm_adds, xvm_rms = {}, {}, {}, {}, {}
dirs["/cache/step_" .. ver] = true

pkginfo = {
    name = function() return "step" end,
    version = function() return ver end,
    install_file = function() return archive_path end,
    install_dir = function() return "/xpkgs/step/" .. ver end,
}
os.host = function() return plat end
os.isfile = function(p) return files[p] == true end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p) dirs[p] = nil end
os.mv = function(src, dst)
    table.insert(moved, {src, dst})
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/bin/step"] = true
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
assert(#moved == 1 and moved[1][1] == "/cache/step_" .. ver and moved[1][2] == "/xpkgs/step/" .. ver)
assert(installed())

files["/xpkgs/step/" .. ver .. "/bin/step"] = nil
assert(not installed(), "accepted missing bin/step")
files["/xpkgs/step/" .. ver .. "/bin/step"] = true
files["/xpkgs/step/" .. ver .. "/LICENSE"] = nil
assert(not installed(), "accepted missing LICENSE")
files["/xpkgs/step/" .. ver .. "/LICENSE"] = true

assert(config())
assert(#xvm_adds == 1)
assert(xvm_adds[1][1] == "step" and xvm_adds[1][2].bindir == "/xpkgs/step/" .. ver .. "/bin")

assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "step")
''',
                PKG_FILE,
                plat,
                archive,
                VERSION,
            )

    @pytest.mark.static
    def test_hooks_via_payload_module_windows(self):
        _run_lua(
            r'''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
assert(loadfile(arg[1]))()

local ver = arg[2]
local files, dirs, execs, xvm_adds, xvm_rms = {}, {}, {}, {}, {}

pkginfo = {
    name = function() return "step" end,
    version = function() return ver end,
    install_file = function() return "C:/cache/step_windows_" .. ver .. "_amd64.zip" end,
    install_dir = function() return "C:/xpkgs/step/" .. ver end,
}
os.host = function() return "windows" end
os.getenv = function(k) return k == "SystemRoot" and "C:\\Windows" or nil end
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
        files["C:/xpkgs/step/" .. ver .. "/bin/step.exe"] = true
        files["C:/xpkgs/step/" .. ver .. "/LICENSE"] = true
    end,
}

assert(not installed())
assert(install())
assert(#execs == 1)
assert(execs[1]:match('^C:\\Windows\\System32\\tar%.exe %-xf "C:\\cache\\step_windows_0%.31%.0_amd64%.zip" %-%-strip%-components=1 %-C "C:\\xpkgs\\step\\0%.31%.0"$'))
assert(installed())

assert(config())
assert(#xvm_adds == 1)
assert(xvm_adds[1][1] == "step" and xvm_adds[1][2].bindir == "C:/xpkgs/step/" .. ver .. "/bin")

assert(uninstall())
assert(#xvm_rms == 1 and xvm_rms[1] == "step")
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
        src = (REPO_ROOT / PKG_FILE).read_text(encoding="utf-8")
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
        assert_install_succeeds(under_test(PKG), timeout=120)


class TestVerify:
    def _step_bin(self) -> str:
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS", "current")
        bindir = Path(xlings_home()) / "subos" / subos / "bin"
        if not bindir.is_dir():
            bindir = Path(xlings_home()) / "subos" / os.environ.get("XLINGS_TEST_SUBOS", "default") / "bin"
        shim = bindir / ("step" + suffix)
        if shim.is_file():
            return str(shim)
        found = shutil.which("step")
        assert found, f"Missing installed step shim at {shim} or in PATH"
        return found

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert_command_output(f'"{self._step_bin()}" version', contains=f"Smallstep CLI/{expected}")
        assert_command_output(f'"{self._step_bin()}" --version', contains=f"Smallstep CLI/{expected}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_help_and_non_interactive(self):
        assert_command_output(f'"{self._step_bin()}" --help', contains="plumbing for distributed systems")
        proc = subprocess.run(
            [self._step_bin(), "/?"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert proc.returncode != 0
        assert "No help topic" in (proc.stdout + proc.stderr)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos = "current" if (Path(xlings_home()) / "subos" / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        suffix = ".exe" if os.name == "nt" else ""
        subos = os.environ.get("XLINGS_TEST_SUBOS")
        if subos:
            shim = Path(xlings_home()) / "subos" / subos / "bin" / ("step" + suffix)
            assert shim.is_file(), f"shim not found at {shim}"
        else:
            assert_xvm_shim_exists(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_certificate_create_and_inspect(self, tmp_path):
        cert = tmp_path / "test.crt"
        key = tmp_path / "test.key"
        step_bin = self._step_bin()

        create_proc = subprocess.run(
            [
                step_bin,
                "certificate",
                "create",
                "test.local",
                str(cert),
                str(key),
                "--profile",
                "self-signed",
                "--subtle",
                "--no-password",
                "--insecure",
            ],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        assert cert.is_file() and cert.stat().st_size > 0
        assert key.is_file() and key.stat().st_size > 0
        assert "saved" in (create_proc.stdout + create_proc.stderr)

        inspect_proc = subprocess.run(
            [step_bin, "certificate", "inspect", str(cert), "--short"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )
        assert "test.local" in inspect_proc.stdout
        assert "ECDSA" in inspect_proc.stdout
