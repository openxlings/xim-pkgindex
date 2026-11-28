"""Official portable scc resources and native source-counting lifecycle."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "scc"
PKG_FILE = "pkgs/s/scc.lua"
ROOT = Path(__file__).resolve().parents[2]


def run_lua(source):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to evaluate the package declaration"
    return subprocess.run([lua, "-", PKG_FILE], input=source, cwd=ROOT,
                          text=True, capture_output=True, check=True, timeout=30)


def run_xlings(*args):
    # Native argv avoids login-shell startup overriding an isolated XLINGS_HOME.
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for lifecycle checks"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def shim_path():
    suffix = ".exe" if os.name == "nt" else ""
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    for name in ([subos] if subos else ["current", "default"]):
        directory = base / name / "bin"
        if directory.is_dir():
            return directory / (PKG + suffix)
    pytest.fail("Missing active subos bin directory")


def assert_counts(tmp_path):
    source = tmp_path / "sample.py"
    source.write_text('# A comment\n\nprint("hello")\nanswer = 42\n', encoding="utf-8")
    result = subprocess.run([str(shim_path()), "--format", "json", str(source)],
                            cwd=tmp_path, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    counts = json.loads(result.stdout)
    assert len(counts) == 1, counts
    python = counts[0]
    assert {key: python[key] for key in ("Name", "Count", "Lines", "Code", "Blank", "Comment")} == {
        "Name": "Python", "Count": 1, "Lines": 4, "Code": 2, "Blank": 1, "Comment": 1,
    }


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_valid_xvm_node_kinds(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_resources_and_updater(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2" and package.name == "scc")
assert(package.licenses[1] == "MIT" and package.programs[1] == "scc")
assert(package.xvm_enable and package.ci.mirror)
local expected = {
    linux = { os = "Linux", ext = ".tar.gz", hashes = {
        x86_64 = "c7328436d3027f4357d3d7853f7dc3ac2bbcb4ca08f1adad91a27c593884079b",
        aarch64 = "6e0d2a1f8d3540ba7df185477dec40bb7340f1b214bfd303147de5cad2bd7b8b",
    } },
    macosx = { os = "Darwin", ext = ".tar.gz", hashes = {
        x86_64 = "7f705031228add7e55edded409179a60de6b538d41f153ba2922dee95adda50d",
        aarch64 = "7201c7aa4aace058d43308462cba72adb18f6094c08c0741727455976d0a0747",
    } },
    windows = { os = "Windows", ext = ".zip", hashes = {
        x86_64 = "4a433984f45ff29c94eeb3af6db5b511c58f5bf74063dccedafcbf473cb8ff31",
        aarch64 = "fdc1188bec07ab46fd391686c404abcd0bed92fffb5f1bb03aa9050dd7bc7f15",
    } },
}
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/boyter/scc/releases")
assert(auto.resources.CN == nil)
local count = 0
for platform, wanted in pairs(expected) do
    local p = assert(package.xpm[platform])
    assert(p.latest.ref == "4.1.0")
    local entry = assert(p["4.1.0"])
    for arch, hash in pairs(wanted.hashes) do
        assert(entry.sha256[arch] == hash)
        local alias = arch == "aarch64" and "arm64" or "x86_64"
        assert(entry.arch_alias[arch] == alias)
        local url = p.source:gsub("%${version}", "4.1.0"):gsub("%${arch_alias}", alias)
        assert(url == "https://github.com/boyter/scc/releases/download/v4.1.0/scc_"
            .. wanted.os .. "_" .. alias .. wanted.ext)
        assert(auto.resources.GLOBAL.url[platform][arch]:gsub("%${tag}", "v4.1.0") == url)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(wanted.hashes[arch]) end
    for arch in pairs(auto.resources.GLOBAL.url[platform]) do assert(wanted.hashes[arch]) end
end
assert(count == 6)
assert(#package.archs == 2 and package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
''')

    @pytest.mark.static
    def test_installed_requires_complete_payload(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
pkginfo = { install_dir = function() return "/isolated/scc" end }
payload = assert(loadfile("libs/payload.lua"))()
local files = {}
os.isfile = function(p) return files[p] == true end
for _, exe in ipairs({"scc", "scc.exe"}) do
    files = {}
    assert(not installed())
    files["/isolated/scc/" .. exe] = true
    files["/isolated/scc/LICENSE"] = true
    assert(not installed(), "README is required, not merely the executable")
    files["/isolated/scc/README.md"] = true
    assert(installed())
    files["/isolated/scc/LICENSE"] = nil
    assert(not installed(), "license must remain part of the installed payload")
end
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_compliance(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text()
        imports = re.findall(r'import\("([^"]+)"\)', source)
        assert set(imports) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|os\.(?:host|curdir|execv)\(|is_host\(|raise\()', source)
        assert "system.exec" not in source and "os.exec" not in source


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        run_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in run_xlings("search", under_test(PKG), "--agent")


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install_reinstall_and_uninstall(self, tmp_path):
        target = under_test(PKG, os.environ.get("XLINGS_TEST_VERSION", ""))
        run_xlings("install", target, "--yes", "--agent")
        assert shim_path().is_file()
        payloads = list((Path(xlings_home()) / "data" / "xpkgs").glob("*-x-scc/*"))
        payloads = [p for p in payloads if (p / ("scc.exe" if os.name == "nt" else "scc")).is_file()]
        assert payloads, "Install must produce a real payload, not only a shim"
        for directory in payloads:
            assert (directory / "LICENSE").is_file() and (directory / "README.md").is_file()
        assert_counts(tmp_path)
        run_xlings("install", target, "--yes", "--agent")
        assert_counts(tmp_path)
        shim = shim_path()
        run_xlings("remove", target, "--yes", "--agent")
        assert not shim.exists() and not shim.is_symlink(), "Uninstall must remove the shim"
        assert all(not p.exists() for p in payloads), "Uninstall must remove the payload"
        registry = json.loads((shim.parent.parent / ".xlings.json").read_text(encoding="utf-8"))
        assert not (registry.get("workspace") or {}).get(PKG), "Uninstall must remove the xvm binding"
        run_xlings("install", target, "--yes", "--agent")
        assert_counts(tmp_path)


class TestVerify:
    @pytest.mark.verify
    def test_version_and_counts(self, tmp_path):
        result = subprocess.run([str(shim_path()), "--version"], capture_output=True,
                                text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        version = os.environ.get("XLINGS_TEST_VERSION", "4.1.0")
        assert f"scc version {version}" in result.stdout
        assert_counts(tmp_path)
