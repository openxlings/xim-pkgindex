#!/usr/bin/env bash
# Build `wayland-protocols` — the protocol XML mesa's Wayland platform is generated from.
#
# Design: xlings/.agents/docs/2026-08-08-mesa-rebuild-iris-d3d12-wayland-design.md §4
#
# WHY THIS EXISTS — AND IT IS NOT "THE PACKAGE WAS MISSING"
#
# mesa asks for it unconditionally once the wayland platform is on:
#
#   meson.build:2061  dependency('wayland-protocols', version : '>= 1.38')
#
# The first version of this comment said the package was not in the index. That
# was wrong: `pkgs/w/wayland-protocols.lua` has existed at 1.38 since
# 2026-08-05, published to xlings-res in both regions. The real finding is worse
# and more interesting.
#
# Measured 2026-08-08:
#
#   * the SHIPPED mesa 25.0.7.1 -- whose Wayland cell the O4 probe certifies as
#     7/7 objects from XLINGS_HOME at RUN time -- was built against the HOST's
#     /usr/share/pkgconfig/wayland-protocols.pc, version 1.45
#   * `ls /home/speak/.xlings/data/xpkgs/*wayland-protocols*` -> nothing. The
#     package was never installed in the home mesa was built in
#   * the T5 line in tiers.sh named neither `--deps wayland-protocols` nor an
#     extra pkgconfig path, and this recipe's config() stages nothing into the
#     subos sysroot (correctly -- it is build-only), so pkg-config could not
#     have seen it even if it had been installed
#
# So a correct, published package sat unused while the host answered the same
# question, and every runtime check still passed. Self-containment at run time
# and at build time are different properties and only the first had a guard.
#
# This script exists to produce 1.45 -- matching what the host offered, so the
# rebuild changes the drivers and not the protocol vintage as well -- and the
# WIRING is the actual fix: tiers.sh now passes the path explicitly.
#
# Unlike meson (openxlings/xim-pkgindex#562), this could not be handled by
# vendoring it into the build: wayland-scanner turns these XML files into C that
# is COMPILED INTO libEGL_mesa and libgbm. It contributes to the payload, so it
# has to be a named, versioned package -- and it already was.
#
# WHY NOT meson, again
#
# Upstream is a meson project whose entire Linux install is:
#
#   install_data(...)          the XML tree, under share/wayland-protocols/
#   pkg.generate(...)          one .pc file carrying pkgdatadir
#
# No compiler runs. There is no object code in this package at all -- `file` on
# every payload member says "XML document" or "ASCII text". Driving that with a
# build system would add a dependency to produce zero binaries.
#
# 1.45 rather than the 1.38 already in the index: it is the version the currently
# shipped mesa was actually built against (from the host), so the rebuild changes
# one thing (the drivers) and not two (the drivers and the protocol vintage). The
# recipe keeps BOTH -- protocol XML is additive, and a published payload cannot be
# withdrawn.
#
# Exit codes follow .agents/tools/README.md:
#   0 built and packaged · 1 the build broke · 3 it never started
set -uo pipefail

VERSION="${1:-1.45}"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"

log()  { echo "[wayland-protocols] $*"; }
fail() { echo "[wayland-protocols] FAIL: $*" >&2; exit 1; }
skip() { echo "[wayland-protocols] SKIP: $*" >&2; exit 3; }

command -v curl >/dev/null || skip "no curl"
mkdir -p "$WORK/src" "$WORK/dist"

SRC="$WORK/src/wayland-protocols-$VERSION"
TARBALL="$WORK/src/wayland-protocols-$VERSION.tar.xz"
if [[ ! -d "$SRC" ]]; then
    [[ -f "$TARBALL" ]] || {
        log "fetching wayland-protocols $VERSION"
        curl -fsSL --retry 3 -o "$TARBALL" \
          "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/$VERSION/downloads/wayland-protocols-$VERSION.tar.xz" \
          || fail "download failed"
    }
    tar -C "$WORK/src" -xf "$TARBALL" || fail "extract failed"
fi
[[ -d "$SRC/stable" ]] || fail "source tree at $SRC has no stable/ protocol directory"

PREFIX="$WORK/dist/wayland-protocols-$VERSION"
rm -rf "$PREFIX"; mkdir -p "$PREFIX/share/wayland-protocols" "$PREFIX/share/pkgconfig"

