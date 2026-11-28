"""Tests for the standalone Tailwind CSS CLI (no Node.js/npm required)."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "tailwindcss"
PKG_FILE = "pkgs/t/tailwindcss.lua"
VERSION = "4.3.5"
REPO = Path(__file__).resolve().parents[2]


def _run_xlings(*args: str, timeout: int = 180) -> str:
    """Never invoke a login shell, which can overwrite an isolated XLINGS_HOME."""
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for index and lifecycle checks"
    result = subprocess.run(
        [command, *args], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=timeout,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def _run_lua(script: str) -> str:
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua is required for hook and resource mapping checks")
    result = subprocess.run(
        [lua, "-", PKG_FILE], input=script, cwd=REPO,
        capture_output=True, text=True, timeout=15,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def _subos() -> Path:
    root = Path(xlings_home()) / "subos"
    configured = os.environ.get("XLINGS_TEST_SUBOS")
    if configured:
        return root / configured
    return root / ("current" if (root / "current").is_dir() else "default")


def _binary() -> str:
    executable = _subos() / "bin" / (PKG + (".exe" if os.name == "nt" else ""))
    assert executable.is_file(), f"Missing installed Tailwind CSS shim: {executable}"
    return str(executable)


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
        assert_config_registers_package_name(meta)
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_verified_matrix_and_updater(self):
        _run_lua(r'''
import = function() end
assert(loadfile(arg[1]))()
assert(package.name == "tailwindcss")
assert(package.ci.mirror == true and package.xvm_enable == true)
assert(#package.programs == 1 and package.programs[1] == "tailwindcss")
assert(package.licenses[1] == "MIT")
local auto = assert(package.extensions.autoupdate)
assert(auto.source == "https://github.com/tailwindlabs/tailwindcss/releases")
assert(auto.resources.CN == nil, "unverified CN mirrors must not be declared")
assert(auto.resources.GLOBAL.required == true)
local expected = {
    linux = { x86_64 = "linux-x64", aarch64 = "linux-arm64" },
    macosx = { x86_64 = "macos-x64", aarch64 = "macos-arm64" },
    windows = { x86_64 = "windows-x64.exe" },
}
local count = 0
for platform, arches in pairs(expected) do
    local resource = assert(package.xpm[platform])
    assert(resource.latest.ref == "4.3.5")
    local entry = assert(resource["4.3.5"])
    for arch, asset in pairs(arches) do
        local digest = assert(entry.sha256[arch])
        assert(#digest == 64 and digest:match("^[0-9a-f]+$"))
        local url = resource.source:gsub("%${version}", "4.3.5")
            :gsub("%${arch_alias}", assert(entry.arch_alias[arch]))
        assert(url == "https://github.com/tailwindlabs/tailwindcss/releases/download/v4.3.5/tailwindcss-" .. asset)
        local template = assert(auto.resources.GLOBAL.url[platform][arch])
        assert(template:gsub("%${tag}", "v4.3.5") == url)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unexpected architecture") end
end
assert(count == 5)
assert(package.xpm.windows["4.3.5"].sha256.aarch64 == nil)
assert(package.xpm.linux.deps.runtime[1] == "xim:glibc@>=2.39")
assert(package.xpm.linux.deps.runtime[2] == "xim:gcc-runtime@15.1.0")
''')

    @pytest.mark.static
    def test_raw_install_and_lifecycle_hooks(self):
        _run_lua(r'''
import = function() end
assert(loadfile(arg[1]))()
local files, chmods, added, removed = {}, {}, {}, {}
local source = "/cache/tailwindcss-linux-x64"
local dir = "/isolated/tailwindcss/4.3.5"
local drop_copy = false
pkginfo = { install_file = function() return source end, install_dir = function() return dir end }
fs = { mkdir_p = function(path) assert(path == dir) end }
os.isfile = function(path) return files[path] == true end
os.cp = function(src, dst)
    assert(src == source and files[src], "copy must use the downloaded raw file")
    if not drop_copy then files[dst] = true end
end
system = { exec = function(command) table.insert(chmods, command) end }
xvm = {
    add = function(name, opts) table.insert(added, name); assert(opts.bindir == dir) end,
    remove = function(name) table.insert(removed, name) end,
}
for _, windows in ipairs({false, true}) do
    source = windows and "/cache/tailwindcss-windows-x64.exe" or "/cache/tailwindcss-linux-x64"
    local target = dir .. (windows and "/tailwindcss.exe" or "/tailwindcss")
    files = { [source] = true }
    chmods = {}
    assert(not installed(), "an empty directory is not installed")
    assert(install())
    assert(files[target] and files[source], "preserve the cached upstream binary")
    assert(installed())
    assert(#chmods == (windows and 0 or 1))
    if not windows then assert(chmods[1] == 'chmod +x "' .. target .. '"') end
    assert(config() and uninstall())
end
assert(#added == 2 and added[1] == "tailwindcss" and added[2] == "tailwindcss")
assert(#removed == 2 and removed[1] == "tailwindcss" and removed[2] == "tailwindcss")
files = {}
local ok = pcall(install)
assert(not ok, "a missing download must fail installation")
files[source] = true
drop_copy = true
ok = pcall(install)
assert(not ok, "missing installed executable must not report success")
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_contract(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', source)) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo",
            "xim.libxpkg.system", "xim.libxpkg.xvm",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|os\.execv\(|os\.curdir\(|raise\(|core\.)', source)


class TestIndex:
    @pytest.mark.index
    def test_register(self):
        _run_xlings("config", "--add-xpkg", str(REPO / PKG_FILE), timeout=45)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _run_xlings("install", under_test(PKG), "-y")


class TestVerify:
    @pytest.mark.verify
    def test_help_and_version(self):
        result = subprocess.run(
            [_binary(), "--help"], capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=20,
        )
        output = result.stdout + result.stderr
        assert result.returncode == 0, output
        assert f"v{os.environ.get('XLINGS_TEST_VERSION', VERSION)}" in output, output
        assert "--input" in output and "--output" in output, output

    @pytest.mark.verify
    def test_offline_css_content_build(self, tmp_path):
        (tmp_path / "input.css").write_text(
            '@import "tailwindcss" source(none);\n@source "./index.html";\n',
            encoding="utf-8",
        )
        (tmp_path / "index.html").write_text(
            '<div class="underline p-4 text-red-500">Offline fixture</div>\n',
            encoding="utf-8",
        )
        result = subprocess.run(
            [_binary(), "-i", "input.css", "-o", "output.css", "--minify"],
            cwd=tmp_path, capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        css = (tmp_path / "output.css").read_text(encoding="utf-8")
        for selector in (".underline", ".p-4", ".text-red-500"):
            assert selector in css, css
        assert "text-decoration-line:underline" in css
        assert '@import "tailwindcss"' not in css

    @pytest.mark.verify
    def test_xvm_registration(self):
        config = json.loads((_subos() / ".xlings.json").read_text(encoding="utf-8"))
        assert PKG in config.get("workspace", {}), config
