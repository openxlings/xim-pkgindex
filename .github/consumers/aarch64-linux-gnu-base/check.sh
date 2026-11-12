#!/usr/bin/env bash
# The admission contract of a base package, by the engine that reads it
# (mcpp design 2026-11-12, section 5.6). The tree-only part of the contract is
# tests/lib/base_package.py; this is the part a build and a run decide:
#
#   a C program, a C++ program over the headers and one that imports std each
#   build for the identity, dynamically; the last one statically as well;
#   each dynamic artifact names the row's loader, carries no run-time path and
#   no path of the machine that built it;
#   each runs through the provider's runner, and its output and exit status
#   arrive.
#
# A payload revision that passes its digest and its install and fails any of
# these is not admitted: revision 2 of this package failed all but the first.
set -uo pipefail
: "${MCPP:?}" "${REGISTRY:?}"
fail() { echo "::error::aarch64-linux-gnu-base: $*"; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"
T=aarch64-linux-gnu
LOADER=/lib/ld-linux-aarch64.so.1
readelf="$(ls "$REGISTRY"/data/xpkgs/xim-x-llvm/*/bin/llvm-readelf 2>/dev/null | head -1)"
[ -x "$readelf" ] || fail "no llvm-readelf in the llvm payload the build installed"

artifact() { find "$1/target/$T" -path "*/bin/$2" -type f | head -1; }

dynamic() {   # <project dir> <program> <output line> <exit status>
    local exe out rc interp
    exe="$(artifact "$1" "$2")"
    [ -n "$exe" ] || fail "$2: no artifact for $T"
    "$readelf" -h "$exe" | grep -q "Machine:.*AArch64" || fail "$2: not an aarch64 ELF"
    interp="$("$readelf" -l "$exe" | sed -n 's/.*Requesting program interpreter: \(.*\)\]/\1/p')"
    echo "READING $2.interpreter: $interp"
    [ "$interp" = "$LOADER" ] || fail "$2: the interpreter is '$interp', the row's loader is $LOADER"
    if "$readelf" -d "$exe" | grep -qiE "RPATH|RUNPATH"; then fail "$2: a run-time path of the build machine"; fi
    if grep -aq "$REGISTRY" "$exe"; then fail "$2: a path of the build machine's store is in the artifact"; fi
    out="$(cd "$1" && "$MCPP" run 2>&1)"; rc=$?
    echo "READING $2.run: exit=$rc"
    [ "$rc" -eq "$4" ] || { echo "$out" | tail -20; fail "$2: mcpp run exited $rc, the program returns $4"; }
    echo "$out" | grep -q "^$3\$" || { echo "$out" | tail -20; fail "$2: the program's output did not arrive"; }
}

dynamic "$here" base-c "base-c" 42

for p in cxx std; do
    echo "::group::mcpp build ($p)"
    (cd "$here/probes/$p" && "$MCPP" build) || fail "base-$p: mcpp build failed"
    echo "::endgroup::"
done
dynamic "$here/probes/cxx" base-cxx "base-cxx" 43
dynamic "$here/probes/std" base-std "base-std 6" 44

# Statically: no interpreter, the same exit status.
printf '\n[target.%s]\nlinkage = "static"\n' "$T" >> "$here/probes/std/mcpp.toml"
(cd "$here/probes/std" && "$MCPP" build) > "$here/static.log" 2>&1 || { tail -20 "$here/static.log"; fail "the static import-std program did not build"; }
exe="$(find "$here/probes/std/target/$T" -path '*/bin/base-std' -type f -newer "$here/probes/std/mcpp.toml" | head -1)"
[ -n "$exe" ] || fail "no static artifact"
if "$readelf" -l "$exe" | grep -q "program interpreter"; then fail "a static program names an interpreter"; fi
out="$(cd "$here/probes/std" && "$MCPP" run 2>&1)"; rc=$?
echo "READING base-std.static.run: exit=$rc"
[ "$rc" -eq 44 ] || { echo "$out" | tail -20; fail "static: mcpp run exited $rc"; }
echo "aarch64-linux-gnu-base: every criterion held"
