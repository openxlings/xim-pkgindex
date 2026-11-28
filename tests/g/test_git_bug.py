"""Portable git-bug metadata, isolation, lifecycle and offline issue tracking."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

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

PKG = "git-bug"
PKG_FILE = "pkgs/g/git-bug.lua"
VERSION = "0.12.0"
ROOT = Path(__file__).resolve().parents[2]
SUPPORTED = pytest.mark.skipif(
    sys.platform not in ("linux", "win32"),
    reason="The index has no managed macOS Git dependency",
)
HASHES = {
    "linux/x86_64": "ff243821d70445df0bbbcd77d99ef65108fc3d632659a95e79c640ac0db57994",
    "linux/aarch64": "5a238294ff3c77d6a7592bab4f8748db5673fdcfd23c1e83d80b5820337b4f92",
    "windows/x86_64": "1b891903991954570f04dcc898b38bde949905c2923845f0c18bb71cd967ef7b",
}


def _run(args, **kwargs):
    result = subprocess.run(
        args, capture_output=True, text=True, encoding="utf-8",
        errors="replace", timeout=240, **kwargs,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return result.stdout


def _xlings(*args):
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    command = str(binary) if binary.is_file() else shutil.which("xlings")
    assert command, "xlings is required for index/lifecycle checks"
    return _run([command, *args], cwd=ROOT)


def _shim(name=PKG):
    suffix = ".exe" if os.name == "nt" else ""
    subos = os.environ.get("XLINGS_TEST_SUBOS")
    for name_subos in ([subos] if subos else ["current", "default"]):
        binary = Path(xlings_home()) / "subos" / name_subos / "bin" / (name + suffix)
        if binary.is_file():
            return binary
    pytest.fail(f"Missing managed {name} shim")


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        for check in (assert_required_fields, assert_valid_spec, assert_valid_type,
                      assert_config_registers_package_name, assert_valid_xvm_node_kinds):
            check(meta)
        assert_no_typos(PKG_FILE)
        assert meta.spec == "2" and meta.name == PKG

    @pytest.mark.static
    def test_complete_matrix_and_git_dependency(self):
        lua = shutil.which("lua5.4") or shutil.which("lua")
        assert lua, "Lua is required for resource resolution checks"
        script = r'''
function import() end
dofile(arg[1])
assert(package.ci.mirror and package.xvm_enable)
assert(package.xpm.macosx == nil)
assert(table.concat(package.archs, ",") == "x86_64,aarch64")
local auto = package.extensions.autoupdate
assert(auto.source == "https://github.com/git-bug/git-bug/releases")
assert(auto.resources.GLOBAL.required and not auto.resources.CN)
local targets = {linux = {"x86_64", "aarch64"}, windows = {"x86_64"}}
for platform, arches in pairs(targets) do
    local p = package.xpm[platform]
    assert(p.deps.runtime[1] == "xim:git" and #p.deps.runtime == 1)
    assert(p.latest.ref == "0.12.0")
    local entry = p["0.12.0"]
    local count = 0
    for _ in pairs(entry.sha256) do count = count + 1 end
    assert(count == #arches)
    for _, arch in ipairs(arches) do
        local url = p.source:gsub("%${version}", "0.12.0")
                            :gsub("%${arch_alias}", entry.arch_alias[arch])
        local update = auto.resources.GLOBAL.url[platform][arch]
        assert(url == update:gsub("%${tag}", "v0.12.0"))
        assert(#entry.sha256[arch] == 64 and entry.sha256[arch]:match("^%x+$"))
        print(platform .. "/" .. arch .. " " .. entry.sha256[arch])
    end
end
assert(not package.xpm.windows["0.12.0"].sha256.aarch64)
'''
        output = _run([lua, "-", PKG_FILE], input=script, cwd=ROOT)
        assert dict(line.split() for line in output.splitlines()) == HASHES

    @pytest.mark.static
    def test_lua_syntax(self):
        luac = shutil.which("luac5.4") or shutil.which("luac")
        assert luac, "luac is required for recipe syntax checks"
        _run([luac, "-p", str(ROOT / PKG_FILE)])


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_boundaries(self):
        for check in (assert_no_exec_xvm, assert_no_bashrc_modification,
                      assert_no_direct_path_modification, assert_no_direct_pkg_manager,
                      assert_uses_new_api):
            check(PKG_FILE)
        source = (ROOT / PKG_FILE).read_text(encoding="utf-8")
        imports = re.findall(r'import\("([^"]+)"\)', source)
        assert imports and all(name.startswith("xim.libxpkg.") for name in imports)
        assert not re.search(r"\b(?:path\.|is_host\(|os\.(?:host|execv|curdir)\(|raise\()", source)


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self):
        _xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))
        assert PKG in _xlings("search", PKG, "--agent")


@SUPPORTED
class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install_and_reinstall(self):
        version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        _xlings("install", under_test(PKG, version), "-y", "--agent")
        assert _shim().is_file() and _shim("git").is_file()
        assert PKG in _xlings("list", PKG, "--agent")
        _xlings("install", under_test(PKG, version), "-y", "--agent")


@SUPPORTED
class TestVerify:
    @pytest.mark.verify
    def test_version(self, tmp_path):
        # Upstream exposes `version`, not a `--version` flag; do not wrap it.
        output = _run([str(_shim()), "version"], cwd=tmp_path)
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert re.search(r"\bgit-bug v" + re.escape(expected) + r"\b", output), output
        result = subprocess.run(
            [str(_shim()), "--version"], cwd=tmp_path, capture_output=True,
            text=True, encoding="utf-8", errors="replace", timeout=20,
        )
        assert result.returncode != 0 and "unknown flag" in result.stderr.lower()

    @pytest.mark.verify
    def test_offline_issue_workflow_with_managed_git(self, tmp_path):
        git = _shim("git")
        bug = _shim()
        env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        env.update({
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_TERMINAL_PROMPT": "0",
            # No host Git fallback: git-bug must find its declared runtime shim.
            "PATH": str(git.parent),
        })
        repo = tmp_path / "repository"
        repo.mkdir()

        def run(binary, *args):
            return _run([str(binary), *args], cwd=repo, env=env)

        run(git, "init", ".")
        run(git, "config", "--local", "user.name", "Package Test")
        run(git, "config", "--local", "user.email", "package-test@example.invalid")
        identity = run(bug, "user", "new", "--non-interactive", "--name", "Package Test",
                       "--email", "package-test@example.invalid").strip()
        assert re.fullmatch(r"[0-9a-f]{40,64}", identity), identity
        title = "Offline package verification"
        body = "An issue persisted as local Git objects without any remote."
        run(bug, "bug", "new", "--non-interactive", "--title", title, "--message", body)
        ids = run(bug, "bug", "--format", "id").splitlines()
        assert len(ids) == 1 and re.fullmatch(r"[0-9a-f]{7,64}", ids[0]), ids
        shown = run(bug, "bug", "show", ids[0])
        assert title in shown and body in shown and "Package Test" in shown, shown
        run(bug, "bug", "status", "close", ids[0])
        assert run(bug, "bug", "show", ids[0], "--field", "status").strip() == "closed"
        assert run(git, "remote").strip() == ""


@SUPPORTED
class TestUninstall:
    @pytest.mark.lifecycle
    def test_remove_and_cleanup(self):
        binary = _shim()
        _xlings("remove", under_test(PKG), "-y", "--agent")
        assert not binary.exists() and not binary.is_symlink(), f"Leftover shim: {binary}"
        for config in (Path(xlings_home()) / "subos").glob("*/.xlings.json"):
            workspace = json.loads(config.read_text(encoding="utf-8")).get("workspace") or {}
            assert PKG not in workspace, f"Leftover git-bug registration: {config}"
        assert not re.search(r"(?:local|xim):git-bug@", _xlings("list", PKG, "--agent"))
        _xlings("remove", under_test(PKG), "-y", "--agent")
