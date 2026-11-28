"""Brook's official raw binaries, isolated lifecycle and offline link generation."""
import os
from pathlib import Path
import shutil
import subprocess
from urllib.parse import parse_qs, urlsplit

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
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

RECIPE = Path(__file__).resolve().parents[2] / "pkgs/b/brook.lua"
EXE = ".exe" if os.name == "nt" else ""
VERSION = os.environ.get("XLINGS_TEST_VERSION", "")


def run_xlings(*args):
    client = Path(xlings_home()) / "bin" / ("xlings" + EXE)
    command = str(client) if client.is_file() else shutil.which("xlings")
    assert command, "xlings is required"
    result = subprocess.run(
        [command, *args], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=240,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "[error]" not in output.lower(), output
    return output


def brook_binary():
    root = Path(xlings_home()) / "subos"
    subos = os.environ.get("XLINGS_TEST_SUBOS", "default")
    return root / subos / "bin" / ("brook" + EXE)


@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(str(RECIPE))
    for check in (assert_required_fields, assert_valid_spec, assert_valid_type,
                  assert_config_registers_package_name):
        check(meta)
    assert_no_typos(str(RECIPE))
    assert meta.programs == ["brook"]
    assert set(meta.platforms) == {"linux", "macosx", "windows"}
    assert meta.spec == "2"


@pytest.mark.static
def test_lua_syntax():
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua 5.3+ is required to check recipe syntax"
    subprocess.run(
        [lua, "-", str(RECIPE)], input="assert(loadfile(arg[1]))",
        text=True, check=True, timeout=10,
    )


@pytest.mark.isolation
def test_isolation():
    for check in (
        assert_no_bashrc_modification, assert_no_direct_path_modification,
        assert_no_direct_pkg_manager, assert_no_exec_xvm, assert_uses_new_api,
    ):
        check(str(RECIPE))


@pytest.mark.index
def test_register():
    run_xlings("config", "--add-xpkg", str(RECIPE))
    assert "brook" in run_xlings("search", "brook")


@pytest.mark.lifecycle
def test_install():
    run_xlings("install", under_test("brook", VERSION), "-y")
    assert brook_binary().is_file(), "config must create a usable xvm route"
    payloads = Path(xlings_home()) / "data" / "xpkgs"
    assert any(payloads.glob(f"*-x-brook/*/brook{EXE}"))


@pytest.mark.verify
def test_version_and_offline_links():
    binary = str(brook_binary())
    result = subprocess.run(
        [binary, "--version"], capture_output=True, text=True, timeout=15,
    )
    assert result.returncode == 0 and "Brook version" in result.stdout, result.stderr
    if VERSION:
        assert result.stdout.strip().endswith(VERSION)
    # `link` only serializes parameters: no listener, DNS, service or network I/O.
    for server, kind in (
        ("127.0.0.1:9999", "server"),
        ("wss://localhost:443/proxy", "wssserver"),
        ("socks5://127.0.0.1:1080", "socks5"),
    ):
        result = subprocess.run(
            [binary, "link", "--server", server, "--password", "test & +=/?",
             "--name", "offline test", "--udpovertcp"],
            capture_output=True, text=True, encoding="utf-8", timeout=15,
        )
        assert result.returncode == 0, result.stderr
        link = urlsplit(result.stdout.strip())
        assert link.scheme == "brook" and link.netloc == kind
        assert parse_qs(link.query) == {
            kind: [server], "password": ["test & +=/?"],
            "name": ["offline test"], "udpovertcp": ["true"],
        }


@pytest.mark.lifecycle
def test_uninstall():
    run_xlings("remove", under_test("brook"), "-y")
    assert not brook_binary().exists()
    payloads = Path(xlings_home()) / "data" / "xpkgs"
    assert not any(payloads.glob(f"*-x-brook/*/brook{EXE}"))
