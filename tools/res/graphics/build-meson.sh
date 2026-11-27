#!/usr/bin/env bash
# Repack `meson` as an xlings payload — closes openxlings/xim-pkgindex#562.
#
# WHY THIS EXISTS
#
# There was no meson package, and `build-in-subos.sh` called `$SUBOS/bin/meson`
# unconditionally — a path that exists in no home. So every meson build in this
# tree, mesa included, was driven by whatever meson the developer's host had
# (`pip --user`, usually). The G2 input audit never caught it because it inspects
# what the driver FOUND, never the driver itself.
#
# NO COMPILER RUNS
#
# meson is pure Python. This script downloads upstream's release tarball and
# repacks it under the naming publish.sh expects; there is nothing to build, and
# the payload is byte-identical content to upstream's.
#
# `-linux-x86_64` in the asset name is a convention of this index, not a claim:
# the content is architecture-independent, exactly like wayland-protocols. If a
# second arch is ever published it should get this same tarball.
#
# THE LAUNCHER IS NOT HERE
#
# `bin/meson` cannot be shipped: it has to name an absolute path inside the
# install directory, which is only known at install time. pkgs/m/meson.lua either
# registers an `alias` shim (xvm runs `python3 <payload>/meson.py`) or writes a
# launcher — see that recipe for which, and why.
#
# Exit codes follow .agents/tools/README.md:
#   0 packaged · 1 it broke · 3 it never started
set -uo pipefail

VERSION="${1:-1.8.2}"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"

log()  { echo "[meson] $*"; }
fail() { echo "[meson] FAIL: $*" >&2; exit 1; }
skip() { echo "[meson] SKIP: $*" >&2; exit 3; }

command -v curl >/dev/null || skip "no curl"
mkdir -p "$WORK/src" "$WORK/dist"

SRC="$WORK/src/meson-$VERSION"
TB="$WORK/src/meson-$VERSION.tar.gz"
if [[ ! -d "$SRC" ]]; then
    [[ -f "$TB" ]] || {
        log "fetching meson $VERSION"
        curl -fsSL --retry 3 -o "$TB" \
          "https://github.com/mesonbuild/meson/releases/download/$VERSION/meson-$VERSION.tar.gz" \
          || fail "download failed"
    }
    tar -C "$WORK/src" -xzf "$TB" || fail "extract failed"
fi
[[ -f "$SRC/meson.py" ]] || fail "$SRC has no meson.py -- wrong tarball layout"

PREFIX="$WORK/dist/meson-$VERSION"
rm -rf "$PREFIX"; mkdir -p "$PREFIX"

# meson.py plus the package it imports. Everything else in the tarball is
# packaging metadata, tests and docs, and a build driver has no use for them.
cp "$SRC/meson.py" "$PREFIX/meson.py"        || fail "copying meson.py"
cp -r "$SRC/mesonbuild" "$PREFIX/mesonbuild" || fail "copying mesonbuild/"
cp "$SRC/COPYING" "$PREFIX/COPYING" 2>/dev/null || true

# Assertions naming what each file is for.
for f in meson.py mesonbuild/mesonmain.py mesonbuild/__init__.py; do
    [[ -f "$PREFIX/$f" ]] || fail "payload is missing $f"
done

# No object code. A pure-Python package that grows an ELF has become something
# else, and the recipe's (empty) dep list would silently stop being true.
elves=$(find "$PREFIX" -type f -exec sh -c 'head -c4 "$1" | od -An -tx1 | grep -q "7f 45 4c 46" && echo "$1"' _ {} \; 2>/dev/null)
[[ -z "$elves" ]] || { echo "$elves" >&2; fail "payload contains ELF objects"; }

# Prove it runs, and that it reports the version we think we packaged.
#
# Any python3 will do for this check -- it is asking whether the payload is
# complete, not which interpreter the shim will use.
if command -v python3 >/dev/null 2>&1; then
    got=$(cd "$PREFIX" && python3 meson.py --version 2>&1 | tail -1)
    [[ "$got" == "$VERSION" ]] || fail "payload reports version '$got', expected $VERSION"
    log "acceptance: meson.py --version -> $got"
else
    log "note: no python3 here, so the run check was skipped (the recipe asserts the files)"
fi

TAR="$WORK/dist/meson-$VERSION-linux-x86_64.tar.gz"
rm -f "$TAR"
tar -C "$WORK/dist" -czf "$TAR" "meson-$VERSION" || fail "packaging"
log "packaged $TAR"
log "sha256 $(sha256sum "$TAR" | awk '{print $1}')"
log "size   $(du -h "$TAR" | awk '{print $1}')"
