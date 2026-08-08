#!/usr/bin/env bash
# A recipe hook must not block on stdin.
#
# THE DEFECT
# ----------
# `io.read()` inside an install hook does not degrade when nobody is there to
# answer it -- it blocks forever. An unattended install (CI, a Dockerfile, a
# provisioning script, `xlings install <pkg> -y`) then HANGS rather than
# failing, and a hang is strictly worse than an error: there is nothing to
# read, and from the outside "slow" and "stuck" look identical.
#
# Measured 2026-08-08: `rust`'s windows hook asked
#
#     please input (1 or 2):
#
# and a windows-test job sat on it for four hours -- against a normal runtime of
# under three minutes for that job. GitHub does not serve logs for an
# in-progress job, so there was no way to see the prompt until someone watched
# the runner live.
#
# It had been unreachable in CI by accident: `rust` declared a dependency that
# resolved to nothing, so the install aborted before reaching the prompt.
# Repairing that namespace is what let the hook run for the first time. That is
# the shape to expect here -- these do not announce themselves, they wait behind
# some other bug.
#
# THE RULE
# --------
# `io.read` is allowed only in a file that also consults the environment for the
# answer, so the same decision can be made without a terminal. The pattern is:
#
#     local want = os.getenv("XLINGS_<SOMETHING>")   -- honour an explicit answer
#     if os.getenv("XLINGS_NON_INTERACTIVE") or os.getenv("CI") then ... end
#     -- only then prompt
#
# `io.readfile` is a different function and is not matched.
#
# Exit codes follow .agents/tools/README.md: 0 proven, 1 broken, 3 could-not-run.
set -uo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT_DIR" || { echo "::error::cannot cd to $ROOT_DIR"; exit 3; }

command -v grep >/dev/null 2>&1 || { echo "  [SKIP] no grep"; exit 3; }

# `io.read` but not `io.readfile`. -w is not enough: `io.readfile` contains
# `io.read` as a prefix, so anchor on the character that follows.
mapfile -t hits < <(grep -rnE 'io\.read[^f]' pkgs/ libs/ 2>/dev/null || true)

scanned=$(find pkgs libs -name '*.lua' 2>/dev/null | wc -l)
bad=0

for hit in "${hits[@]:-}"; do
    [[ -n "$hit" ]] || continue
    file="${hit%%:*}"
    # A commented line is documentation, not a call. This check exists because
    # of a hook that blocked; the comments explaining that fix must not trip it.
    body="${hit#*:*:}"
    [[ "$body" =~ ^[[:space:]]*-- ]] && continue

    if grep -q 'XLINGS_NON_INTERACTIVE' "$file" && grep -q 'os.getenv' "$file"; then
        echo "  ok   $file  (reads stdin, but the answer can also come from the environment)"
        continue
    fi
    echo "::error file=$file::$hit"
    echo "       io.read() in a recipe hook blocks forever when nobody can answer."
    echo "       Accept the answer from an environment variable, and fall back to a"
    echo "       default (or a clear error) when XLINGS_NON_INTERACTIVE or CI is set."
    bad=$((bad + 1))
done

if [[ $bad -gt 0 ]]; then
    echo "xpkg blocking-input check: FAIL ($bad unguarded io.read across $scanned recipes)"
    exit 1
fi
# The count is part of the result: a check that matched nothing prints the same
# PASS as one that read every recipe, and this repo has shipped that confusion.
echo "xpkg blocking-input check: PASS (${#hits[@]} io.read site(s) across $scanned recipes, all guarded)"
exit 0
