"""dep-closure-check.sh D3: a declared RUNTIME dep that is a tool and provides
no library is probably there for install() -- printed, never a failure.

A runtime dependency is activated in the user's workspace, so 7zip declared
there puts `7z` and `7zz` on their PATH for good (chatgpt, qt, qt-base,
qt-addons and qt5 all did). The check cannot know whether the app runs the tool
at runtime, so the advice is conditional ("if only install() uses it") and the
exit code does not move. What it has to get right is who it stays quiet about:

  * a package with a library (libsecret, mesa)
  * a package with nothing executable in it (`xim:graphics` is an empty
    payload, a discovery package; data packages are the same shape)
  * a dep that is not installed -- not observed is not "provides nothing"
  * a BUILD dep, which is where the advice sends people

Run against a synthetic index and store, so what it reads is what this file
wrote.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
SCRIPTS = REPO / ".github" / "scripts"

LUA = shutil.which("lua5.4") or shutil.which("lua")
pytestmark = pytest.mark.skipif(
    LUA is None or shutil.which("readelf") is None or not Path("/bin/true").is_file(),
    reason="needs lua, readelf and an ELF program to stand in for the payload")

RECIPE = """package = {
    spec = "2", name = "toolapp", type = "package",
    xpm = { linux = {
        deps = {
            runtime = { "xim:faketool", "xim:fakelib", "xim:fakemeta", "xim:absent" },
            build = { "xim:buildtool" },
        },
        ["latest"] = { ref = "1.0" },
        ["1.0"] = {},
    } },
}
"""


def _exe(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("#!/bin/sh\n")
    path.chmod(0o755)


@pytest.fixture()
def world(tmp_path):
    index = tmp_path / "index"
    (index / ".github/scripts").mkdir(parents=True)
    for name in ("dep-closure-check.sh", "check-dep-namespace.lua", "recipe-sandbox.lua"):
        shutil.copy(SCRIPTS / name, index / ".github/scripts" / name)
    (index / "pkgs/t").mkdir(parents=True)
    (index / "pkgs/t/toolapp.lua").write_text(RECIPE)

    xpkgs = tmp_path / "xpkgs"
    _exe(xpkgs / "xim-x-faketool/1.0/bin/faketool")          # a program, no library
    _exe(xpkgs / "xim-x-buildtool/1.0/bin/buildtool")        # same, but declared under build
    lib = xpkgs / "xim-x-fakelib/1.0/lib/libfake.so.1"       # a library
    lib.parent.mkdir(parents=True)
    lib.write_bytes(b"")
    _exe(xpkgs / "xim-x-fakelib/1.0/bin/fakelib-config")     # ... that also ships a program
    (xpkgs / "xim-x-fakemeta/0.1/.xpkg.lua").parent.mkdir(parents=True)
    (xpkgs / "xim-x-fakemeta/0.1/.xpkg.lua").write_text("package = {}\n")   # empty payload

    payload = tmp_path / "payload"
    payload.mkdir()
    shutil.copy("/bin/true", payload / "toolapp")
    return index, xpkgs, payload


def run(world):
    index, xpkgs, payload = world
    return subprocess.run(
        ["bash", str(index / ".github/scripts/dep-closure-check.sh"),
         str(payload), str(index / "pkgs/t/toolapp.lua"), "linux", str(xpkgs)],
        capture_output=True, text=True)


@pytest.mark.static
def test_a_tool_only_runtime_dep_is_advised_about_and_nothing_else(world):
    r = run(world)
    d3 = [l.strip() for l in r.stdout.splitlines() if "D3:" in l]
    assert d3 == ["D3: faketool provides no library; if only install() uses it, declare it under build"], r.stdout + r.stderr


@pytest.mark.static
def test_d3_never_fails_the_check(world):
    r = run(world)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "[FAIL]" not in r.stderr
