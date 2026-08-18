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


# ── the pointer must never move backwards ────────────────────────────
#
# The chain deliberately contains versions OLDER than `latest` (that is the
# whole point of backfill), and both the report and `--apply` used to take
# `chain[-1]` -- the newest MISSING version -- as the new pointer. For any
# package already sitting on the newest release, every missing version is
# older, so the bot proposed a downgrade. Measured 2026-08-19 against the
# live index: fd 10.4.2 -> 10.4.1, and qemu-riscv 9.2.4-1 -> 8.2.6-1, a whole
# major below a version mcpp pins.

def _pointer_after(chain, current):
    """What `["latest"].ref` says once the chain has been walked."""
    newest = current
    for ver in chain:
        if vc.version_sort_key(ver) > vc.version_sort_key(newest):
            newest = ver
    return newest


def test_pure_backfill_leaves_the_pointer_alone():
    """fd's exact state: on the newest release, nine older entries missing."""
    chain = ["8.7.0", "8.7.1", "9.0.0", "10.0.0", "10.1.0",
             "10.2.0", "10.3.0", "10.4.0", "10.4.1"]
    assert _pointer_after(chain, "10.4.2") == "10.4.2"


def test_a_real_upgrade_still_moves_the_pointer():
    """The guard must not cost the feature: fzf's chain straddles `current`."""
    chain = ["0.68.0", "0.70.0", "0.73.0", "0.73.1",
             "0.74.0", "0.74.1", "0.74.2", "0.74.3"]
    assert _pointer_after(chain, "0.72.0") == "0.74.3"


def test_dashed_upstream_versions_do_not_invert():
    """xPack tags carry a packaging revision (`9.2.4-1`). The component after
    the dot is then non-numeric, which sorts as text -- fine, as long as the
    numeric majors still decide first."""
    assert _pointer_after(["7.0.0-1", "8.2.2-1", "8.2.6-1"], "9.2.4-1") == "9.2.4-1"
    assert vc.version_sort_key("9.2.4-1") > vc.version_sort_key("8.2.6-1")


def test_apply_bump_writes_latest_ref_not_the_appended_version(tmp_path):
    """The append still lands; only the pointer is held back."""
    recipe = tmp_path / "demo.lua"
    recipe.write_text(
        'package = {\n'
        '    xpm = {\n'
        '        linux = {\n'
        '            ["latest"] = { ref = "10.4.2" },\n'
        '            ["10.4.2"] = { url = "u", sha256 = "s" },\n'
        '        },\n'
        '    },\n'
        '}\n', encoding="utf-8")

    original = vc.compute_sha256
    vc.compute_sha256 = lambda url, token=None: "deadbeef"
    try:
        result = vc.apply_bump(
            recipe, "10.4.2", "10.4.1",
            {"linux": "https://example/fd-10.4.1.tar.gz"},
            None, [], [], "10.4.2")
    finally:
        vc.compute_sha256 = original

    assert result["status"] == "applied"
    text = recipe.read_text(encoding="utf-8")
    assert '["latest"] = { ref = "10.4.2" }' in text, "pointer moved backwards"
    assert '["10.4.1"] = {' in text, "backfilled entry was not appended"


def test_apply_bump_defaults_latest_ref_to_upstream(tmp_path):
    """Omitting the argument keeps the pre-fix behaviour for the ordinary
    forward bump, so existing callers are unaffected."""
    recipe = tmp_path / "demo.lua"
    recipe.write_text(
        'package = {\n'
        '    xpm = {\n'
        '        linux = {\n'
        '            ["latest"] = { ref = "0.72.0" },\n'
        '        },\n'
        '    },\n'
        '}\n', encoding="utf-8")

    original = vc.compute_sha256
    vc.compute_sha256 = lambda url, token=None: "deadbeef"
    try:
        vc.apply_bump(recipe, "0.72.0", "0.74.3",
                      {"linux": "https://example/fzf-0.74.3.tar.gz"}, None)
    finally:
        vc.compute_sha256 = original

    assert '["latest"] = { ref = "0.74.3" }' in recipe.read_text(encoding="utf-8")
