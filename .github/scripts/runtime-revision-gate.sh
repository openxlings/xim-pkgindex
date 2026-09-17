#!/usr/bin/env bash
# The two-leg build that reproduces mcpp-community/mcpp#660: a runtime
# revision move (glibc's `latest` here) that a fresh install never sees, but
# a consumer's CI-cache-shaped install does.
#
# WHY A FRESH INSTALL CANNOT SEE THIS
#
# A fresh `mcpp build` resolves the CURRENT index once, downloads exactly the
# payload it names, and binds the toolchain to it in the same run. There is
# no earlier revision on disk for the new one to disagree with, so nothing in
# that sequence can exercise a stale-binding defect. The incident needed a
# machine that already had a toolchain patched against the OLD runtime
# revision, and then met the NEW revision with its version-tracking state
# gone but the old payload directory still present -- exactly the shape a CI
# cache produces when it restores `~/.mcpp/registry/data/xpkgs` (payloads;
# large, worth caching) without the rest of `~/.mcpp/registry` (xlings' own
# version database and subos views; small, and the part a cache action was
# never told to keep).
#
# THE TWO LEGS
#
#   Leg A ("previous revision"): a fresh MCPP_HOME resolves the BASE index
#   tree and builds+runs a hello-world project, so the default toolchain gets
#   installed and patched against whatever glibc revision the base tree
#   declares as latest.
#
#   Cache simulation: everything under $MCPP_HOME/registry is deleted except
#   registry/data/xpkgs -- the payload store a CI cache action would restore.
#   xlings' version database (.xlings.json), the subos view that declares the
#   active runtime, and the composed runtime directory are all gone; the
#   installed toolchain and glibc payload directories are not.
#
#   Leg B ("new revision"): the same project, same MCPP_HOME, now resolving
#   the HEAD index tree. mcpp sees no installed-state record, so it
#   reinitializes as if this were a fresh home, but the gcc payload it would
#   normally download is already on disk under the un-touched xpkgs store, so
#   mcpp treats it as already installed and proceeds straight to a
#   "post-install fixup" that binds it to the runtime the NEW index declares.
#   If that binding assumes the corresponding glibc payload directory already
#   exists rather than fetching it, the build fails with exactly the error
#   quoted in mcpp#660. The job fails if this leg's build or run fails --
#   that failure is this gate's entire purpose, not a flake to retry.
#
# Environment: MCPP (path to the released mcpp binary), MCPP_VENDORED_XLINGS
# (the xlings binary that ships beside it), MCPP_HOME (a fresh directory this
# script owns), BASE_TREE / HEAD_TREE (two checkouts of this index, at the
# pull request's base and head commits), RUNNER_TEMP.
set -uo pipefail

: "${MCPP:?}"
: "${MCPP_VENDORED_XLINGS:?}"
: "${MCPP_HOME:?}"
: "${BASE_TREE:?}"
: "${HEAD_TREE:?}"
: "${RUNNER_TEMP:?}"

export MCPP_HOME MCPP_VENDORED_XLINGS

reading() { printf 'READING %s: %s\n' "$1" "$2"; }
fail() { echo "::error::$*"; exit 1; }

run_mcpp() {
    env -u XLINGS_ACTIVE_SUBOS -u XLINGS_PROJECT_DIR "$MCPP" "$@"
}

# `[index.repos.xim]` is the one table mcpp reconciles into an existing
# home's `.xlings.json` (mcpp-community/mcpp#634) and seeds fresh into a new
# one -- the mechanism .github/scripts/consumer-through-index-override.sh
# already uses to build the fixtures under .github/consumers/ against this
# checkout instead of the published index. config.toml lives directly under
# $MCPP_HOME, a sibling of registry/, so rewriting it between legs survives
# the cache simulation below untouched -- exactly as a consumer's own setup
# step (which does not cache its own config file either) would regenerate it
# fresh every run.
set_index() {
    printf '[index.repos.xim]\nurl = "%s"\n' "$1" > "$MCPP_HOME/config.toml"
}

print_state() {
    local label="$1"
    local store="(absent)"
    if [ -d "$MCPP_HOME/registry/data/xpkgs/xim-x-glibc" ]; then
        store="$(ls "$MCPP_HOME/registry/data/xpkgs/xim-x-glibc" 2>/dev/null | tr '\n' ' ')"
        [ -n "$store" ] || store="(empty)"
    fi
    reading "$label.glibc-store" "$store"

    local declared="(no subos/default/.xlings.json)"
    local xjson="$MCPP_HOME/registry/subos/default/.xlings.json"
    if [ -f "$xjson" ]; then
        declared="$(python3 -c '
import json, sys
try:
    doc = json.load(open(sys.argv[1]))
except Exception as exc:
    print(f"(unreadable: {exc})"); sys.exit()
print(doc.get("subos_info", {}).get("runtime", "(no runtime key)"))
' "$xjson")"
    fi
    reading "$label.declared-runtime" "$declared"
}

