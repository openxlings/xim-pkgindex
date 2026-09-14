#!/usr/bin/env bash
# Builds the consumer fixtures under .github/consumers/ whose recipes this
# change touches, in one fresh mcpp home whose config.toml names this checkout
# as the `xim` index, then runs each fixture's check.sh.
#
# Environment: CHANGED_FILES (space-separated repository paths), EVENT (the
# GitHub event name; `workflow_dispatch` builds every fixture), MCPP_VERSION.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$ROOT/.github/consumers"
: "${MCPP_VERSION:?MCPP_VERSION names the released mcpp to build with}"
: "${RUNNER_TEMP:?}"

reading() { printf 'READING %s: %s\n' "$1" "$2"; }
fail() { echo "::error::$*"; exit 1; }

# ── Which fixtures ─────────────────────────────────────────────────────────
selected=()
for dir in "$FIXTURES"/*/; do
    name="$(basename "$dir")"
    [ -f "$dir/consumes" ] || continue
    pick=0
    if [ "${EVENT:-}" = "workflow_dispatch" ]; then
        pick=1
    else
        for changed in ${CHANGED_FILES:-}; do
            case "$changed" in .github/consumers/"$name"/*) pick=1 ;; esac
            while IFS= read -r path; do
                [ -n "$path" ] && [ "$changed" = "$path" ] && pick=1
            done < "$dir/consumes"
        done
    fi
    [ "$pick" -eq 1 ] && selected+=("$name")
done
reading fixtures "${selected[*]:-none}"
if [ "${#selected[@]}" -eq 0 ]; then
    echo "No consumer fixture consumes a file this change touches."
    exit 0
fi

# ── The released mcpp, and a fresh home that names this checkout ───────────
cd "$RUNNER_TEMP" || exit 1
asset="mcpp-$MCPP_VERSION-linux-x86_64"
curl -fsSL --retry 3 --retry-all-errors -o mcpp.tar.gz \
    "https://github.com/mcpp-community/mcpp/releases/download/v$MCPP_VERSION/$asset.tar.gz" \
    || fail "could not download mcpp $MCPP_VERSION"
tar -xzf mcpp.tar.gz || fail "could not unpack mcpp $MCPP_VERSION"
MCPP="$RUNNER_TEMP/$asset/bin/mcpp"
export MCPP_VENDORED_XLINGS="$RUNNER_TEMP/$asset/registry/bin/xlings"
[ -x "$MCPP" ] && [ -x "$MCPP_VENDORED_XLINGS" ] || fail "the mcpp tarball lacks bin/mcpp or its xlings"
reading mcpp "$("$MCPP" --version | head -1)"

export MCPP_HOME="$RUNNER_TEMP/consumer-home"
rm -rf "$MCPP_HOME"; mkdir -p "$MCPP_HOME"
printf '[index.repos.xim]\nurl = "%s"\n' "$ROOT" > "$MCPP_HOME/config.toml"
# GLOBAL on a hosted runner; MCPP_MIRROR=CN reproduces the job from a network
# where the GitHub hosts are slow.
"$MCPP" self config --mirror "${MCPP_MIRROR:-GLOBAL}" > /dev/null 2>&1 || fail "mcpp self config failed"
export MCPP REGISTRY="$MCPP_HOME/registry"

# ── Each fixture ───────────────────────────────────────────────────────────
for name in "${selected[@]}"; do
    work="$RUNNER_TEMP/consumers/$name"
    rm -rf "$work"; mkdir -p "$(dirname "$work")"
    cp -R "$FIXTURES/$name" "$work"
    echo "::group::mcpp build ($name)"
    (cd "$work" && "$MCPP" build) > "$work.build.log" 2>&1; rc=$?
    cat "$work.build.log"
    echo "::endgroup::"
    reading "$name.build" "exit=$rc"
    [ "$rc" -eq 0 ] || fail "$name: mcpp build exited $rc"
    bash "$work/check.sh" || fail "$name: a criterion did not hold"
done

# ── The index the builds resolved against was this checkout ────────────────
index_dir="$REGISTRY/data/xim-pkgindex"
[ -L "$index_dir" ] || fail "$index_dir is not a symlink to the checkout"
target="$(cd "$index_dir" && pwd -P)"
reading index-dir "$index_dir -> $target"
[ "$target" = "$(cd "$ROOT" && pwd -P)" ] || fail "the registry's index is $target, not this checkout"
named=$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(" ".join(r.get("url", "") for r in d.get("index_repos", []) if r.get("name") == "xim"))
' "$REGISTRY/.xlings.json")
reading index-repos "xim -> $named"
[ "$named" = "$ROOT" ] || fail "the registry's .xlings.json names '$named' for xim, not this checkout"

echo "consumer fixtures through the index override: every criterion held"
