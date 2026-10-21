"""Every Luban program says how it is checked (xlings design 2026-10-21 §6.1).

A `luban:` package with programs declares its checks -- in its recipe
(extensions.luban.checks: `run`, `launcher`, `gui`, `sound`) or in the tree
its payload is built from (tools/res/luban/<name>/share/luban/checks.d) --
and every declared check is one of those kinds, with an id and what it checks.
"""
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
KINDS = ("run", "launcher", "gui", "sound")


def luban_recipes():
    for f in sorted((ROOT / "pkgs/luban").glob("*.lua")):
        text = f.read_text()
        m = re.search(r"\bprograms\s*=\s*\{([^}]*)\}", text)
        if m and re.search(r'"[^"]+"', m.group(1)):
            yield f, text


def declared_in_recipe(text):
    m = re.search(r"\bchecks\s*=\s*\{", text)
    if not m:
        return None
    depth, i = 1, m.end()
    while i < len(text) and depth:
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return text[m.end():i - 1]


@pytest.mark.static
@pytest.mark.parametrize("recipe,text", list(luban_recipes()), ids=lambda v: v.stem if isinstance(v, Path) else "")
def test_a_luban_program_declares_its_checks(recipe, text):
    name = recipe.stem
    in_payload = (ROOT / "tools/res/luban" / name / "share/luban/checks.d").is_dir()
    declared = declared_in_recipe(text)
    assert in_payload or declared, f"luban:{name} has programs and declares no checks (extensions.luban.checks)"
    if declared:
        for entry in re.findall(r"\{([^{}]*)\}", declared):
            assert re.search(r'\bid\s*=\s*"', entry), f"luban:{name}: a check without an id: {entry.strip()}"
            assert re.search(r'\bwhat\s*=\s*"', entry), f"luban:{name}: a check without what it checks: {entry.strip()}"
            assert any(re.search(rf"\b{k}\s*=", entry) for k in KINDS), f"luban:{name}: a check of no kind ({KINDS}): {entry.strip()}"
