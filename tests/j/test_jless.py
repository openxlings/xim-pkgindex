"""Official portable jless: metadata, isolation, lifecycle and real terminal UI."""
import errno
import json
import os
from pathlib import Path
import re
import select
import shutil
import signal
import struct
import subprocess
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

PKG_FILE = "pkgs/j/jless.lua"
ROOT = Path(__file__).resolve().parents[2]
VERSION = "0.9.0"
ASSETS = {
    "linux": {
        "x86_64": ("x86_64-unknown-linux-gnu", "a1e0eb63ef347adc649989ac5c7d2dc896df6d494622b953c86e3a248e733a93"),
    },
    "macosx": {
        "x86_64": ("x86_64-apple-darwin", "8228d44b918af7e904a75df10f85dabf29cdedac17156d870c80968e6836b04f"),
        "aarch64": ("aarch64-apple-darwin", "1967568762e44d3a5a7b09211c55ff9680419878a5a7045876d2cc6870e40390"),
    },
}


def _lua(script):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua is needed to inspect executable recipe metadata")
    return subprocess.run(
        [lua, "-", str(ROOT / PKG_FILE)], input=script,
        text=True, capture_output=True, check=True, timeout=10,
    ).stdout


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        meta = parse_xpkg(PKG_FILE)
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_valid_xvm_node_kinds(meta)
        assert_no_typos(PKG_FILE)
        assert meta.spec == "2"
        assert meta.name == "jless"
        assert meta.programs == ["jless"]
        assert set(meta.platforms) == {"linux", "macosx"}

    @pytest.mark.static
    def test_exact_assets_hashes_and_autoupdate(self):
        rows = _lua('''
import = function() end
dofile(arg[1])
assert(package.xvm_enable and package.ci.mirror)
assert(#package.archs == 2)
local au = package.extensions.autoupdate
assert(au.source == "https://github.com/PaulJuliusMartinez/jless/releases")
assert(au.resources.CN == nil and au.resources.GLOBAL.required == true)
assert(package.xpm.windows == nil)
assert(package.xpm.linux["0.9.0"].aarch64 == nil)
assert(package.xpm.macosx.deps == nil)
local deps = package.xpm.linux.deps.runtime
assert(#deps == 3)
assert(deps[1] == "xim:glibc@>=2.34")
assert(deps[2] == "xim:gcc-runtime@>=15.1.0")
assert(deps[3] == "xim:libxcb@>=1.17.0")
for plat, entry in pairs(package.xpm) do
    assert(entry.latest.ref == "0.9.0")
    for arch, resource in pairs(entry["0.9.0"]) do
        local template = assert(au.resources.GLOBAL.url[plat][arch])
        assert(template:gsub("${tag}", "v0.9.0") == resource.url)
        print(plat .. "\\t" .. arch .. "\\t" .. resource.url .. "\\t" .. resource.sha256)
    end
end
''')
        actual = {}
        for row in rows.splitlines():
            platform, arch, url, digest = row.split("\t")
            actual[(platform, arch)] = (url, digest)
        expected = {
            (platform, arch): (
                f"https://github.com/PaulJuliusMartinez/jless/releases/download/v{VERSION}/jless-v{VERSION}-{target}.zip",
                digest,
            )
            for platform, arches in ASSETS.items()
            for arch, (target, digest) in arches.items()
        }
        assert actual == expected

    @pytest.mark.static
    @pytest.mark.parametrize("target", ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin"])
    def test_hooks_land_only_payload_and_seal_linux(self, target):
        _lua('''
import = function() end
dofile(arg[1])
local dir = "/isolated/jless/0.9.0"
local source = "/download/jless"
local have_binary = false
pkginfo = {
    install_file = function() return "/download/jless-v0.9.0-TARGET.zip" end,
    install_dir = function() return dir end,
}
fs = {mkdir_p = function(p) assert(p == dir .. "/bin") end}
os.isfile = function(p) return p == source end
os.tryrm = function(p) assert(p == dir) end
os.mv = function(from, to)
    assert(from == source and to == dir .. "/bin/jless")
    have_binary = true
end
payload = {
    present = function(files)
        assert(#files == 1 and files[1] == "bin/jless")
        return have_binary
    end,
    require = function(files) assert(have_binary and files[1] == "bin/jless") end,
}
shell = {exec = function(args)
    assert(args[1] == "chmod" and args[2] == "+x" and args[3] == dir .. "/bin/jless")
end}
local sealed = false
selfcontain = {seal = function(p, dirs)
    assert(p == dir and #dirs == 1 and dirs[1] == "bin")
    sealed = true
    return true
end}
xvm = {
    add = function(name, options) assert(name == "jless" and options.bindir == dir .. "/bin") end,
    remove = function(name) assert(name == "jless") end,
}
assert(not installed())
assert(install() and installed())
assert(sealed == ("TARGET" == "x86_64-unknown-linux-gnu"))
assert(config() and uninstall())
'''.replace("TARGET", target))

    @pytest.mark.static
    def test_missing_executable_fails_before_removing_install(self):
        _lua('''
import = function() end
dofile(arg[1])
pkginfo = {install_file = function() return "/download/jless.zip" end}
os.isfile = function() return false end
os.tryrm = function() error("must not delete existing install") end
local ok, message = pcall(install)
assert(not ok and tostring(message):find("extracted executable is missing", 1, true))
''')


class TestIsolation:
    @pytest.mark.isolation
    @pytest.mark.parametrize("check", [
        assert_no_exec_xvm, assert_no_bashrc_modification,
        assert_no_direct_path_modification, assert_uses_new_api,
        assert_no_direct_pkg_manager,
    ])
    def test_isolation(self, check):
        check(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_apis_and_no_host_fallback(self):
        source = (ROOT / PKG_FILE).read_text()
        assert set(re.findall(r'import\("([^"]+)"\)', source)) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.selfcontain", "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', source)
        assert 'type(selfcontain.seal) ~= "function"' in source
        assert 'not selfcontain.seal(dir, {"bin"})' in source


def _run(argv, env, **kwargs):
    result = subprocess.run(
        [str(arg) for arg in argv], env=env, text=True,
        capture_output=True, timeout=kwargs.pop("timeout", 180), **kwargs,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "[error]" not in result.stdout.lower(), result.stdout + result.stderr
    return result


def _package(env, version=""):
    local = Path(env["XLINGS_HOME"]) / "data/xim-pkgindex-local/pkgs/j/jless.lua"
    name = ("local:" if local.is_file() else "xim:") + "jless"
    return name + ("@" + version if version else "")


@pytest.fixture(scope="module")
def sandbox(tmp_path_factory):
    executable = shutil.which("xlings")
    assert executable, "xlings is required for index/lifecycle verification"
    root = tmp_path_factory.mktemp("jless-isolated")
    home = root / "home"
    xhome = root / "xlings"
    bindir = xhome / "subos/default/bin"
    home.mkdir()
    # xvm creates command shims to this home's manager, not the external
    # executable used to bootstrap the test home.
    (xhome / "bin").mkdir(parents=True)
    shutil.copy2(executable, xhome / "bin/xlings")
    executable = str(xhome / "bin/xlings")
    env = {
        **os.environ,
        "HOME": str(home), "XLINGS_HOME": str(xhome),
        "XDG_CONFIG_HOME": str(root / "config"), "XDG_CACHE_HOME": str(root / "cache"),
        "XDG_DATA_HOME": str(root / "data"), "XDG_STATE_HOME": str(root / "state"),
        "BASH_ENV": "/dev/null", "XLINGS_ACTIVE_SUBOS": "default",
        "XLINGS_BIN": str(bindir), "XLINGS_SUBOS_LIBS": str(bindir.parent / "lib"),
        "XLINGS_SUBOS_LIB": str(bindir.parent / "lib"),
        "PATH": str(bindir) + os.pathsep + os.environ["PATH"],
    }
    _run([executable, "config", "--mirror", "GLOBAL"], env)
    _run([executable, "update"], env)
    local = xhome / "data/xim-pkgindex-local"
    shutil.copytree(ROOT / "libs", local / "libs", dirs_exist_ok=True)
    _run([executable, "config", "--add-xpkg", ROOT / PKG_FILE], env)
    return executable, env, bindir


@pytest.fixture(scope="module")
def installed(sandbox):
    executable, env, bindir = sandbox
    package = _package(env, VERSION)
    _run([executable, "install", package, "-y"], env)
    _run([executable, "use", "jless", package.split(":", 1)[0] + ":" + VERSION], env)
    binary = bindir / "jless"
    assert binary.exists(), "installation did not create the jless shim"
    try:
        yield binary, env
    finally:
        _run([executable, "remove", package, "-y"], env)
        assert not binary.exists(), "uninstall left the jless shim behind"


class TestIndex:
    @pytest.mark.static
    @pytest.mark.parametrize("registered", [False, True])
    def test_registered_and_published_package_identity(self, tmp_path, registered):
        env = {"XLINGS_HOME": str(tmp_path)}
        if registered:
            recipe = tmp_path / "data/xim-pkgindex-local/pkgs/j/jless.lua"
            recipe.parent.mkdir(parents=True)
            recipe.write_text("registered recipe")
        expected = ("local:" if registered else "xim:") + "jless"
        assert _package(env) == expected
        assert _package(env, VERSION) == expected + "@" + VERSION

    @pytest.mark.index
    def test_register_and_search(self, sandbox):
        executable, env, _ = sandbox
        result = _run([executable, "search", "jless"], env)
        assert _package(env) in result.stdout


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self, installed):
        binary, env = installed
        assert _run([binary, "--version"], env).stdout.strip() == "jless " + VERSION


class TestVerify:
    @pytest.mark.verify
    def test_json_pretty_print_and_parse_failure(self, installed):
        binary, env = installed
        data = {"value": 42, "nested": [True, "needle"]}
        result = _run([binary, "--json", "-"], env, input=json.dumps(data))
        assert json.loads(result.stdout) == data
        assert "\n" in result.stdout
        bad = subprocess.run(
            [str(binary), "--json", "-"], input='{"broken":',
            env=env, capture_output=True, text=True, timeout=10,
        )
        assert bad.returncode != 0
        assert "Unable to parse input" in bad.stderr

    @pytest.mark.verify
    @pytest.mark.skipif(os.name != "posix", reason="official jless releases are POSIX-only")
    def test_real_terminal_navigation_and_search(self, installed, tmp_path):
        import fcntl
        import pty
        import termios

        _, env = installed
        # Shim routing is exercised by the version/JSON checks. Give the native
        # UI direct ownership of this controlling terminal, not xlings' macOS
        # child-process wrapper, so q and terminal cleanup belong to jless.
        namespace = _package(env).split(":", 1)[0]
        native_binary = Path(env["XLINGS_HOME"]) / "data/xpkgs" / (namespace + "-x-jless") / VERSION / "bin/jless"
        assert native_binary.is_file()
        fixture = tmp_path / "fixture.json"
        rows = [{"value": f"row-{index:02}"} for index in range(60)]
        rows[45]["value"] = "needle-unique-731"
        fixture.write_text(json.dumps({"rows": rows}))
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
        process = None
        try:
            process = subprocess.Popen(
                [str(native_binary), str(fixture)], stdin=slave, stdout=slave, stderr=slave,
                env={**env, "TERM": "xterm-256color"}, start_new_session=True,
                preexec_fn=lambda: fcntl.ioctl(0, termios.TIOCSCTTY, 0),
            )
            os.close(slave)
            slave = -1

            def until(expected):
                output = bytearray()
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    if not select.select([master], [], [], max(0, deadline - time.monotonic()))[0]:
                        break
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as exc:
                        if exc.errno == errno.EIO:
                            break
                        raise
                    if not chunk:
                        break
                    output.extend(chunk)
                    if expected in output:
                        return bytes(output)
                pytest.fail(f"Terminal did not render {expected!r}: {bytes(output)!r}")

            initial = until(b"fixture.json")
            assert b"row-00" in initial
            os.write(master, b"G")
            until(b"rows[59]")
            # Enter rustyline first: sending the query in the same write as
            # '/' lets termion prefetch and consume it before the editor starts.
            os.write(master, b"/")
            until(b"\x1b[?2004h")
            os.write(master, b"needle-unique-731\r")
            found = until(b"[1/1]")
            assert b"rows[45].value" in found
            os.write(master, b"/")
            until(b"\x1b[?2004h")
            os.write(master, b"absent-unique-942\r")
            until(b"Pattern not found: absent-unique-942")
            os.write(master, b"q")
            # Keep consuming terminal output while the app restores the screen;
            # waiting first can back-pressure a macOS PTY during shutdown.
            deadline = time.monotonic() + 3
            while process.poll() is None and time.monotonic() < deadline:
                if select.select([master], [], [], 0.05)[0]:
                    try:
                        if not os.read(master, 65536):
                            break
                    except OSError as exc:
                        if exc.errno != errno.EIO:
                            raise
                        break
            assert process.wait(timeout=max(0.1, deadline - time.monotonic())) == 0
        finally:
            if slave >= 0:
                os.close(slave)
            # Closing the controlling terminal releases its foreground process
            # before bounded process-group cleanup, including failure paths.
            os.close(master)
            if process is not None and process.poll() is None:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    process.wait(timeout=1)
