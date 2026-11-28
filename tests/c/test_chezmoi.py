"""Portable chezmoi assets and an explicitly isolated dotfile round trip."""
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
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "chezmoi"
PKG_FILE = "pkgs/c/chezmoi.lua"
ROOT = Path(__file__).resolve().parents[2]


def run_lua(source):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required to evaluate the package declaration"
    return subprocess.run([lua, "-", PKG_FILE], input=source, cwd=ROOT,
                          text=True, capture_output=True, check=True, timeout=30)


def run_xlings(*args):
    # Native argv avoids login-shell startup and Windows' bash.exe.
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for lifecycle checks"
    result = subprocess.run([command, *args], capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def executable():
    suffix = ".exe" if os.name == "nt" else ""
    base = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    for name in [subos] if subos else ["current", "default"]:
        shim = base / name / "bin" / (PKG + suffix)
        if shim.is_file():
            return str(shim)
    pytest.fail("Missing installed chezmoi shim")


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_resources_and_updater(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.spec == "2" and package.name == "chezmoi")
assert(package.licenses[1] == "MIT")
local expected = {
    linux = {x86_64="linux-musl_amd64.tar.gz", aarch64="linux_arm64.tar.gz"},
    macosx = {x86_64="darwin_amd64.tar.gz", aarch64="darwin_arm64.tar.gz"},
    windows = {x86_64="windows_amd64.zip", aarch64="windows_arm64.zip"},
}
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/twpayne/chezmoi/releases")
assert(auto.resources.CN == nil)
local count = 0
for platform, arches in pairs(expected) do
    local p = assert(package.xpm[platform])
    local version = assert(p.latest.ref)
    local entry = assert(p[version])
    for arch, suffix in pairs(arches) do
        local resource = entry[arch]
        local hash = resource and resource.sha256 or entry.sha256[arch]
        assert(#hash == 64 and hash:match("^[a-f0-9]+$"))
        local url = resource and resource.url or p.source
        url = url:gsub("%${version}", version)
        if entry.arch_alias then
            url = url:gsub("%${arch_alias}", entry.arch_alias[arch])
        end
        assert(url == "https://github.com/twpayne/chezmoi/releases/download/v"
            .. version .. "/chezmoi_" .. version .. "_" .. suffix, url)
        assert(auto.resources.GLOBAL.url[platform][arch]
            :gsub("%${version}", version) == url)
        count = count + 1
    end
    for arch in pairs(entry.sha256 or entry) do
        assert(arches[arch], "unexpected architecture")
    end
    for arch in pairs(auto.resources.GLOBAL.url[platform]) do assert(arches[arch]) end
end
assert(count == 6)
''')

    @pytest.mark.static
    def test_flat_archive_hooks_and_missing_payload(self):
        run_lua(r'''
function import() end
assert(loadfile(arg[1]))()
local dir, archive, files = "/isolated/chezmoi", "", {}
local wanted = {"LICENSE", "README.md", "completions/chezmoi-completion.bash",
                "completions/chezmoi.fish", "completions/chezmoi.ps1",
                "completions/chezmoi.zsh"}
local function unpack_files()
    files = {}
    files[dir .. (archive:match("%.zip$") and "/chezmoi.exe" or "/chezmoi")] = true
    for _, f in ipairs(wanted) do files[dir .. "/" .. f] = true end
end
pkginfo = {install_dir=function() return dir end, install_file=function() return archive end}
os.isfile = function(p) return p == archive or files[p] == true end
os.tryrm = function(p) assert(p == dir); files = {} end
fs = {mkdir_p=function(p) assert(p == dir) end}
system = {exec=function(cmd)
    assert(cmd == 'tar -xzf "' .. archive .. '" -C "' .. dir .. '"', cmd)
    unpack_files()
end}
payload = {
    unpack=function(opt) assert(next(opt) == nil); unpack_files() end,
    present=function(required)
        for _, f in ipairs(required) do if not files[dir .. "/" .. f] then return false end end
        return true
    end,
}
payload.require = function(required) assert(payload.present(required)) end
xvm = {
    add=function(name, opt) assert(name == "chezmoi" and opt.bindir == dir) end,
    remove=function(name) assert(name == "chezmoi") end,
}
for _, suffix in ipairs({"linux-musl_amd64.tar.gz", "linux_arm64.tar.gz",
                         "darwin_amd64.tar.gz", "darwin_arm64.tar.gz",
                         "windows_amd64.zip", "windows_arm64.zip"}) do
    archive = "/download/chezmoi_9.8.7_" .. suffix
    assert(install() and installed() and config() and uninstall())
    for _, f in ipairs(wanted) do
        files[dir .. "/" .. f] = nil
        assert(not installed(), "missing payload must not count as installed: " .. f)
        files[dir .. "/" .. f] = true
    end
    files[dir .. "/chezmoi"], files[dir .. "/chezmoi.exe"] = nil, nil
    assert(not installed())
end
''')


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_and_no_dotfile_side_effects(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text()
        imports = re.findall(r'import\("([^"]+)"\)', source)
        assert set(imports) == {"xim.libxpkg.fs", "xim.libxpkg.pkginfo",
                                "xim.libxpkg.system", "xim.libxpkg.xvm",
                                "xim.pkgindex.payload"}
        assert not re.search(r'\b(?:path\.|os\.(?:host|curdir|execv)\(|is_host\(|raise\()', source)
        assert "os.getenv" not in source and "io." not in source
        assert "chezmoi init" not in source and "chezmoi apply" not in source


class TestIndex:
    @pytest.mark.index
    def test_register(self):
        run_xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in run_xlings("search", under_test(PKG), "--agent")


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        run_xlings("install", under_test(PKG), "--yes", "--agent")
        assert Path(executable()).is_file()


class TestVerify:
    @pytest.mark.verify
    def test_version_and_registration(self):
        result = subprocess.run([executable(), "--version"], capture_output=True,
                                text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        match = re.search(r"chezmoi version v?(\d+\.\d+\.\d+)\b", result.stdout)
        assert match, result.stdout
        if os.environ.get("XLINGS_TEST_VERSION"):
            assert match[1] == os.environ["XLINGS_TEST_VERSION"]
        registry = Path(executable()).parent.parent / ".xlings.json"
        node = json.loads(registry.read_text(encoding="utf-8"))["workspace"][PKG]
        assert node["active"] in node["installed"]

    @pytest.mark.verify
    def test_add_apply_isolated_dotfile(self, tmp_path):
        binary = executable()
        home, source, dest, control = (tmp_path / name for name in
                                       ("home", "source", "destination", "control"))
        for directory in (home, source, dest, control):
            directory.mkdir()
        # chezmoi protects the config directory: keep targets outside that tree.
        config = control / "chezmoi.toml"
        config.write_text("", encoding="utf-8")
        env = os.environ.copy()
        env.update(HOME=str(home), USERPROFILE=str(home),
                   APPDATA=str(home / "appdata"), LOCALAPPDATA=str(home / "localappdata"),
                   XDG_CONFIG_HOME=str(home / "config"), XDG_DATA_HOME=str(home / "data"),
                   XDG_CACHE_HOME=str(home / "cache"), XDG_STATE_HOME=str(home / "state"))
        args = [binary, "--config", str(config), "--source", str(source),
                "--destination", str(dest), "--persistent-state", str(control / "state.boltdb"),
                "--cache", str(control / "cache"), "--no-tty", "--force"]
        target = dest / ".chezmoi-package-test"
        content = "chezmoi isolated add/apply round trip\n"
        target.write_text(content, encoding="utf-8")
        for command in (["add", str(target)], ["apply", str(target)]):
            if command[0] == "apply":
                target.unlink()
            result = subprocess.run([*args, *command], cwd=tmp_path, env=env,
                                    capture_output=True, text=True, timeout=30)
            assert result.returncode == 0, result.stdout + result.stderr
        assert target.read_text(encoding="utf-8") == content
        assert (source / "dot_chezmoi-package-test").read_text(encoding="utf-8") == content
        assert config.read_text(encoding="utf-8") == ""
        assert not list(home.iterdir()), "Explicit paths must not create default home configuration"
