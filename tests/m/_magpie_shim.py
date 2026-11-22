"""Run an installed package's shim and xlings itself, without a login shell.

The shim is located under the SubOS the job installed into (`XLINGS_TEST_SUBOS`
in CI) and executed by path. `bash -l -c <program>` would be the shorter
route, but a login shell rebuilds PATH from the profile: on Windows' Git Bash
that drops the home's `subos/default/bin` entirely, so the assertion would
report "command not found" for a package whose shim exists and runs.

For the same reason, `install_package` runs xlings directly rather than
through `tests/lib/xlings_client.py`: that helper spawns `bash`, and on the
Windows runner `bash` resolves to `C:\\Windows\\System32\\bash.exe` (the WSL
launcher) before Git Bash, which prints a UTF-16 "no installed distributions"
error and never runs xlings.
"""
import os
import shutil
import subprocess

from tests.lib.platform_utils import xlings_home


def xlings(*args, timeout=900):
    executable = shutil.which("xlings")
    if not executable:
        raise AssertionError("xlings is not on PATH")
    result = subprocess.run(
        [executable, *args], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=timeout,
        env={**os.environ, "HOME": os.path.expanduser("~")},
    )
    return result.returncode, result.stdout + result.stderr


def install_package(spec, timeout=900):
    code, out = xlings("install", spec, "-y", timeout=timeout)
    ok = code == 0 and ("installed" in out.lower() or "already installed" in out.lower())
    return ok, out


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