"""xlings' release owns the versions of what it publishes.

xlings, luban, luban-os and xim:xdesk are released by openxlings/xlings: their
assets go to xlings-res and GitCode first, then each version is written here
as `XLINGS_RES` with the release's sha256 (xlings AGENTS.md, "Versions and
releases"). A second writer -- `extensions.autoupdate` -- writes another shape
that this index's own tests refuse, and its candidate install of the client
(`local:xlings@...`) is refused by xlings by design: xlings 2026.10.23.1 could
not be indexed (xlings design 2026-10-23 part 3, R1).
"""
import re
from pathlib import Path

import pytest

pytestmark = pytest.mark.static
ROOT = Path(__file__).resolve().parents[1]
RELEASE_OWNED = ("pkgs/x/xlings.lua", "pkgs/luban/luban.lua", "pkgs/luban/luban-os.lua", "pkgs/x/xdesk.lua")


@pytest.mark.parametrize("recipe", RELEASE_OWNED)
def test_a_release_owned_package_has_no_autoupdate(recipe):
    text = (ROOT / recipe).read_text(encoding="utf-8")
    assert not re.search(r"(?m)^\s*autoupdate\s*=", text), \
        f"{recipe}: its versions are written by xlings' release, not by autoupdate"


@pytest.mark.parametrize("recipe", RELEASE_OWNED)
def test_its_latest_is_an_xlings_res_entry(recipe):
    text = (ROOT / recipe).read_text(encoding="utf-8")
    xpm = text.index("    xpm = {")
    for latest in re.finditer(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([0-9.]+)"', text[xpm:]):
        version = latest.group(1)
        entry = re.search(r'\["' + re.escape(version) + r'"\]\s*=\s*\{\s*url\s*=\s*"XLINGS_RES"', text[xpm:])
        assert entry, f"{recipe}: latest {version} is not an XLINGS_RES entry"
