"""A dirun profile a recipe writes is TOML (docs/12-disk-image-assets.md).

A recipe carries its image's profile as a Lua long string and writes it beside
the image as `dirun.toml`. Lua copies the text as it is; TOML reads `\\` in a
basic string as an escape, so a pattern such as `\\d` or `\\$` must be written
`\\\\d`, or the profile does not parse and the runner stops before it boots. The
profiles are parsed here, from the recipes, without installing anything.
"""
import glob
import os
import re
import tomllib

import pytest

LONG_STRING = re.compile(r"\[(=*)\[(.*?)\]\1\]", re.S)


def _profiles():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for recipe in sorted(glob.glob(os.path.join(root, "pkgs", "**", "*.lua"), recursive=True)):
        with open(recipe, encoding="utf-8") as f:
            text = f.read()
        for n, m in enumerate(LONG_STRING.finditer(text)):
            body = m.group(2)
            if re.search(r"^\[machine\]|^\[command\]|^\[payload\]", body, re.M):
                yield pytest.param(body, id=f"{os.path.basename(recipe)}#{n}")


@pytest.mark.static
@pytest.mark.parametrize("profile", list(_profiles()))
def test_a_dirun_profile_parses(profile):
    tomllib.loads(profile)
