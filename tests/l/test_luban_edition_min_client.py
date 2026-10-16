"""An edition's version entry names the client its manifest needs.

The manifest's `min_client` is read only after the edition is fetched; a
client that cannot use the newest edition was refused there, and stopped
(xlings-ci-luban-fresh, 2026-10-16: `subos:luban-tiny needs xlings >=
2026.10.16.1, this is 2026.10.15.4`). The version entry carries the same
value, so a client resolving an edition with no version named (xlings
2026.10.16.2 and later) passes over the ones it cannot use before fetching
anything. The two must agree.
"""
import glob
import os
import re

import pytest

from tests.lib.platform_utils import project_root

ENTRY = re.compile(r'\["(\d{4}\.\d+\.\d+\.\d+)"\] = \{ min_client = "([^"]+)" \}')
BLOCK = re.compile(r'\n    \["(\d{4}\.\d+\.\d+\.\d+)"\] = \{')


def manifests(source):
    blocks = list(BLOCK.finditer(source))
    out = {}
    for i, block in enumerate(blocks):
        end = blocks[i + 1].start() if i + 1 < len(blocks) else len(source)
        found = re.search(r'"min_client":\s*"([^"]+)"', source[block.end():end])
        if found:
            out[block.group(1)] = found.group(1)
    return out


@pytest.mark.static
@pytest.mark.parametrize("recipe", sorted(glob.glob(os.path.join(project_root(), "pkgs/luban/luban-*.lua"))),
                         ids=os.path.basename)
def test_entry_and_manifest_agree(recipe):
    with open(recipe, encoding="utf-8") as handle:
        source = handle.read()
    declared = manifests(source)
    entries = dict(ENTRY.findall(source))
    assert entries == declared, f"version entries {entries} vs manifests {declared}"