# ── Leg A: previous revision, fresh home ────────────────────────────────────
rm -rf "$MCPP_HOME"; mkdir -p "$MCPP_HOME"
set_index "$BASE_TREE"
run_mcpp self config --mirror "${MCPP_MIRROR:-GLOBAL}" > "$RUNNER_TEMP/leg-a-config.log" 2>&1 \
    || fail "leg A: mcpp self config failed ($(cat "$RUNNER_TEMP/leg-a-config.log"))"

PROJECT_ROOT="$RUNNER_TEMP/gate-project"
rm -rf "$PROJECT_ROOT"; mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT" || fail "could not enter $PROJECT_ROOT"

echo "::group::leg A -- mcpp new hello (base tree: $BASE_TREE)"
run_mcpp new hello 2>&1 | tee "$RUNNER_TEMP/leg-a-new.log"
echo "::endgroup::"
[ -d "$PROJECT_ROOT/hello" ] || fail "leg A: mcpp new hello did not create a project"
cd "$PROJECT_ROOT/hello" || fail "could not enter the hello project"

echo "::group::leg A -- mcpp build"
run_mcpp build > "$RUNNER_TEMP/leg-a-build.log" 2>&1; rc=$?
cat "$RUNNER_TEMP/leg-a-build.log"
echo "::endgroup::"
reading "leg-a.build" "exit=$rc"
[ "$rc" -eq 0 ] || fail "leg A: mcpp build exited $rc -- the previous revision must build cleanly for this gate to mean anything"

echo "::group::leg A -- mcpp run"
run_mcpp run > "$RUNNER_TEMP/leg-a-run.log" 2>&1; rc=$?
cat "$RUNNER_TEMP/leg-a-run.log"
echo "::endgroup::"
reading "leg-a.run" "exit=$rc"
[ "$rc" -eq 0 ] || fail "leg A: mcpp run exited $rc -- the previous revision must run cleanly for this gate to mean anything"

print_state "after-leg-a"

# ── Model a CI cache: only the xpkgs payload store survives ────────────────
# Everything else xlings keeps under registry/ records INSTALLED STATE (the
# version database, the subos view that binds a runtime, the composed
# runtime directory) rather than payload bytes, and is exactly what a cache
# action scoped to `data/xpkgs` -- the large, slow-to-redownload part --
# would not restore.
reading "cache-sim" "keeping only $MCPP_HOME/registry/data/xpkgs"
find "$MCPP_HOME/registry" -mindepth 1 -maxdepth 1 ! -name data -exec rm -rf {} +
find "$MCPP_HOME/registry/data" -mindepth 1 -maxdepth 1 ! -name xpkgs -exec rm -rf {} +
rm -rf "$PROJECT_ROOT/hello/target"

print_state "after-cache-sim"

# ── Leg B: new revision, cache-shaped home, same project ───────────────────
set_index "$HEAD_TREE"
run_mcpp self config --mirror "${MCPP_MIRROR:-GLOBAL}" > "$RUNNER_TEMP/leg-b-config.log" 2>&1 \
    || fail "leg B: mcpp self config failed ($(cat "$RUNNER_TEMP/leg-b-config.log"))"

cd "$PROJECT_ROOT/hello" || fail "could not re-enter the hello project"

echo "::group::leg B -- mcpp build (head tree: $HEAD_TREE)"
run_mcpp build > "$RUNNER_TEMP/leg-b-build.log" 2>&1; rc=$?
cat "$RUNNER_TEMP/leg-b-build.log"
echo "::endgroup::"
reading "leg-b.build" "exit=$rc"
print_state "after-leg-b-build"
[ "$rc" -eq 0 ] || fail "leg B: mcpp build exited $rc -- the new revision failed against a CI-cache-shaped home (mcpp-community/mcpp#660)"

echo "::group::leg B -- mcpp run"
run_mcpp run > "$RUNNER_TEMP/leg-b-run.log" 2>&1; rc=$?
cat "$RUNNER_TEMP/leg-b-run.log"
echo "::endgroup::"
reading "leg-b.run" "exit=$rc"
[ "$rc" -eq 0 ] || fail "leg B: mcpp run exited $rc"

print_state "after-leg-b"

echo "runtime revision gate: both legs held"
