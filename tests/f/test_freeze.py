"""Portable freeze binaries must render real, self-contained code screenshots."""
import base64
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid
import xml.etree.ElementTree as ET

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

PKG_FILE = "pkgs/f/freeze.lua"
VERSION = "0.2.2"
SVG = "{http://www.w3.org/2000/svg}"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.mark.static
@pytest.mark.parametrize("check", [
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_config_registers_package_name,
])
def test_metadata(meta, check):
    check(meta)


@pytest.mark.static
@pytest.mark.parametrize("platform", ["linux", "macosx", "windows"])
def test_supported_platform(meta, platform):
    assert_platform_supported(meta, platform)


@pytest.mark.static
def test_no_typos():
    assert_no_typos(PKG_FILE)


@pytest.mark.isolation
@pytest.mark.parametrize("check", [
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
])
def test_isolation(check):
    check(PKG_FILE)


def _xlings():
    # Native subprocesses also work on Windows; bash -l can select WSL instead.
    suffix = ".exe" if os.name == "nt" else ""
    native = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    if native.is_file():
        return str(native)
    found = shutil.which("xlings" + suffix)
    assert found, "Native xlings executable is required"
    return found


def _shim():
    suffix = ".exe" if os.name == "nt" else ""
    base = Path(xlings_home()) / "subos"
    names = [os.environ["XLINGS_TEST_SUBOS"]] if os.environ.get("XLINGS_TEST_SUBOS") else ["current", "default"]
    for name in names:
        shim = base / name / "bin" / ("freeze" + suffix)
        if shim.is_file():
            return str(shim)
    raise AssertionError(f"Missing freeze shim in {base}, subos {names}")


def _run(args, **kwargs):
    return subprocess.run(
        args, stdin=subprocess.DEVNULL, capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=120, **kwargs,
    )


@pytest.mark.lifecycle
def test_install():
    result = _run([_xlings(), "install", under_test("freeze"), "-y"])
    assert result.returncode == 0, result.stdout + result.stderr
    assert Path(_shim()).is_file()


@pytest.mark.verify
def test_version():
    result = _run([_shim(), "--version"])
    assert result.returncode == 0, result.stdout + result.stderr
    expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
    assert re.search(r"freeze version v?" + re.escape(expected) + r"(?:\s|$)", result.stdout), result.stdout


def _isolated_render_env(tmp_path):
    env = os.environ.copy()
    env["XLINGS_HOME"] = xlings_home()
    for key, directory in {
        "HOME": "home", "USERPROFILE": "home", "APPDATA": "appdata",
        "LOCALAPPDATA": "localappdata", "XDG_CONFIG_HOME": "config",
        "XDG_CACHE_HOME": "cache", "XDG_DATA_HOME": "data",
    }.items():
        path = tmp_path / directory
        path.mkdir(exist_ok=True)
        env[key] = str(path)
    # No working proxy, credentials, custom fonts, config wizard or child commands.
    for key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
        env[key] = "http://127.0.0.1:9"
    env["NO_PROXY"] = env["no_proxy"] = ""
    return env


@pytest.mark.verify
def test_offline_svg_rendering(tmp_path):
    symbol = "freeze_svg_" + uuid.uuid4().hex
    code = f"def {symbol}(value):\n    return value + 4729\n"
    source = tmp_path / "unique.py"
    source.write_text(code, encoding="utf-8")
    output = tmp_path / "code.svg"
    env = _isolated_render_env(tmp_path)
    result = _run([
        _shim(), str(source), "--output", str(output), "--language", "python",
    ], env=env, cwd=tmp_path)
    assert result.returncode == 0, result.stdout + result.stderr
    root = ET.parse(output).getroot()
    assert root.tag == SVG + "svg"
    width, height = (float(root.attrib[key]) for key in ("width", "height"))
    assert all(math.isfinite(value) and value > 0 for value in (width, height))
    lines = list(root.iter(SVG + "text"))
    rendered = "".join("".join(line.itertext()) for line in lines).replace("\u00a0", " ")
    assert rendered == code, rendered
    positions = []
    for line in lines:
        x, y = (float(line.attrib[key].removesuffix("px")) for key in ("x", "y"))
        assert 0 <= x < width and 0 < y < height, line.attrib
        positions.append(y)
    assert positions == sorted(set(positions)), positions
    colors = {span.attrib.get("fill") for span in root.iter(SVG + "tspan") if "fill" in span.attrib}
    assert len(colors) >= 2, "Expected Python syntax highlighting, not an empty canvas"
    style = "".join("".join(node.itertext()) for node in root.iter(SVG + "style"))
    font = re.search(r"url\(data:[^,]+;base64,([A-Za-z0-9+/=]+)\)", style)
    assert font, "Default font must be embedded, not fetched from a server"
    font_bytes = base64.b64decode(font.group(1), validate=True)
    assert font_bytes[:4] in (b"\x00\x01\x00\x00", b"OTTO", b"wOF2", b"wOFF")
    assert len(font_bytes) > 1024
    for node in root.iter():
        for key, value in node.attrib.items():
            if key.rsplit("}", 1)[-1] == "href":
                assert value.startswith(("data:", "#")), value
    assert all(url.startswith(("data:", "#")) for url in re.findall(r"url\(([^)]+)\)", style))
    assert not list((tmp_path / "config").rglob("*.json")), "Noninteractive rendering must not save user configuration"


@pytest.mark.verify
def test_missing_source_fails_without_output(tmp_path):
    output = tmp_path / "missing.svg"
    result = _run([
        _shim(), str(tmp_path / "absent.py"), "--output", str(output), "--language", "python",
    ], env=_isolated_render_env(tmp_path), cwd=tmp_path)
    assert result.returncode != 0, result.stdout + result.stderr
    assert not output.exists()
