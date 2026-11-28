"""git-cliff metadata, isolation, payload routing, and offline changelog tests."""
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
    assert_platform_supported,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "git-cliff"
VERSION = "2.14.2"
PKG_FILE = "pkgs/g/git-cliff.lua"
ROOT = Path(__file__).resolve().parents[2]
PROGRAMS = (PKG,)


def _lua(source, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter unavailable")
    result = subprocess.run(
        [lua, "-", *args], input=source, cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", timeout=15,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def _xlings(*args):
    """Use the native CLI, never a login shell that could replace XLINGS_HOME."""
    binary = os.environ.get("XLINGS_TEST_BINARY") or shutil.which("xlings")
    if not binary or not os.environ.get("XLINGS_HOME"):
        pytest.skip("Native xlings and an explicit XLINGS_HOME are required")
    result = subprocess.run(
        [binary, *args], cwd=ROOT, stdin=subprocess.DEVNULL,
        capture_output=True, text=True, encoding="utf-8", timeout=180,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert not re.search(r"\[error\].*failed", result.stdout + result.stderr)
    return result.stdout + result.stderr


def _shim(program=PKG):
    suffix = ".exe" if os.name == "nt" else ""
    home = Path(xlings_home())
    names = (os.environ.get("XLINGS_TEST_SUBOS", "current"), "default")
    for name in names:
        path = home / "subos" / name / "bin" / (program + suffix)
        if path.is_file():
            return path
    pytest.fail(f"Missing {program} shim under {home}")


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_valid_xvm_node_kinds(meta)
        assert_no_typos(PKG_FILE)
        assert meta.name == PKG and meta.spec == "2"
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_verified_resource_matrix(self):
        _lua(r'''
function import() end
assert(loadfile(arg[1]))()
local p = package
assert(p.xvm_enable and p.ci.mirror)
assert(#p.archs == 2 and p.archs[1] == "x86_64" and p.archs[2] == "aarch64")
assert(#p.programs == 1 and p.programs[1] == "git-cliff")
assert(p.licenses[1] == "MIT" and p.licenses[2] == "Apache-2.0")
local auto = p.extensions.autoupdate
assert(auto.source == "https://github.com/orhun/git-cliff/releases")
assert(auto.resources.CN == nil and auto.resources.GLOBAL.required == true)
local expected = {
    linux = {
        x86_64 = "fa21e2fc70046fcfd0e43e5e4613873ab799aff3d9dc8559c00d31b270e417d0",
        aarch64 = "4be21b21ec9699af4d330b224aeba8a41d41d8f5b351ca2da8a9ea2bdc36380f",
    },
    macosx = {
        x86_64 = "4e647d2deb152aca1e987f225cf42b080b991dd98f3bce4027ef95446d982ac3",
        aarch64 = "a0be97e237d440d34c5e508ec21d070b2c85cbb8be48a46a56f9a4e8bd247f05",
    },
    windows = {
        x86_64 = "ab802a72a1fbdd1e06f17001728cb801d04a180f320efb0ec94af84d2f6adbc7",
    },
}
local count = 0
for platform, arches in pairs(expected) do
    local matrix = p.xpm[platform]
    assert(matrix.latest.ref == "2.14.2" and matrix.deps == nil)
    local entry = matrix["2.14.2"]
    for arch, digest in pairs(arches) do
        assert(entry.sha256[arch] == digest, platform .. "/" .. arch)
        local url = matrix.source:gsub("%${version}", "2.14.2"):gsub("%${arch}", arch)
        local updater = auto.resources.GLOBAL.url[platform][arch]
        assert(updater:gsub("%${tag}", "v2.14.2"):gsub("%${version}", "2.14.2") == url)
        assert(url:match("^https://github.com/orhun/git%-cliff/releases/download/v2%.14%.2/"))
        if platform == "linux" then assert(url:match("linux%-musl.tar.gz$")) end
        if platform == "windows" then assert(url:match("windows%-gnu.zip$")) end
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch], "unchecked architecture") end
    for arch in pairs(auto.resources.GLOBAL.url[platform]) do assert(arches[arch]) end
end
assert(count == 5)
''', PKG_FILE)

    @pytest.mark.static
    @pytest.mark.parametrize("windows", [False, True])
    def test_payload_and_routing_hooks(self, windows):
        _lua(r'''
function import() end
local windows = arg[2] == "true"
local suffix = windows and ".exe" or ""
local present, unpacked, required, chmod, added, removed = {}, false, false, 0, {}, {}
pkginfo = {
    version = function() return "2.14.2" end,
    install_dir = function() return "/isolated/git-cliff" end,
    install_file = function() return windows and "C:\\cache\\release.zip" or "/cache/release.tar.gz" end,
}
payload = {
    present = function(files)
        for _, f in ipairs(files) do if not present[f] then return false end end
        return true
    end,
    unpack = function(opt)
        assert(opt.extracted == "git-cliff-2.14.2" and opt.strip == 1)
        unpacked = true
    end,
    require = function(files)
        assert(unpacked)
        assert(#files == 6 and files[1] == "git-cliff" .. suffix)
        assert(files[2] == "git-cliff-completions" .. suffix)
        assert(files[3] == "git-cliff-mangen" .. suffix)
        assert(files[4] == "LICENSE-MIT" and files[5] == "LICENSE-APACHE")
        assert(files[6] == "man/git-cliff.1")
        for _, f in ipairs(files) do present[f] = true end
        required = true
    end,
}
shell = { exec = function(argv)
    assert(argv[1] == "chmod" and argv[2] == "+x")
    assert(argv[3]:match("^/isolated/git%-cliff/git%-cliff"))
    chmod = chmod + 1
end }
xvm = {
    add = function(name, opt) assert(opt.bindir == "/isolated/git-cliff"); added[name] = true end,
    remove = function(name) removed[name] = true end,
}
assert(loadfile(arg[1]))()
assert(not installed())
assert(install() and required and installed())
assert(chmod == (windows and 0 or 1))
for _, f in ipairs({"git-cliff" .. suffix, "git-cliff-completions" .. suffix,
    "git-cliff-mangen" .. suffix, "LICENSE-MIT", "LICENSE-APACHE", "man/git-cliff.1"}) do
    present[f] = nil; assert(not installed(), "must detect missing " .. f); present[f] = true
end
assert(config() and uninstall())
for _, program in ipairs(package.programs) do assert(added[program] and removed[program]) end
''', PKG_FILE, str(windows).lower())


class TestIsolation:
    @pytest.mark.isolation
    @pytest.mark.parametrize("check", [
        assert_no_exec_xvm, assert_no_bashrc_modification,
        assert_no_direct_path_modification, assert_uses_new_api,
        assert_no_direct_pkg_manager,
    ])
    def test_subos_compliance(self, check):
        check(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_apis(self):
        src = (ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) == {
            "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.(?:host|curdir|execv)\(|raise\(|core\.|try\s*\{)', src)


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        _xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in _xlings("search", PKG)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        _xlings("install", under_test(PKG, os.environ.get("XLINGS_TEST_VERSION", VERSION)), "-y")
        for program in PROGRAMS:
            assert _shim(program).is_file()


class TestVerify:
    @pytest.mark.verify
    def test_version_and_registration(self):
        result = subprocess.run([str(_shim()), "--version"], capture_output=True,
                                text=True, encoding="utf-8", check=True, timeout=15)
        assert f"git-cliff {os.environ.get('XLINGS_TEST_VERSION', VERSION)}" in result.stdout
        config = _shim().parent.parent / ".xlings.json"
        workspace = json.loads(config.read_text(encoding="utf-8"))["workspace"]
        for program in PROGRAMS:
            assert program in workspace, f"Unregistered program: {program}"

    @pytest.mark.verify
    def test_offline_changelog(self, tmp_path):
        git = shutil.which("git")
        assert git, "git is required to create the local smoke-test repository"
        env = {key: value for key, value in os.environ.items()
               if not key.startswith(("GIT_", "GITHUB_", "GITLAB_", "GITEA_", "BITBUCKET_", "AZURE_DEVOPS_"))}
        env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                   GIT_CLIFF_OFFLINE="true", NO_COLOR="1")
        for args in (["init", "."],
                     ["-c", "user.name=Package Test", "-c", "user.email=test@example.invalid",
                      "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "feat: generate an offline changelog"],
                     ["tag", "v1.0.0"]):
            subprocess.run([git, *args], cwd=tmp_path, env=env, check=True,
                           capture_output=True, text=True, encoding="utf-8", timeout=15)
        config = tmp_path / "cliff.toml"
        config.write_text('[changelog]\nbody = """{% for commit in commits %}{{ commit.message }}\\n{% endfor %}"""\n'
                          '[git]\nconventional_commits = true\nfilter_unconventional = true\n', encoding="utf-8")
        result = subprocess.run(
            [str(_shim()), "--offline", "--no-exec", "--config", str(config), "--repository", str(tmp_path)],
            cwd=tmp_path, env=env, capture_output=True, text=True, encoding="utf-8", check=True, timeout=20,
        )
        assert "generate an offline changelog" in result.stdout
