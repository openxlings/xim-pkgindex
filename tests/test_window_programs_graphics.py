"""A package that opens a window on Linux draws through the graphics stack.

On the loader of an xlings home a program sees neither the host's GL nor
any other: without `xim:graphics` (its libraries on the RPATH, its discovery
variables on the shim) SDL, Qt and GTK fall back to software rendering without
a word. luban-os shipped that way and took 47% of a core for a moving pointer
where the stack takes 2% (xlings: 2026-10-18 Luban OS distribution design,
E13).

What says "this opens a window" here is a menu entry: a Linux recipe that
writes a freedesktop `[Desktop Entry]` into an applications directory depends
on `xim:graphics`, or says why not with a `graphics-ok: <why>` comment -- a
program on the host's loader, for one, uses the host's stack. A desktop
session's entry (share/wayland-sessions) is not one: the session draws inside
a Luban system. Libraries categorised `gui` (gtk3, qt-base) open nothing
themselves; their consumers do.
"""
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
GRAPHICS = re.compile(r'"(?:xim:)?graphics(?:@[^"]*)?"')


def _recipes():
    return sorted(ROOT.glob("pkgs/*/*.lua"))


def _opens_a_window_on_linux(text):
    return "[Desktop Entry]" in text and "applications" in text and "linux" in text


@pytest.mark.static
@pytest.mark.parametrize("recipe", _recipes(), ids=lambda p: f"{p.parent.name}/{p.name}")
def test_window_program_depends_on_graphics(recipe):
    text = recipe.read_text(encoding="utf-8")
    if not _opens_a_window_on_linux(text):
        return
    assert GRAPHICS.search(text) or "graphics-ok:" in text, (
        f"{recipe.relative_to(ROOT)} writes a desktop entry on Linux but does not depend on "
        "xim:graphics: on this home's loader its program renders in software without a word. "
        "Depend on xim:graphics (and on what the program loads itself: luban-os.lua), "
        "or say why not with a `graphics-ok: <why>` comment.")


@pytest.mark.static
def test_the_check_sees_a_window_program():
    """The rule is not vacuous: luban-os writes an entry and is held to it."""
    text = (ROOT / "pkgs/luban/luban-os.lua").read_text(encoding="utf-8")
    assert _opens_a_window_on_linux(text)
    assert GRAPHICS.search(text)
