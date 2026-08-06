"""version-check.py's backfill: which versions are missing, and how many.

The defect these cover, in one line: `up-to-date` used to mean "the `latest`
pointer matches upstream", and that is not the same as "nothing is missing".
Once `latest` reached 2026.8.6.1, the releases skipped on the way there
(2026.8.5.2, 2026.8.5.3) were no longer newer than `latest`, so a
pointer-equality check returned early and never looked at them again. They are
absent from the published index today.

Network-free on purpose: these exercise the pure functions and the set
arithmetic, not the GitHub API.
"""
import importlib.util
import pathlib
import sys

import pytest

_SCRIPT = pathlib.Path(__file__).resolve().parents[2] / ".github/scripts/version-check.py"


def _load():
    spec = importlib.util.spec_from_file_location("version_check", _SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["version_check"] = mod
    spec.loader.exec_module(mod)
    return mod


vc = _load()

pytestmark = pytest.mark.static


# ── version ordering ─────────────────────────────────────────────────

def test_date_stamped_versions_order_numerically():
    """xlings releases are four dotted components, not semver."""
    got = sorted(["2026.8.5.1", "2026.8.6.1", "2026.8.5.3", "2026.8.5.2"],
                 key=vc.version_sort_key)
    assert got == ["2026.8.5.1", "2026.8.5.2", "2026.8.5.3", "2026.8.6.1"]


def test_ten_sorts_after_nine_not_between_one_and_two():
    """A plain string sort puts "0.4.11" before "0.4.9"."""
    got = sorted(["0.4.9", "0.4.11", "0.4.2"], key=vc.version_sort_key)
    assert got == ["0.4.2", "0.4.9", "0.4.11"]


def test_non_numeric_components_do_not_raise():
    """Toolchain-style versions carry flavour tags; ordering them as text is
    enough, crashing is not acceptable."""
    assert vc.version_sort_key("15.1.0-aarch64-musl")


# ── which entries the index already has ──────────────────────────────

def test_extract_version_entries_finds_the_version_keys():
    body = '''
        res_versioned = true,
        ["latest"] = { ref = "2026.8.6.1" },
        ["2026.8.6.1"] = { url = "XLINGS_RES" },
        ["2026.8.5.1"] = { url = "XLINGS_RES" },
    '''
    assert vc.extract_version_entries(body) == {"2026.8.6.1", "2026.8.5.1"}


def test_latest_is_not_a_version_entry():
    """`["latest"]` is a pointer, not a version. Counting it as one would make
    a missing set look complete."""
    body = '["latest"] = { ref = "1.2.3" },'
    assert vc.extract_version_entries(body) == set()


# ── the missing set ──────────────────────────────────────────────────

def _missing(published, present, window=10):
    ordered = sorted(published, key=vc.version_sort_key, reverse=True)[:window]
    return sorted({v for v in ordered if v not in present},
                  key=vc.version_sort_key)


def test_a_current_pointer_does_not_mean_nothing_is_missing():
    """The exact production state on 2026-08-06: `latest` is 2026.8.6.1 and
    two releases below it have no entry."""
    published = ["2026.8.6.1", "2026.8.5.3", "2026.8.5.2", "2026.8.5.1"]
    present = {"2026.8.6.1", "2026.8.5.1"}
    assert _missing(published, present) == ["2026.8.5.2", "2026.8.5.3"]


def test_a_complete_index_is_empty():
    published = ["2026.8.6.1", "2026.8.5.1"]
    present = {"2026.8.6.1", "2026.8.5.1"}
    assert _missing(published, present) == []


def test_the_window_bounds_the_backfill():
    """Without a bound the chain ran back to 0.3.2 -- sixteen entries, each
    costing a sha256 download. The index keeps very old entries on purpose, so
    "older than the oldest entry" is not a usable floor."""
    published = [f"1.0.{i}" for i in range(30)]
    assert len(_missing(published, set(), window=10)) == 10


def test_the_chain_is_ascending():
    """apply_bump walks it, each step seeing the previous as its `current`, so
    the order is load-bearing rather than cosmetic."""
    got = _missing(["2026.8.6.1", "2026.8.5.3", "2026.8.5.2"], set())
    assert got == sorted(got, key=vc.version_sort_key)
