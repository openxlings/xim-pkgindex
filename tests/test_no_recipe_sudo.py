"""A recipe never runs sudo itself (Luban OS part 3 §8.2).

An install that nobody watches -- `xlings self doctor --fix` repairing another
SubOS, the Luban OS window, an agent -- has no terminal to ask a password on:
a recipe's own `sudo` waited there forever. A step only an administrator may
take is declared with `system.admin_step(argv, why)` (libxpkg 0.0.63): xlings
asks once after the install, through its one door, or keeps the step for
`xlings self doctor --fix`.

What remains is marked where it is: a command a person runs at their terminal
(a helper's own action), or a package that is the host's package manager by
definition. `-- elevation-ok: <why>` on the line says which.
"""
import glob
import os
import re

import pytest

RUN_SUDO = re.compile(
    r"\b(os\.exec|os\.execute|os\.iorun|os\.vrun|os\.run|io\.popen|system\.exec|system\.run_in_script)"
    r"\s*\(\s*(string\.format\(\s*)?(\[\[|[\"'])\s*sudo\b")


def _recipes():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return sorted(glob.glob(os.path.join(root, "pkgs", "**", "*.lua"), recursive=True))


@pytest.mark.static
@pytest.mark.parametrize("recipe", _recipes(), ids=lambda p: os.path.basename(p))
def test_a_recipe_does_not_run_sudo(recipe):
    bad = []
    with open(recipe, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            if RUN_SUDO.search(line) and "elevation-ok:" not in line:
                bad.append(f"{n}: {line.strip()}")
    assert not bad, (
        "a recipe runs sudo itself; declare the step with system.admin_step(argv, why) "
        "(or mark a person's own terminal action `-- elevation-ok: <why>`):\n  " + "\n  ".join(bad))
