#!/usr/bin/env python3
"""The published xlings reads what xlings' release writes here (U6).

xlings, luban, luban-os and xim:xdesk are written by xlings' release
(tests/test_release_owned.py). What reads them is the client: installs, `self
update`, and xlings' own rootfs self-update test, which picks the release
before its candidate from `interface package_info` (xlings design 2026-10-23
part 3, U5). A change to one of these recipes is checked here the same way,
with the published xlings, against this checkout: on every platform the
package answers, `latest` is one of its versions, and xlings has a release
before its latest.

    scripts/test-release-owned-client.py --home DIR [--xlings PATH]
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = {
    "xim:xlings": ("linux", "macosx", "windows"),
    "xim:luban": ("linux", "macosx", "windows"),
    "xim:luban-os": ("linux", "macosx", "windows"),
    "xim:xdesk": ("linux",),
}


def number(version):
    return tuple(int(part) for part in version.split("."))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument("--xlings", default=shutil.which("xlings"))
    args = parser.parse_args()
    if not args.xlings:
        raise SystemExit("no xlings on PATH (--xlings)")
    if args.home.exists():
        raise SystemExit(f"{args.home} exists; a new home is made here")
    (args.home / "bin").mkdir(parents=True)
    entry = args.home / "bin/xlings"
    shutil.copy2(os.path.realpath(args.xlings), entry)
    (args.home / ".xlings.json").write_text(json.dumps(
        {"mirror": "GLOBAL", "index_repos": [{"name": "xim", "url": str(ROOT)}]}))
    env = {k: v for k, v in os.environ.items() if not k.startswith("XLINGS_")}
    env["XLINGS_HOME"] = str(args.home)

    def xlings(*words):
        return subprocess.run([str(entry), *words], env=env, cwd=args.home, capture_output=True, text=True)

    version = xlings("--version")
    print(version.stdout.strip())
    init = xlings("self", "init")
    if init.returncode != 0:
        raise SystemExit(f"self init: {init.stdout}{init.stderr}")

    failures = []
    for package, platforms in PACKAGES.items():
        for platform in platforms:
            run = xlings("interface", "package_info", "--args", json.dumps({"target": package, "platform": platform}))
            events = [json.loads(line) for line in run.stdout.splitlines() if line.startswith("{")]
            info = next((e["payload"].get("package", {}) for e in events if e.get("dataKind") == "info_panel"), {})
            versions, latest = info.get("versions", []), info.get("version", "")
            where = f"{package} ({platform})"
            if run.returncode != 0 or not info:
                failures.append(f"{where}: package_info answered nothing (exit {run.returncode}) {run.stderr[-300:]}")
            elif not versions:
                failures.append(f"{where}: no versions (an xlings before 2026.10.23.2 does not list them)")
            elif latest not in versions:
                failures.append(f"{where}: latest {latest} is not one of its versions")
            elif package == "xim:xlings" and not [v for v in versions if number(v) < number(latest)]:
                failures.append(f"{where}: no release before {latest}")
            else:
                print(f"ok   {where}: latest {latest}, {len(versions)} versions")
    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
