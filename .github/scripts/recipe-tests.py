#!/usr/bin/env python3
"""Run the lifecycle and verify tests of the recipes a change edits.

A recipe's test module states what its installed payload must be: the files a
consumer reads, the manifest of a base package, the output of its programs
(docs/20-testing.md, levels L3 and L4). The install job installs and removes
the planned recipes; this step runs the module of each recipe the change
edits, on the host of the job, so the statement is checked where the payload
was just installed.

    recipe-tests.py pkgs/a/aarch64-linux-gnu-sysroot.lua ...

A recipe without a module, or whose module has no test of these levels for
this host, is named in the summary and is not a failure: the levels below
(static, isolation) and the install itself have run for it. A failing test
fails the job.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
NO_TESTS = 5   # pytest: nothing was collected or everything was deselected


def module_of(recipe):
    path = pathlib.PurePosixPath(recipe)
    return ROOT / "tests" / path.parent.name / ("test_" + path.stem.replace("-", "_") + ".py")


def main(recipes):
    without, failed = [], []
    for recipe in recipes:
        module = module_of(recipe)
        if not module.is_file():
            without.append(f"{recipe}: no test module ({module.relative_to(ROOT)})")
            continue
        print(f"::group::{recipe}", flush=True)
        code = subprocess.call([sys.executable, "-m", "pytest", str(module), "-m", "lifecycle or verify",
                                "--tb=short", "-q", "-x", "-rs"], cwd=ROOT)
        print("::endgroup::", flush=True)
        if code == NO_TESTS:
            without.append(f"{recipe}: no lifecycle or verify test")
        elif code != 0:
            failed.append(recipe)
    for line in without:
        print(line)
    for recipe in failed:
        print(f"::error::{recipe}: its lifecycle or verify tests failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
