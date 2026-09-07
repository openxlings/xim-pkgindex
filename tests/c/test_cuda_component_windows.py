"""The NVIDIA redistributable components that declare a Windows section.

WHY THIS FILE IS NOT A PER-PACKAGE TEST. Twenty-four recipes in this index
install an NVIDIA redistributable component, and they share one shape: locate
the unpacked archive, move it, then scan the payload for programs and
libraries. Four of them now also publish a Windows section, and the shared
shape was written for Linux -- POSIX `find` with GNU flags, an archive suffix
of `.tar.xz`, libraries named `*.so*`.

The denominator therefore comes from the tree rather than from a list kept
here: every recipe carrying that scan AND a Windows section must have had the
host-dependent halves adapted. A fifth component gaining a Windows section is
covered the moment it is written, which is the property a hand-written list
cannot have.
"""
import glob
import os
import re

import pytest

from tests.lib.platform_utils import project_root

# The line that identifies the shared component shape.
SCAN_MARK = "-maxdepth 1 ! -type d -executable"


def _code(text: str) -> str:
    return "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("--"))


def _component_recipes():
    """Every recipe using the shared component scan, as (path, source)."""
    out = []
    for p in sorted(glob.glob(os.path.join(project_root(), "pkgs", "*", "*.lua"))):
        with open(p, encoding="utf-8") as f:
            text = f.read()
        if SCAN_MARK in text:
            out.append((os.path.relpath(p, project_root()), text))
    return out


def _windows_components():
    return [(p, t) for p, t in _component_recipes()
            if re.search(r'^\s*windows\s*=\s*\{', _code(t), re.M)]


def test_the_shared_shape_is_still_recognisable():
    """A denominator that can silently become zero is not a denominator.

    This suite selects its subjects by a string that lives in the recipes. If
    that string is reworded, every assertion below passes over an empty set.
    """
    assert len(_component_recipes()) >= 20, \
        f"only {len(_component_recipes())} component recipes matched; has the scan been reworded?"
    assert _windows_components(), "no component recipe declares a windows section"


@pytest.mark.static
@pytest.mark.parametrize("rel,text", _windows_components(),
                         ids=[p for p, _ in _windows_components()])
class TestWindowsComponents:
    def test_declares_a_download_and_a_hash(self, rel, text):
        code = _code(text)
        block = code[code.index("windows = {"):]
        assert "source =" in block or "url " in block or "url=" in block, \
            f"{rel}: the windows section declares no download"
        assert re.search(r'sha256\s*=', block), f"{rel}: the windows section declares no sha256"
        assert "windows-x86_64" in block, \
            f"{rel}: the windows section does not name a windows-x86_64 archive"

    def test_the_archive_suffix_is_recognised(self, rel, text):
        """The Windows components are zips. `payload_root` strips the suffix to
        find the unpacked directory by name, and a stem that keeps `.zip`
        matches nothing -- sending the lookup into a scan of the SHARED
        download directory, where the first sibling with a `bin/` wins."""
        code = _code(text)
        assert 'gsub("%.zip$", "")' in code, \
            f"{rel}: publishes a .zip but payload_root only strips .tar.xz"

    def test_the_payload_listing_is_per_host(self, rel, text):
        """`find` on Windows is System32's content search: it rejects these
        flags, writes a usage error, and returns nothing. A component that
        registers nothing is indistinguishable from one with no programs."""
        code = _code(text)
        assert 'is_host("windows")' in code, \
            f"{rel}: the payload listing is the POSIX one on every host"
        assert re.search(r'dir /b /a-d', code), \
            f"{rel}: no Windows listing command"

    def test_no_posix_only_command_runs_unguarded(self, rel, text):
        """`ln` is the one this shape reaches for, and it is reached only when
        a release splits its back end out. Windows publishes the line that does
        not, so the branch must refuse rather than run."""
        code = _code(text)
        if "ln -sfn" not in code:
            return
        assert re.search(r'is_host\("windows"\)\s+and\s+next\(split\)', code), \
            f"{rel}: calls ln with no host guard"
