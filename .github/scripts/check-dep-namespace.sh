#!/usr/bin/env bash
set -euo pipefail

# Runs the dep-namespace policy check. The check itself is
# check-dep-namespace.lua, which loads every recipe AS LUA and walks
# `package.xpm.<platform>[.<version>].deps` as a table -- read that file for
# what the rule is and why it is not a grep.
#
# This wrapper only finds an interpreter. Two things it deliberately does not
# do, both because they produce a WRONG ANSWER rather than an error:
#
#   * skip when no interpreter is present. A check that skips itself reports
#     the same green as a check that ran.
#
#   * accept any `lua` on PATH. The checker loads each recipe into a sandbox
#     env via `loadfile(f, "t", env)`, which is Lua 5.2+. On 5.1 / LuaJIT the
#     env argument is ignored, every recipe then runs against the real globals,
#     `import(...)` is nil, and all 160 recipes fail to load -- an index-wide
#     red that says nothing about the index. So the version is probed, and an
#     interpreter that cannot do the job is not used.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

CHECKER="$ROOT_DIR/.github/scripts/check-dep-namespace.lua"

find_lua() {
  for candidate in lua5.4 lua5.3 lua; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    if "$candidate" -e 'os.exit((tonumber(_VERSION:match("%d+%.%d+")) or 0) >= 5.2 and 0 or 1)' \
        >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if ! LUA_CMD="$(find_lua)"; then
  echo "::error::No Lua 5.2+ interpreter found (tried lua5.4, lua5.3, lua);" \
       "cannot enforce the dep namespace policy. Install one:" \
       "apt-get install -y lua5.4"
  exit 1
fi

# What an exemption's expiry is measured against (see EXEMPT in the .lua).
# In CI this must resolve; a checkout too shallow to see the base would turn
# "expired" into "not measured", and that is the silence the expiry exists to
# end. Locally it is optional -- the checker says when it did not look.
resolve_base_ref() {
  if [[ -n "${DEP_NS_BASE_REF:-}" ]]; then
    echo "$DEP_NS_BASE_REF"; return 0
  fi
  [[ "${GITHUB_ACTIONS:-}" == "true" ]] || return 0
  # --depth only on a clone that is ALREADY shallow (actions/checkout's
  # default). On a full clone it would truncate the history to that depth.
  local shallow=()
  [[ "$(git rev-parse --is-shallow-repository)" == "true" ]] && shallow=(--depth=2)
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    git fetch --no-tags --quiet "${shallow[@]}" origin \
      "+refs/heads/${GITHUB_BASE_REF}:refs/remotes/origin/${GITHUB_BASE_REF}" >&2
    echo "origin/${GITHUB_BASE_REF}"
  else
    # push: the base is the commit this one landed on.
    git fetch --no-tags --quiet "${shallow[@]}" origin "${GITHUB_SHA}" >&2
    echo "${GITHUB_SHA}~1"
  fi
}

BASE_REF="$(resolve_base_ref)"
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  if [[ -z "$BASE_REF" ]] || ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null; then
    echo "::error::cannot resolve the base ref '${BASE_REF}' for the dep-namespace" \
         "exemption expiry check; refusing to report a pass that did not look"
    exit 1
  fi
fi

DEP_NS_BASE_REF="$BASE_REF" exec "$LUA_CMD" "$CHECKER" --check "$ROOT_DIR"
