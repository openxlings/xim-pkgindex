"""A library payload does not carry the compiler's C++ runtime.

The rule (decision D3 of the 2026-09-28 ecosystem design, mcpp-community/mcpp
`.agents/docs/2026-09-28-ecosystem-design-and-optimisation-plan.md`; the
recipe rule in docs/10-adding-a-package.md, Rules that keep packages correct): no recipe places a file of the MSVC C++
runtime set (`vcruntime140*.dll`, `msvcp140*.dll`, `concrt140.dll`,
`vccorlib140.dll`, the `Microsoft.VC*.CRT` redistributable directory) into its
payload, with one exception: the toolset package itself, whose redistributable
directory IS the compiler's runtime.

WHY. A program's C++ runtime must be at least as new as the newest toolset
that built one of its images. The build that links the program knows that
toolset; a library payload does not, and its copy is whatever version its
recipe pinned. mcpp placed `xim:qt-base`'s copy (14.44) beside programs built
with a newer toolset (review 2026-09-28 §2.1), and since 2026.9.28.2 it
prefers the toolset's set and states a dependency's copy as a packaging fault.
A payload's own host tools (Qt's `moc.exe`) start with the toolset's runtime,
which the engine puts first on every action's PATH for a Windows target.

The check reads recipe source: code lines, not comments, that name the
redistributable archive, its CRT directory, or a runtime DLL.
"""
import pathlib
import re

import pytest

REPO = pathlib.Path(__file__).resolve().parent.parent

# The toolset packages: their redistributable directory is the compiler's
# runtime, the one mcpp places and puts on PATH.
TOOLSET_RECIPES = {
    "pkgs/m/msvc.lua",
}

CRT_REFERENCE = re.compile(
    r"CRT\.Redist"                      # the redistributable vsix
    r"|Microsoft\.VC\d+\.CRT"           # its CRT directory
    r"|vcruntime140\w*\.dll"
    r"|msvcp140\w*\.dll"
    r"|concrt140\.dll"
    r"|vccorlib140\.dll",
    re.IGNORECASE,
)


def _code_lines(src: str):
    """The recipe's lines with Lua comments removed (`--` to the end of the
    line, outside a string is not tracked: a CRT name inside a comment is
    documentation, and one inside a string on a code line is code)."""
    for number, line in enumerate(src.splitlines(), start=1):
        stripped = line.lstrip()
        if stripped.startswith("--"):
            continue
        cut = line.find(" --")
        yield number, line if cut == -1 else line[:cut]


def _offending(path: pathlib.Path):
    src = path.read_text(encoding="utf-8", errors="replace")
    for number, line in _code_lines(src):
        match = CRT_REFERENCE.search(line)
        if match:
            yield number, match.group(0)


@pytest.mark.static
def test_no_library_payload_places_the_msvc_runtime():
    bad = []
    for lua in sorted((REPO / "pkgs").rglob("*.lua")):
        rel = lua.relative_to(REPO).as_posix()
        if rel in TOOLSET_RECIPES:
            continue
        for number, what in _offending(lua):
            bad.append(f"{rel}:{number}: {what}")
    assert not bad, (
        "a library payload places the MSVC C++ runtime; the program's build "
        "places the toolset's (docs/10-adding-a-package.md, Rules that keep packages correct):\n  "
        + "\n  ".join(bad))


@pytest.mark.static
def test_the_toolset_exemption_names_existing_recipes():
    # An exemption for a recipe that no longer exists would silently exempt
    # whatever takes its path next.
    missing = [r for r in TOOLSET_RECIPES if not (REPO / r).is_file()]
    assert not missing, f"exempted recipes that do not exist: {missing}"
