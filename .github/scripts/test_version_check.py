#!/usr/bin/env python3
"""Offline tests for version-check.py.

Self-contained (no pytest): run `python3 .github/scripts/test_version_check.py`.
Exit 0 = all pass, non-zero = failure. Network/resource discovery is replaced
with deterministic test data.
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
    print("test_res_apply_bump writes dual-compatible checked entries")
    original = vc.resolve_res_hashes
    vc.resolve_res_hashes = lambda *args, **kwargs: {
        "linux": {"x86_64": "a" * 64, "aarch64": "b" * 64},
        "macosx": {"aarch64": "c" * 64},
        "windows": {"x86_64": "d" * 64},
    }
    try:
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
            check('["0.4.61"] = "XLINGS_RES"' not in out, "new target is never a bare sentinel")
            check(out.count('url = "XLINGS_RES"') == 3, "keeps the V1-compatible URL sentinel")
            check(out.count("sha256 = {") == 3, "writes per-arch checksum tables")
            check('x86_64 = "' + "a" * 64 + '"' in out, "writes linux x86_64 hash")
            check('aarch64 = "' + "b" * 64 + '"' in out, "writes linux aarch64 hash")
            check('["0.4.60"] = "XLINGS_RES"' in out, "old version entry preserved")
    finally:
        vc.resolve_res_hashes = original


def test_res_apply_bump_fails_closed_without_complete_hashes():
    print("test_res_apply_bump fails closed when resource verification fails")
    original = vc.resolve_res_hashes
    vc.resolve_res_hashes = lambda *args, **kwargs: {
        "status": "error", "reason": "missing sidecar for windows"
    }
    try:
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "xlings.lua"
            p.write_text(RES_FIXTURE, encoding="utf-8")
            before = p.read_text(encoding="utf-8")
            result = vc.apply_bump(
                p, current="0.4.60", upstream="0.4.61",
                proposed_urls={}, token=None,
                res_platforms=["linux", "macosx", "windows"],
            )
            check(result["status"] == "error", "verification error aborts bump")
            check(p.read_text(encoding="utf-8") == before, "failure leaves recipe untouched")
    finally:
        vc.resolve_res_hashes = original


def test_res_hash_discovery_rejects_architecture_regression():
    print("test_res_hash_discovery rejects a missing architecture")
    original_release = vc.github_release_by_tag
    current_assets = [
        "mcpp-1.0.0-linux-x86_64.tar.gz",
        "mcpp-1.0.0-linux-aarch64.tar.gz",
        "mcpp-1.0.0-macosx-arm64.tar.gz",
        "mcpp-1.0.0-windows-x86_64.zip",
    ]
    upstream_assets = [
        "mcpp-1.1.0-linux-x86_64.tar.gz",
        "mcpp-1.1.0-macosx-arm64.tar.gz",
        "mcpp-1.1.0-windows-x86_64.zip",
    ]

    def release(_owner, _name, tag, _token):
        names = current_assets if tag == "1.0.0" else upstream_assets
        assets = []
        for name in names:
            assets.append({"name": name, "browser_download_url": "https://example/" + name})
            assets.append({"name": name + ".sha256", "browser_download_url": "https://example/" + name + ".sha256"})
        return {"assets": assets}

    vc.github_release_by_tag = release
    try:
        result = vc.resolve_res_hashes(
            "mcpp", "1.0.0", "1.1.0",
            ["linux", "macosx", "windows"], None,
        )
        check(result["status"] == "error", "arch set regression aborts verification")
        check("architecture set changed" in result["reason"], "error identifies architecture set")
    finally:
        vc.github_release_by_tag = original_release


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
    test_res_apply_bump_fails_closed_without_complete_hashes()
    test_res_hash_discovery_rejects_architecture_regression()
    test_url_apply_bump_unaffected()
    if _failures:
        print(f"\n{len(_failures)} FAILURE(S)")
        raise SystemExit(1)
    print("\nAll tests passed.")
