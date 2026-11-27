#!/usr/bin/env bash
set -euo pipefail

# The architecture checks K1 and K3 on the recipes a change adds or modifies
# (tools/xpkg_ci.py arch-check; the reasons are in tools/xpkg_arch.py):
#
#   K1  a Linux entry with an artifact names the architectures it is for
#       (`sha256 = { x86_64 = "<h>" }`; the same hash under each architecture
#       when it has no machine code; or an artifact per architecture). A
#       Linux host is x86_64 or aarch64, and one URL with one string digest
#       says nothing about which: an aarch64 client installed x86_64 bytes.
#   K3  `package.archs` is the union of what the entries list; locally,
#       `python3 tools/xpkg_ci.py arch-check --fix` rewrites it.
#
# The base is the one the revision check compares against (REVISION_BASE_REF,
# else the pull request's base or the commit a push landed on, else
# origin/main), resolved the same way.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

resolve_base_ref() {
  if [[ -n "${REVISION_BASE_REF:-}" ]]; then
    echo "$REVISION_BASE_REF"; return 0
  fi
  if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
    echo "origin/main"; return 0
  fi
  local shallow=()
  [[ "$(git rev-parse --is-shallow-repository)" == "true" ]] && shallow=(--depth=2)
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    git fetch --no-tags --quiet "${shallow[@]}" origin \
      "+refs/heads/${GITHUB_BASE_REF}:refs/remotes/origin/${GITHUB_BASE_REF}" >&2
    echo "origin/${GITHUB_BASE_REF}"
  else
    git fetch --no-tags --quiet "${shallow[@]}" origin "${GITHUB_SHA}" >&2
    echo "${GITHUB_SHA}~1"
  fi
}

BASE_REF="$(resolve_base_ref)"
if [[ -z "$BASE_REF" ]] || ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null; then
  echo "::error::cannot resolve the base ref '${BASE_REF}' for the architecture check;" \
       "refusing to report a pass that compared nothing (set REVISION_BASE_REF)"
  exit 1
fi

exec python3 tools/xpkg_ci.py --workspace "$ROOT_DIR" arch-check --base "$BASE_REF"
