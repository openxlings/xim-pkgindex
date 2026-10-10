"""A published Luban version's output never changes (xlings: Luban OS design part 2 §2.6).

tests/fixtures/luban-published.json holds, for every published version of a
Luban recipe, the sha256 and mode of every file its install() writes. A
recipe may move to libs/luban.lua, gain versions, change its unpublished
ones -- never change what a published one writes.

Regenerate only when a version is PUBLISHED (added to the fixture), never to
absorb a change: LUBAN_PUBLISHED_ADD=<recipe>@<version> pytest -k published
"""
import hashlib
import json
import os
from pathlib import Path

import pytest

from tests.lib.luban_recipe import run_recipe

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/fixtures/luban-published.json"


def output_of(recipe, version, tmp_path, libs=None):
    target = tmp_path / f"{Path(recipe).stem}-{version}"
    kwargs = {"libs": libs} if libs else {}
    result = run_recipe(recipe, target, version=version, **kwargs)
    assert result.returncode == 0, result.stderr + result.stdout
    files = {}
    for f in sorted(target.rglob("*")):
        if f.is_file():
            files[str(f.relative_to(target))] = {
                "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
                "mode": oct(f.stat().st_mode & 0o777)[2:],
            }
    return files


def published():
    return json.loads(FIXTURE.read_text())


@pytest.mark.static
@pytest.mark.parametrize("key", sorted(published()))
def test_a_published_version_writes_what_it_published(key, tmp_path):
    recipe, version = key.rsplit("@", 1)
    assert output_of(ROOT / recipe, version, tmp_path) == published()[key]


@pytest.mark.static
def test_every_published_version_is_still_offered():
    for key in published():
        recipe, version = key.rsplit("@", 1)
        text = (ROOT / recipe).read_text()
        assert f'["{version}"]' in text, f"{key}: a published version cannot be withdrawn"


if os.environ.get("LUBAN_PUBLISHED_ADD"):
    def test_add_published(tmp_path):
        key = os.environ["LUBAN_PUBLISHED_ADD"]
        recipe, version = key.rsplit("@", 1)
        data = published() if FIXTURE.exists() else {}
        data[key] = output_of(ROOT / recipe, version, tmp_path)
        FIXTURE.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n")
