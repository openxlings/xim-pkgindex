#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

# Files that are allowed to set LD_LIBRARY_PATH directly (documented exceptions).
# musl-gcc.lua: musl-ldd and musl-loader are alias wrappers invoking the musl
# dynamic linker, where RPATH cannot apply.
LD_ALLOWLIST=(
  "pkgs/m/musl-gcc.lua"
)

is_ld_allowlisted() {
  local file="$1"
  for item in "${LD_ALLOWLIST[@]}"; do
    if [[ "$file" == "$item" ]]; then
      return 0
    fi
  done
  return 1
}

# THE POLICY IS ABOUT CODE, SO THE SEARCH MUST NOT READ COMMENTS.
#
# This grepped the raw .lua text, so a recipe that DOCUMENTS a consumer's
# invocation failed the check for describing it. Measured: android-system-
# image.lua records the qemu-user runner line
#
#   LD_LIBRARY_PATH=<xim:android-ndk installdir>/.../aarch64-linux-android \
#     qemu-aarch64 -L <extracted-root> <artifact>
#
# in its header -- an instruction to a CONSUMER about a guest loader, and not
# an assignment this package makes. The check refused it, and the two ways out
# without touching the check were both worse: allowlist the file (which then
# exempts real assignments in it), or reword the documentation to avoid a
# literal string (which makes the record less useful to keep a text search
# happy).
#
# Comments are blanked LINE BY LINE so reported line numbers still point at the
# source. `--[[ ]]` blocks are handled as well as `--` tails; a `--` inside a
# string literal is left alone, which errs toward reporting rather than
# hiding.
strip_lua_comments() {
  awk '
    { line = $0 }
    inblock {
      i = index(line, "]]")
      if (i == 0) { print ""; next }
      line = substr(line, i + 2); inblock = 0
    }
    {
      b = index(line, "--[[")
      d = index(line, "--")
      if (b > 0 && (d == 0 || b <= d)) {
        pre = substr(line, 1, b - 1)
        rest = substr(line, b + 4)
        j = index(rest, "]]")
        if (j == 0) { inblock = 1; print pre; next }
        print pre substr(rest, j + 2); next
      }
      if (d > 0) { print substr(line, 1, d - 1); next }
      print line
    }
  ' "$1"
}

search() {
  local pattern="$1" f matches
  while IFS= read -r f; do
    matches="$(strip_lua_comments "$f" | grep -n -E "$pattern" || true)"
    [[ -z "$matches" ]] && continue
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      echo "${f}:${m}"
    done <<< "$matches"
  done < <(find pkgs -name "*.lua" -type f | sort)
}

failed=0

# --- Check 1: Reject deprecated XLINGS_PROGRAM_LIBPATH / XLINGS_EXTRA_LIBPATH ---
deprecated_matches="$(search "XLINGS_(PROGRAM|EXTRA)_LIBPATH")"
if [[ -n "$deprecated_matches" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    file="${line%%:*}"
    echo "::error file=${file}::Deprecated field found. XLINGS_PROGRAM_LIBPATH and XLINGS_EXTRA_LIBPATH have been removed. Library paths are now handled by elfpatch RPATH."
    failed=1
  done <<< "$deprecated_matches"
fi

# --- Check 2: LD_LIBRARY_PATH only in documented exceptions ---
ld_matches="$(search "LD_LIBRARY_PATH\s*=")"
if [[ -n "$ld_matches" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    file="${line%%:*}"

    if is_ld_allowlisted "$file"; then
      continue
    fi

    echo "::error file=${file}::Direct LD_LIBRARY_PATH assignment is disallowed in xpkg definitions. Library paths should use elfpatch RPATH instead."
    failed=1
  done <<< "$ld_matches"
fi

if [[ "$failed" -ne 0 ]]; then
  echo "xpkg libpath policy check: FAIL"
  exit 1
fi

echo "xpkg libpath policy check: PASS"
