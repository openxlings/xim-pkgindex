"""Witr metadata, portable payload hooks, and owned-process inspection."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

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
from tests.lib.xpkg_parser import parse_xpkg

PKG_FILE = "pkgs/w/witr.lua"
ROOT = Path(__file__).resolve().parents[2]
VERSION = "0.3.4"
HASHES = {
    ("linux", "x86_64"): "d99098c61002f9b8a5337977d527dbe8ee29453f2a62c531038ea2749ea738eb",
    ("linux", "aarch64"): "ecd737fcca418026514ed45a6ad06ecc2e02997e1b75ed6e7100ac8cc69eee54",
    ("macosx", "x86_64"): "e8dae6b77e71826805fb1e27a22ca2ec90d85cb50809044dab3a3232269b5f74",
    ("macosx", "aarch64"): "731b7ed07b07e4c413bfcfae7e4865b5020f7f2379c7f1cdea09c235c5280515",
    ("windows", "x86_64"): "34ef930e6f53c026e952f5952442281640bae551e59477137a045f9a2141188f",
    ("windows", "aarch64"): "c1db651220bc8a86433fba7e680c87f9db868a41c0fb144427f37750ec62a7ce",
}


def _lua(source):
    executable = shutil.which("lua5.4") or shutil.which("lua")
    assert executable, "Lua is required to evaluate the recipe"
    return subprocess.run(
        [executable, "-", PKG_FILE], input=source, text=True,
        capture_output=True, check=True, cwd=ROOT, timeout=15,
    ).stdout


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
        assert meta.spec == "2"
        assert meta.name == "witr"
        assert meta.programs == ["witr"]
        assert meta.has_xvm_enable
        assert set(meta.platforms) == {"linux", "macosx", "windows"}

    @pytest.mark.static
    def test_complete_official_resource_matrix(self):
        rows = _lua(r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.licenses[1] == "Apache-2.0")
assert(package.ci.mirror == true)
assert(package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
assert(#package.archs == 2)
assert(package.extensions == nil, "updates are manual until updater verification")
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    local p = assert(package.xpm[platform])
    assert(p.latest.ref == "0.3.4")
    assert(p.deps == nil, "self-contained binaries need no third-party runtime")
    local v = assert(p[p.latest.ref])
    local count = 0
    for arch, sum in pairs(v.sha256) do
        local url = p.source:gsub("%${version}", p.latest.ref)
                            :gsub("%${arch_alias}", assert(v.arch_alias[arch]))
        print(platform .. "\t" .. arch .. "\t" .. url .. "\t" .. sum)
        count = count + 1
    end
    assert(count == 2)
end
''').splitlines()
        assert len(rows) == 6
        actual = {}
        for row in rows:
            platform, arch, url, checksum = row.split("\t")
            asset_os = "darwin" if platform == "macosx" else platform
            asset_arch = {"x86_64": "amd64", "aarch64": "arm64"}[arch]
            suffix = ".zip" if platform == "windows" else ""
            assert url == (
                "https://github.com/pranshuparmar/witr/releases/download/"
                f"v{VERSION}/witr-{asset_os}-{asset_arch}{suffix}"
            )
            actual[platform, arch] = checksum
        assert actual == HASHES


class TestIsolation:
    @pytest.mark.isolation
    def test_no_user_environment_changes(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)
        assert_uses_new_api(PKG_FILE)


def _run(argv, env, timeout=180):
    result = subprocess.run(
        [str(arg) for arg in argv], env=env, cwd=ROOT,
        capture_output=True, text=True, timeout=timeout,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "[error]" not in result.stdout.lower(), result.stdout + result.stderr
    return result


def _package(env, version=""):
    local = Path(env["XLINGS_HOME"]) / "data/xim-pkgindex-local/pkgs/w/witr.lua"
    name = ("local:" if local.is_file() else "xim:") + "witr"
    return name + ("@" + version if version else "")


@pytest.fixture(scope="module")
def sandbox(tmp_path_factory):
    manager = shutil.which("xlings")
    assert manager, "xlings is required for index/lifecycle tests"
    root = tmp_path_factory.mktemp("witr-isolated")
    home, xhome = root / "home", root / "xlings"
    home.mkdir()
    (xhome / "bin").mkdir(parents=True)
    suffix = ".exe" if os.name == "nt" else ""
    executable = xhome / "bin" / ("xlings" + suffix)
    shutil.copy2(manager, executable)
    bindir = xhome / "subos/default/bin"
    env = {
        **os.environ, "HOME": str(home), "USERPROFILE": str(home),
        "XLINGS_HOME": str(xhome), "XLINGS_ACTIVE_SUBOS": "default",
        "XLINGS_BIN": str(bindir), "XLINGS_SUBOS_LIBS": str(bindir.parent / "lib"),
        "XLINGS_SUBOS_LIB": str(bindir.parent / "lib"),
        "XDG_CONFIG_HOME": str(root / "config"), "XDG_CACHE_HOME": str(root / "cache"),
        "XDG_DATA_HOME": str(root / "data"), "XDG_STATE_HOME": str(root / "state"),
        "BASH_ENV": os.devnull, "PATH": str(bindir) + os.pathsep + os.environ["PATH"],
    }
    local = xhome / "data/xim-pkgindex-local"
    registered = False
    try:
        _run([executable, "self", "init", "--home", xhome, "--agent"], env)
        _run([executable, "config", "--mirror", "GLOBAL", "--agent"], env)
        _run([executable, "update", "--yes", "--agent"], env)
        shutil.copytree(ROOT / "libs", xhome / "data/xim-pkgindex/libs", dirs_exist_ok=True)
        _run([executable, "config", "--add-xpkg", ROOT / PKG_FILE, "--agent"], env)
        registered = True
        if archives := os.environ.get("XLINGS_TEST_ARCHIVES"):
            host = {"linux": "linux", "darwin": "macosx", "win32": "windows"}[sys.platform]
            arch = {"amd64": "x86_64", "x86_64": "x86_64", "arm64": "aarch64",
                    "aarch64": "aarch64"}[platform.machine().lower()]
            asset_os = "darwin" if host == "macosx" else host
            asset_arch = {"x86_64": "amd64", "aarch64": "arm64"}[arch]
            suffix = ".zip" if host == "windows" else ""
            source = Path(archives) / f"witr-{asset_os}-{asset_arch}{suffix}"
            assert hashlib.sha256(source.read_bytes()).hexdigest() == HASHES[host, arch]
            runtime = xhome / "data/runtimedir"
            runtime.mkdir(parents=True, exist_ok=True)
            # Read only this explicitly supplied, exact upstream asset; do not
            # register or search a shared/user archive directory.
            shutil.copy2(source, runtime / source.name)
        yield executable, env, bindir
    finally:
        try:
            if registered:
                _run([executable, "config", "--remove-xpkg", "witr", "--agent"], env)
                assert not (local / "pkgs/w/witr.lua").exists()
        finally:
            shutil.rmtree(root)


@pytest.fixture(scope="module")
def installed(sandbox):
    executable, env, bindir = sandbox
    package = _package(env, os.environ.get("XLINGS_TEST_VERSION", VERSION))
    binary = bindir / ("witr.exe" if os.name == "nt" else "witr")
    try:
        _run([executable, "install", package, "--subos", "default", "-u", "--yes", "--agent"], env)
        assert binary.is_file(), "installation did not create the Witr shim"
        yield binary, env
    finally:
        # Teardown runs after every verify test, not between install and verify.
        _run([executable, "remove", _package(env), "--subos", "default", "--yes", "--agent"], env)
        assert not binary.exists(), "uninstall left the Witr shim behind"
        registry = Path(env["XLINGS_HOME"]) / "subos/default/.xlings.json"
        if registry.is_file():
            assert "witr" not in (json.loads(registry.read_text()).get("workspace") or {})
        _run([executable, "remove", _package(env), "--subos", "default", "--yes", "--agent"], env)


class TestIndex:
    @pytest.mark.index
    def test_register_and_search(self, sandbox):
        executable, env, _ = sandbox
        assert _package(env) in _run([executable, "search", "witr", "--agent"], env).stdout


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install_and_idempotence(self, installed, sandbox):
        binary, env = installed
        executable, _, _ = sandbox
        assert os.access(binary, os.X_OK)
        package = _package(env, os.environ.get("XLINGS_TEST_VERSION", VERSION))
        result = _run([executable, "install", package, "--subos", "default", "--yes", "--agent"], env)
        assert "already installed" in result.stdout.lower()
        assert "witr" in _run([executable, "list", "witr", "--agent"], env).stdout


class TestVerify:
    @pytest.mark.verify
    def test_version_and_registration(self, installed):
        binary, env = installed
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert expected in _run([binary, "--version"], env).stdout
        registry = Path(env["XLINGS_HOME"]) / "subos/default/.xlings.json"
        node = json.loads(registry.read_text())["workspace"]["witr"]
        assert node["active"] in node["installed"]
        namespace = _package(env).split(":", 1)[0]
        payload = Path(env["XLINGS_HOME"]) / "data/xpkgs" / (namespace + "-x-witr") / expected
        assert (payload / binary.name).is_file(), "installed package has no native executable"
        if os.name != "nt":
            assert os.access(payload / "witr", os.X_OK)

    @pytest.mark.verify
    def test_owned_process_short_json(self, installed, tmp_path):
        binary, install_env = installed
        # Pinned ToShortJSON serializes only PID/Command plus optional PPID and
        # ParentExited, never cmdlines or environments. --pid walks ancestry;
        # no name/port lookup, --tree or --verbose process snapshot is requested.
        # Upstream reads ancestry context internally; do not log its raw output.
        safe_env = {
            "PATH": str(binary.parent) + os.pathsep + os.defpath,
            "HOME": str(tmp_path), "USERPROFILE": str(tmp_path),
            "TMP": str(tmp_path), "TEMP": str(tmp_path), "TMPDIR": str(tmp_path),
            "LANG": "C", "LC_ALL": "C", "NO_COLOR": "1",
            "XLINGS_HOME": install_env["XLINGS_HOME"], "XLINGS_ACTIVE_SUBOS": "default",
        }
        if os.name == "nt":
            safe_env["SystemRoot"] = os.environ["SystemRoot"]
        ready = tmp_path / "ready"
        child = subprocess.Popen(
            [sys.executable, "-I", "-S", "-c",
             "import pathlib,sys; pathlib.Path(sys.argv[1]).write_text('ready'); sys.stdin.buffer.read(1)",
             str(ready)],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            env=safe_env, cwd=tmp_path,
        )
        try:
            deadline = time.monotonic() + 5
            while not ready.is_file() and child.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            if not ready.is_file() or child.poll() is not None:
                pytest.fail("Owned fixture process did not become ready", pytrace=False)
            try:
                result = subprocess.run(
                    [str(binary), "--pid", str(child.pid), "--short", "--json"],
                    env=safe_env, cwd=tmp_path, capture_output=True, text=True, timeout=20,
                )
            except subprocess.TimeoutExpired:
                pytest.fail("Witr owned-process inspection timed out", pytrace=False)
            # v0.3.4 renderResult returns 1 for warnings and 6 for an unknown
            # launch cause even when PID lookup and short JSON output succeed.
            # All three statuses must still pass the exact identity checks below.
            if result.returncode not in (0, 1, 6):
                pytest.fail(f"Witr inspection failed with exit {result.returncode}", pytrace=False)
            try:
                report = json.loads(result.stdout)
                owned = next(entry for entry in report if entry.get("PID") == child.pid)
                owned_pid, owned_name = owned["PID"], owned["Command"]
            except (ValueError, TypeError, AttributeError, KeyError, StopIteration):
                pytest.fail("Witr did not return the owned process in short JSON", pytrace=False)
            if owned_pid != child.pid or "python" not in str(owned_name).lower():
                pytest.fail("Witr reported an incorrect owned-process identity", pytrace=False)
        finally:
            if child.stdin:
                child.stdin.close()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=5)
