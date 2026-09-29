"""libs/qtsdk.lua's 7-Zip extraction: quiet when it works, ONE line for the
known chained-symlink refusal, and 7-Zip's own words when it is anything else.

7-Zip 21+ refuses a symlink whose target is another symlink of the same
archive, exits non-zero, and leaves a 0-byte file in its place. The recipe
recreates the link. What it used to do around that was let 7-Zip's banner,
file list and the two ERROR lines run across the installer's screen, in the
middle of the `[n/88]` progress -- and say nothing about having repaired it.

Run against a forged 7zz (tests/lua/qtsdk_extract_harness.lua), in a plain-Lua
sandbox: the real tool needs a Qt archive of ~100 MB, and what is under test
is the recipe's handling of its exit code and output, not 7-Zip.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "qtsdk_extract_harness.lua"
QTSDK = REPO / "libs" / "qtsdk.lua"

LUA = shutil.which("lua5.4") or shutil.which("lua")
pytestmark = pytest.mark.skipif(LUA is None or os.name == "nt",
                                reason="needs lua and a POSIX shell")


def run(tmp_path, mode):
    env = dict(os.environ, FAKE_ROOT=str(tmp_path), QTSDK=str(QTSDK))
    r = subprocess.run([LUA, str(HARNESS), mode], env=env, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    facts = {}
    for line in r.stdout.splitlines():
        key, _, rest = line.partition("\t")
        facts.setdefault(key, []).append(rest)
    return facts


@pytest.mark.static
def test_success_is_silent_and_asks_7zip_to_be_quiet(tmp_path):
    f = run(tmp_path, "ok")
    assert f["RETURN"] == ["true"]
    assert f.get("LOG", []) == []
    assert "-bso0 -bsp0" in f["ARGS"][0]
    assert f["LEFT"] == ["false"]                      # the capture file is not left behind


@pytest.mark.static
def test_chained_links_are_repaired_and_reported_once(tmp_path):
    f = run(tmp_path, "chained")
    assert f["RETURN"] == ["true"]
    # one line, carrying the real count, and nothing else
    assert f["LOG"] == ["info\tqt-test: 7-Zip refused 2 chained .so links; recreated"]
    assert sorted(f["LINK"]) == ["libBar.so\tlibBar.so.6", "libFoo.so\tlibFoo.so.6"]
    assert "FILE" not in f
    assert f["LEFT"] == ["false"]


@pytest.mark.static
def test_unrepairable_failure_shows_what_7zip_said(tmp_path):
    f = run(tmp_path, "broken")
    assert f["RETURN"] == ["false"]
    errors = [l for l in f["LOG"] if l.startswith("error\t")]
    assert any("Data error : lib/libLost.so.6.1" in l for l in errors), f["LOG"]
    assert not any(l.startswith("info\t") for l in f["LOG"])
    assert f["FILE"] == ["libLost.so\t0"]              # nothing was papered over


@pytest.mark.static
def test_other_output_is_not_swallowed(tmp_path):
    f = run(tmp_path, "other")
    assert f["RETURN"] == ["true"]                     # nothing to repair: as before
    assert any(l.startswith("warn\t") and "something 7-Zip wants known" in l for l in f["LOG"]), f["LOG"]
    assert not any("chained" in l for l in f["LOG"])
