#!/usr/bin/env python3
"""Offline tests for version-check.py — focused on the XLINGS_RES auto-bump
path (and a guard that url_template behaviour is unchanged).

Self-contained (no pytest): run `python3 .github/scripts/test_version_check.py`.
Exit 0 = all pass, non-zero = failure. The res_versioned path needs no
network (no artifact download / sha256), so these tests are deterministic.
"""

import importlib.util
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("vcheck", HERE / "version-check.py")
vc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vc)

_failures = []


def check(cond, msg):
    if cond:
        print(f"  ok: {msg}")
    else:
        print(f"  FAIL: {msg}")
        _failures.append(msg)


RES_FIXTURE = '''package = {
    name = "xlings",
    repo = "https://github.com/openxlings/xlings",
    xpm = {
        linux = {
            res_versioned = true,
            ["latest"] = { ref = "0.4.60" },
            ["0.4.60"] = "XLINGS_RES",
            ["0.4.55"] = "XLINGS_RES",
        },
        macosx = {
            res_versioned = true,
            ["latest"] = { ref = "0.4.60" },
            ["0.4.60"] = "XLINGS_RES",
        },
        windows = {
            res_versioned = true,
            ["latest"] = { ref = "0.4.60" },
            ["0.4.60"] = "XLINGS_RES",
        },
    },
}
'''

URL_FIXTURE = '''package = {
    name = "uv",
    repo = "https://github.com/astral-sh/uv",
    xpm = {
        linux = {
            url_template = "https://example.com/uv-{version}-linux.tar.gz",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = { url = "https://example.com/uv-1.0.0-linux.tar.gz", sha256 = "aa" },
        },
    },
}
'''


def test_extract_res_versioned():
    print("test_extract_res_versioned")
    check(vc.extract_res_versioned("res_versioned = true,") is True, "detects true")
    check(vc.extract_res_versioned('url_template = "x"') is False, "absent -> false")


def test_res_apply_bump():
    print("test_res_apply_bump (offline, no network)")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "xlings.lua"
        p.write_text(RES_FIXTURE, encoding="utf-8")
        result = vc.apply_bump(
            p, current="0.4.60", upstream="0.4.61",
            proposed_urls={}, token=None,
            res_platforms=["linux", "macosx", "windows"],
        )
        out = p.read_text(encoding="utf-8")
        check(result["status"] == "applied", f"status applied (got {result['status']})")
        check(out.count('["latest"] = { ref = "0.4.61" }') == 3, "latest bumped on all 3 platforms")
        check(out.count('["0.4.61"] = "XLINGS_RES"') == 3, "new XLINGS_RES entry on all 3 platforms")
        check('["0.4.60"] = "XLINGS_RES"' in out, "old version entry preserved")
        check("sha256" not in out, "no sha256 written for res entries")
        check(all(v == "XLINGS_RES" for v in result["platforms"].values()),
              "per-platform reports XLINGS_RES")


def test_url_apply_bump_unaffected(monkeypatch_sha="deadbeef"):
    print("test_url_apply_bump still works (sha256 stubbed)")
    orig = vc.compute_sha256
    vc.compute_sha256 = lambda url, token: monkeypatch_sha
    try:
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "uv.lua"
            p.write_text(URL_FIXTURE, encoding="utf-8")
            result = vc.apply_bump(
                p, current="1.0.0", upstream="1.1.0",
                proposed_urls={"linux": "https://example.com/uv-1.1.0-linux.tar.gz"},
                token=None, res_platforms=[],
            )
            out = p.read_text(encoding="utf-8")
            check(result["status"] == "applied", "url-mode status applied")
            check('["latest"] = { ref = "1.1.0" }' in out, "url-mode latest bumped")
            check(f'sha256 = "{monkeypatch_sha}"' in out, "url-mode writes sha256")
            check('["1.1.0"] = {' in out, "url-mode appends url block")
    finally:
        vc.compute_sha256 = orig


if __name__ == "__main__":
    test_extract_res_versioned()
    test_res_apply_bump()
    test_url_apply_bump_unaffected()
    if _failures:
        print(f"\n{len(_failures)} FAILURE(S)")
        raise SystemExit(1)
    print("\nAll tests passed.")
