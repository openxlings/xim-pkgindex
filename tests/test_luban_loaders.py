"""A Luban component's own musl loader searches only its tree (xlings design
2026-10-21 J12): luban_component.config writes an empty ld-musl-<arch>.path
beside every loader under libexec/, and every component recipe goes through
it -- a library dlopen()ed from a glibc system's /usr/lib (libvulkan) crashed
Falkon in a Luban machine.
"""
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


def component_recipes():
    for f in sorted((ROOT / "pkgs/luban").glob("*.lua")):
        text = f.read_text()
        if "luban_component" in text:
            yield f, text


@pytest.mark.static
def test_config_closes_every_loader():
    lib = (ROOT / "libs/luban_component.lua").read_text()
    body = lib[lib.index("function M.close_loaders()"):lib.index("function M.config(")]
    assert 'os.dirs(path.join(pkginfo.install_dir(), "libexec", "*"))' in body
    assert '"ld-musl-" .. arch .. ".path"' in body and 'io.writefile(file, "")' in body
    config = lib[lib.index("function M.config("):]
    assert config.split("\n")[1].strip() == "M.close_loaders()", "the first thing config does"


@pytest.mark.static
@pytest.mark.parametrize("recipe,text", list(component_recipes()), ids=lambda v: v.stem if isinstance(v, Path) else "")
def test_a_component_is_configured_through_the_library(recipe, text):
    m = re.search(r"\nfunction config\(\)(.*?)\nend\n", text, re.S)
    assert m, f"{recipe.name}: no config()"
    assert "luban_component.config(" in m.group(1), f"{recipe.name}: config() does not go through luban_component.config"
