"""graphics: telling apart the four things a vendor library can be.

`graphics.host_vendor_behind` used to return nil for three unrelated
situations, and `pkgs/g/graphics.lua` turned every nil into `state=native` --
which `xlings subos info` renders as a PASS.

Measured on a real NVIDIA home (2026-08-11): all six vendors were recorded
`native` while the graphics stack was wired into no subos at all, `<subos>/lib`
held zero GL libraries, and GL rendered in software. Four independent channels
reported health for a stack that could not work.

Two conflations produced that, and each has a case here:

* `os.iorun` returns "" when the tool is missing, so "readelf did not run"
  became "this is our own build, nothing to check". The sibling function
  `vendor_closure_gaps` guards exactly this and says so in its own comment --
  the guard existed, one function away.

* since nvidia-gl-host-link 0.1.2 the GLX and GLES vendors are DIRECT SYMLINKS
  to the host driver. A host library has no absolute DT_NEEDED (it names its
  siblings by soname), so "no absolute entry" read as "our own build". It is
  literally the host driver, and the verdict was inverted for precisely the
  vendors that most needed checking.

The fixtures are text, not ELF: the function reads `readelf -d` output and a
`readlink -f` result, so forging those directly tests the logic without
needing a compiler -- and the ABSENCE of the readelf sidecar is how the
"tool did not run" case is reproduced, which is the case that mattered.

Design: xlings/.agents/docs/2026-08-11-five-issues-triage-and-plan.md §2.4
"""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "graphics_vendor_form_harness.lua"
GRAPHICS = REPO / "libs" / "graphics.lua"


def test_graphics_lib_exists():
    assert GRAPHICS.is_file(), "libs/graphics.lua is the shared wiring probe"


def test_caller_never_maps_a_missing_tool_to_a_pass():
    """An INVARIANT, in pure Python, that always runs.

    `state=native` is a pass. It may only be written where the recipe has
    established the vendor is our own build -- never on the path where a tool
    failed to run. Grepping for the pairing is crude, but it is the shape that
    regressed, and it regresses by someone reintroducing `if not host then`.
    """
    text = (REPO / "pkgs" / "g" / "graphics.lua").read_text(encoding="utf-8")
    assert 'form == "native"' in text, (
        "the native verdict must be gated on the explicit form, not on a "
        "nil that also means 'readelf did not run'"
    )
    assert "if not host then" not in text, (
        "a bare nil test is the conflation this file exists to prevent: it "
        "maps 'tool missing' and 'host driver symlinked in' onto a pass"
    )


@pytest.mark.skipif(
    shutil.which("lua5.4") is None and shutil.which("lua") is None,
    reason="no lua interpreter on this machine",
)
def test_vendor_form_is_distinguished(tmp_path):
    lua = shutil.which("lua5.4") or shutil.which("lua")

    fix = tmp_path / "fixtures"
    (fix / "xpkgs").mkdir(parents=True)
    host_dir = tmp_path / "hostlib"
    host_dir.mkdir()
    (host_dir / "libGLX_nvidia.so.0").write_text("host driver")

    # 1. interposed: a stub of ours naming the host driver ABSOLUTELY.
    (fix / "interposed.so").write_text("stub")
    (fix / "interposed.so.readelf").write_text(
        " 0x0000000000000001 (NEEDED) Shared library: "
        f"[{host_dir}/libGLX_nvidia.so.0]\n"
    )

    # 2. unreadable: no sidecar, so `readelf` yields "". The tool did not run.
    (fix / "unreadable.so").write_text("something")

    # 3. direct: no absolute DT_NEEDED, and the file resolves to a host path.
    (fix / "direct.so").symlink_to(host_dir / "libGLX_nvidia.so.0")
    (fix / "direct.so.readelf").write_text(
        " 0x0000000000000001 (NEEDED) Shared library: [libnvidia-glcore.so.550]\n"
    )

    # 4. native: no absolute DT_NEEDED and it resolves inside a store.
    (fix / "xpkgs" / "ours.so").write_text("our build")
    (fix / "xpkgs" / "ours.so.readelf").write_text(
        " 0x0000000000000001 (NEEDED) Shared library: [libc.so.6]\n"
    )

    proc = subprocess.run(
        [lua, str(HARNESS)],
        env={"FAKE_ROOT": str(REPO), "FIXTURE_DIR": str(fix), "PATH": "/usr/bin:/bin"},
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr


# ─── provenance: every recorded verdict names the payload it is about ───────
#
# The `.wiring` record is written by ONE package (`graphics`) and every line in
# it is about ANOTHER (mesa, libglvnd, nvidia-gl-host-link). Those upgrade on
# their own schedule and nothing made a verdict expire when its subject moved.
# Measured on a real home: the record was written at 01:37:17 and the nvidia
# payload it speaks for at 01:38:14 -- 57 seconds AFTER the verdict about it.
#
# The reader (xlings subos/graphics.cppm) compares the wired symlink against
# `payload=` and reports STALE when it no longer lands inside. That check is
# inert for any line missing the field, so the invariant that matters here is
# that NO branch can emit a line without it.

_GRAPHICS_RECIPE = Path(__file__).resolve().parents[1] / "pkgs" / "g" / "graphics.lua"


def test_every_wiring_line_goes_through_the_single_builder():
    """One writer, six branches.

    There are six places that record a verdict (unverified x2, native,
    needs-transitive-consumer, broken, ok). A regex-shaped edit that adds a
    seventh by copying `"vendor=" .. soname` would parse fine, produce a
    plausible record, and silently drop the provenance for exactly that state
    -- and the reader would then never call it stale. Asserting the raw
    construction does not appear is what keeps the builder singular.
    """
    text = _GRAPHICS_RECIPE.read_text(encoding="utf-8")
    assert 'local function vendor_line(soname, dir, rest)' in text
    assert 'payload=" .. dir' in text, "the builder no longer records provenance"
    body = text[text.index("local function vendor_line"):]
    # Inside the builder itself the literal is expected; anywhere after it, a
    # raw `table.insert(lines, "vendor=` is a branch that bypassed it.
    after_builder = body[body.index("local lines = {"):]
    assert 'table.insert(lines, "vendor=' not in after_builder, (
        "a wiring line is built without payload=; the reader cannot expire it"
    )


def test_provenance_is_last_on_the_line():
    """A payload path may contain a space.

    The reader tokenises a vendor line on spaces and takes everything after
    ` payload=` as the remainder, exactly as it already does for `dispatch=`.
    That only works while the field is last.
    """
    text = _GRAPHICS_RECIPE.read_text(encoding="utf-8")
    m = re.search(r'return "vendor=" \.\. soname \.\. " " \.\. rest'
                  r' \.\. " payload=" \.\. dir', text)
    assert m, ("the builder's field order changed; the reader takes the rest "
               "of the line after ` payload=` and would swallow later fields")
