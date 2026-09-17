#!/usr/bin/env python3
"""Print the `["latest"].ref` a package descriptor declares for one
platform. Used by runtime-revision-gate.yml to default `mcpp_version` on a
manual dispatch to whatever this index currently tracks as mcpp's latest,
instead of a value hand-copied into the workflow that would drift from
pkgs/m/mcpp.lua the next time `bump(mcpp)` runs.

Usage: print-latest-ref.py <path-to-lua> [--platform linux]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lua_table import platform_body, latest_ref  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pkg_file", type=Path)
    ap.add_argument("--platform", default="linux")
    args = ap.parse_args()

    source = args.pkg_file.read_text(encoding="utf-8")
    ref = latest_ref(platform_body(source, args.platform))
    if ref is None:
        print(f"error: no ['latest'].ref found in {args.pkg_file} [{args.platform}]", file=sys.stderr)
        return 1
    print(ref)
    return 0


if __name__ == "__main__":
    sys.exit(main())
