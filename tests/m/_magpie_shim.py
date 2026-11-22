"""Run an installed package's shim and return its output.

The shim is located under the SubOS the job installed into (`XLINGS_TEST_SUBOS`
in CI) and executed by path. `bash -l -c <program>` would be the shorter
route, but a login shell rebuilds PATH from the profile: on Windows' Git Bash
that drops the home's `subos/default/bin` entirely, so the assertion would
report "command not found" for a package whose shim exists and runs.
"""
import os
import subprocess

from tests.lib.platform_utils import xlings_home


def shim_output(name, *args, timeout=60):
    bases = []
    if os.environ.get("XLINGS_TEST_SUBOS"):
        bases.append(os.environ["XLINGS_TEST_SUBOS"])
    bases += ["current", "default"]
    seen = set()
    for base in bases:
        if not base or base in seen:
            continue
        seen.add(base)
        bin_dir = os.path.join(xlings_home(), "subos", base, "bin")
        for exe in (name, name + ".exe"):
            candidate = os.path.join(bin_dir, exe)
            if os.path.isfile(candidate):
                result = subprocess.run([candidate, *args], capture_output=True,
                                        text=True, timeout=timeout)
                return result.returncode, result.stdout + result.stderr
    raise AssertionError(f"no {name} shim under {xlings_home()}/subos/*/bin")