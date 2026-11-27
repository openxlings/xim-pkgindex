"""Official cheat binaries: gzip landing, isolated routing, and offline cheatsheets."""
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
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "cheat"
PKG_FILE = "pkgs/c/cheat.lua"
ROOT = Path(__file__).resolve().parents[2]


def run_lua(source):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to evaluate the package declaration"
    return subprocess.run([lua, "-", PKG_FILE], input=source, cwd=ROOT,
                          text=True, capture_output=True, check=True, timeout=30)


def run_xlings(*args):
    # Native argv avoids login shells overriding the caller's isolated HOME.
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for native package checks"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def executable():
    suffix = ".exe" if os.name == "nt" else ""
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    for name in ([subos] if subos else ["current", "default"]):
        shim = base / name / "bin" / (PKG + suffix)
        if shim.is_file():
            return shim
    pytest.fail("Missing installed cheat shim")


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

    @pytest.mark.static
    def test_resource_and_updater_matrix(self, meta):
        assert set(meta.platforms) == {"linux", "macosx", "windows"}
        run_lua(r'''
function import() end
dofile(arg[1])
assert(package.name == "cheat" and package.spec == "2")
assert(package.licenses[1] == "MIT" and package.xvm_enable)
assert(#package.programs == 1 and package.programs[1] == "cheat")
local expected = {
    linux = {x86_64="linux-amd64.gz", aarch64="linux-arm64.gz"},
    macosx = {x86_64="darwin-amd64.gz", aarch64="darwin-arm64.gz"},
    windows = {x86_64="windows-amd64.exe.zip"},
}
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/cheat/cheat/releases")
assert(auto.resources.CN == nil and auto.resources.GLOBAL.required)
local count, hashes = 0, {}
for platform, arches in pairs(expected) do
    local section = assert(package.xpm[platform])
    assert(section.deps == nil)
    local version = section.latest.ref
    local entry = assert(section[version])
    for arch, suffix in pairs(arches) do
        local hash = assert(entry.sha256[arch])
        assert(#hash == 64 and hash:match("^[a-f0-9]+$") and not hashes[hash])
        hashes[hash] = true
        local url = section.source:gsub("%${version}", version)
        if entry.arch_alias then url = url:gsub("%${arch_alias}", entry.arch_alias[arch]) end
        assert(url == "https://github.com/cheat/cheat/releases/download/" .. version .. "/cheat-" .. suffix)
        assert(auto.resources.GLOBAL.url[platform][arch]:gsub("%${tag}", version) == url)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch]) end
    for arch in pairs(auto.resources.GLOBAL.url[platform]) do assert(arches[arch]) end
end
assert(count == 5)
''')

    @pytest.mark.static
    def test_single_binary_landing_and_registration(self):
        run_lua(r'''
function import() end
payload = assert(loadfile("libs/payload.lua"))()
dofile(arg[1])
local files, calls, moves, added, removed = {}, {}, {}, {}, {}
local archive, dir = "/cache/cheat-linux-amd64.gz", "/store/cheat/5.1.0"
pkginfo = {
    name = function() return "cheat" end,
    install_file = function() return archive end,
    install_dir = function() return dir end,
}
os.isfile = function(p) return files[p] == true end
os.tryrm = function() end
os.mv = function(src, dst)
    assert(files[src], "missing move source: " .. src)
    moves[#moves + 1] = {src, dst}
    files[src], files[dst] = nil, true
end
fs = { mkdir_p = function() end }
system = {exec = function(cmd)
    calls[#calls + 1] = cmd
    if cmd:find("gzip -dc", 1, true) then files[dir .. "/cheat"] = true end
end}
xvm = {
    add = function(name, opt) added[#added + 1] = {name, opt.bindir} end,
    remove = function(name) removed[#removed + 1] = name end,
}
assert(not installed())
files[archive] = true
assert(install() and installed())
assert(#calls == 2 and calls[1]:find('gzip -dc "$1" > "$2"', 1, true))
assert(calls[2] == 'chmod +x "' .. dir .. '/cheat"')
assert(config() and added[1][1] == "cheat" and added[1][2] == dir)
assert(uninstall() and removed[1] == "cheat")

-- Native frameworks may already leave a decompressed sibling or a raw binary.
for _, input in ipairs({"/cache/cheat-linux-amd64.gz", "/cache/cheat-linux-amd64"}) do
    archive, files, calls, moves = input, {}, {}, {}
    files["/cache/cheat-linux-amd64"] = true
    assert(install() and installed())
    assert(#moves == 1 and moves[1][1] == "/cache/cheat-linux-amd64")
    assert(#calls == 1 and calls[1]:find("chmod +x", 1, true))
end

-- Flat Windows ZIP has a differently named executable; reuse the shared unpacker.
archive, dir = "C:/cache/cheat-windows-amd64.exe.zip", "C:/store/cheat/5.1.0"
files, calls, moves = {}, {}, {}
payload.unpack = function(opt)
    assert(opt.extracted == "cheat-windows-amd64.exe")
    files[dir .. "/cheat-windows-amd64.exe"] = true
end
assert(install() and installed())
assert(#calls == 0 and #moves == 1 and moves[1][2] == dir .. "/cheat.exe")

-- Missing or unsuccessful decompression must not report a usable installation.
archive, files = "/cache/missing.gz", {}
assert(not pcall(install))
archive = ""
assert(not pcall(install))
archive, files = "/cache/cheat-linux-amd64.gz", {["/cache/cheat-linux-amd64.gz"]=true}
system.exec = function() end
assert(not pcall(install))
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_compliance(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', source)) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.system",
            "xim.libxpkg.xvm", "xim.pkgindex.payload",
        }
        assert not re.search(r'\b(?:path\.|os\.(?:host|curdir|execv)\(|is_host\(|raise\()', source)
        assert "git clone" not in source and "io.writefile" not in source


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        run_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in run_xlings("search", under_test(PKG), "--agent")


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        run_xlings("install", under_test(PKG), "--yes", "--agent")
        assert executable().is_file()


class TestVerify:
    @pytest.mark.verify
    def test_version_and_registration(self):
        result = subprocess.run([str(executable()), "--version"], capture_output=True,
                                text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        assert re.fullmatch(r"\d+\.\d+\.\d+\s*", result.stdout), result.stdout
        if os.environ.get("XLINGS_TEST_VERSION"):
            assert result.stdout.strip() == os.environ["XLINGS_TEST_VERSION"]
        registry = executable().parent.parent / ".xlings.json"
        node = json.loads(registry.read_text(encoding="utf-8"))["workspace"][PKG]
        assert node["active"] in node["installed"]

    @pytest.mark.verify
    def test_offline_personal_cheatsheet(self, tmp_path):
        sheets = tmp_path / "sheets"
        sheets.mkdir()
        text = "# Local offline sample\nprintf 'xlings-cheat-offline-check\\n'\n"
        (sheets / "xlings-sample").write_text(text, encoding="utf-8")
        config = tmp_path / "conf.yml"
        config.write_text(
            "colorize: false\npager: ''\ncheatpaths:\n"
            "  - name: personal\n    path: " + json.dumps(str(sheets)) + "\n"
            "    tags: [personal]\n    readonly: true\n", encoding="utf-8")
        env = {k: v for k, v in os.environ.items() if not k.upper().startswith("CHEAT_")}
        env.update(CHEAT_CONFIG_PATH=str(config), PAGER="", TERM="dumb")
        result = subprocess.run([str(executable()), "xlings-sample"], env=env,
                                stdin=subprocess.DEVNULL, capture_output=True,
                                text=True, encoding="utf-8", timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        assert result.stdout.strip() == text.strip()
        assert (sheets / "xlings-sample").read_text(encoding="utf-8") == text
        assert sorted(p.name for p in tmp_path.iterdir()) == ["conf.yml", "sheets"]