# The XML tree, exactly the four directories upstream installs.
#
# `staging` and `unstable` are not optional extras: mesa binds
# `linux-dmabuf-v1` from stable, `fifo-v1`/`commit-timing-v1` from staging, and
# older compositors still only offer the unstable spellings. Shipping a subset
# makes mesa configure fine and then miss an interface at run time, which
# surfaces as a compositor-specific rendering fault rather than a missing file.
count=0
for d in stable staging unstable; do
    [[ -d "$SRC/$d" ]] || fail "upstream tree is missing $d/"
    cp -r "$SRC/$d" "$PREFIX/share/wayland-protocols/$d" || fail "copying $d/"
    n=$(find "$PREFIX/share/wayland-protocols/$d" -name '*.xml' | wc -l)
    log "$d: $n protocol file(s)"
    count=$((count + n))
done
[[ -f "$SRC/wayland-protocols.pc.in" || -f "$SRC/meson.build" ]] || fail "not a wayland-protocols source tree"
cp "$SRC/COPYING" "$PREFIX/COPYING" 2>/dev/null || true

# Relocatable via ${pcfiledir}, same reasoning as directx-headers: this .pc is
# ours to write, so it never gets an absolute path to rewrite later.
#
# `pkgdatadir` is the only key consumers read -- mesa does
# `dep_wl_protocols.get_variable(pkgconfig : 'pkgdatadir')` and feeds it to
# wayland-scanner. A .pc whose pkgdatadir is wrong yields "No such file or
# directory" naming an XML path, three layers from this file.
cat > "$PREFIX/share/pkgconfig/wayland-protocols.pc" <<'PC'
prefix=${pcfiledir}/../..
datarootdir=${prefix}/share
pkgdatadir=${datarootdir}/wayland-protocols

Name: Wayland Protocols
Description: Wayland protocol files
Version: @VERSION@
PC
sed -i "s/@VERSION@/$VERSION/" "$PREFIX/share/pkgconfig/wayland-protocols.pc"

# Assertions, each naming what mesa would do without it.
[[ $count -gt 0 ]] || fail "no XML files were installed"
for f in share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
         share/wayland-protocols/stable/linux-dmabuf/linux-dmabuf-v1.xml \
         share/pkgconfig/wayland-protocols.pc; do
    [[ -f "$PREFIX/$f" ]] || fail "payload is missing $f"
done

# No object code, asserted rather than assumed. If this ever ships an ELF the
# recipe's dep list and RPATH story would both be wrong, and it would be caught
# here instead of by the closure guard in CI.
elves=$(find "$PREFIX" -type f -exec sh -c 'head -c4 "$1" | od -An -tx1 | grep -q "7f 45 4c 46" && echo "$1"' _ {} \; 2>/dev/null)
[[ -z "$elves" ]] || { echo "$elves" >&2; fail "payload contains ELF objects; this package is meant to be data-only"; }

if command -v pkg-config >/dev/null 2>&1; then
    v=$(PKG_CONFIG_PATH="$PREFIX/share/pkgconfig" pkg-config --modversion wayland-protocols 2>/dev/null || true)
    [[ "$v" == "$VERSION" ]] || fail "pkg-config --modversion gave '$v', expected $VERSION (mesa meson.build:2061)"
    PKG_CONFIG_PATH="$PREFIX/share/pkgconfig" pkg-config --atleast-version=1.38 wayland-protocols \
        || fail "does not satisfy mesa's version : '>= 1.38'"
    pkgdata=$(PKG_CONFIG_PATH="$PREFIX/share/pkgconfig" pkg-config --variable=pkgdatadir wayland-protocols)
    [[ -d "$pkgdata" ]] || fail "pkgdatadir '$pkgdata' does not exist -- wayland-scanner would fail on an XML path"
    [[ -f "$pkgdata/stable/xdg-shell/xdg-shell.xml" ]] \
        || fail "pkgdatadir '$pkgdata' has no stable/xdg-shell/xdg-shell.xml"
    log "pkg-config: $VERSION, pkgdatadir resolves and contains the stable tree"
fi

TAR="$WORK/dist/wayland-protocols-$VERSION-linux-x86_64.tar.gz"
rm -f "$TAR"
tar -C "$WORK/dist" -czf "$TAR" "wayland-protocols-$VERSION" || fail "packaging"
log "packaged $TAR  ($count XML files)"
log "sha256 $(sha256sum "$TAR" | awk '{print $1}')"
log "size   $(du -h "$TAR" | awk '{print $1}')"
