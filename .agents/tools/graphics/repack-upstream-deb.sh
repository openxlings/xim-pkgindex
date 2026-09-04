#!/usr/bin/env bash
# Repack an upstream-published .deb into the xlings payload shape.
#
# WHY THIS EXISTS RATHER THAN A BUILD
#
# "Use upstream when upstream has it" beats rebuilding, and for libjpeg-turbo
# upstream really does have it: the project publishes an official, signed
# `libjpeg-turbo-official_<v>_amd64.deb` on its own release page carrying
# libjpeg.so.62 and libturbojpeg.so.0 -- the same sonames a rebuild would
# produce -- plus headers, .pc and cmake config. Rebuilding that from source
# would substitute our toolchain for theirs and gain nothing.
#
# What upstream does NOT do is ship it in a shape xlings can install: the
# payload lives under /opt/libjpeg-turbo with a lib64/, and this index's
# packages are `<name>-<version>-linux-x86_64/{bin,include,lib}` with a flat
# lib/. So this script moves the tree, not its contents.
#
# WHAT IT DROPS, AND WHY THAT IS NOT REPACKAGING BY ANOTHER NAME
#
#   *.a            every other library package in this index is shared-only
#   classes/*.jar  the JNA binding, which needs a JVM nobody here has
#   man/, doc/     not consumed inside a subos
#
# Nothing is added, nothing is recompiled, and no ELF is modified. `--verify`
# re-derives the sha256 of every shipped ELF from the .deb and compares, so
# the claim "these are upstream's bytes" is checked rather than asserted.
#
# Usage:
#   repack-upstream-deb.sh --name libjpeg-turbo --version 3.2.0 \
#       --url https://github.com/.../libjpeg-turbo-official_3.2.0_amd64.deb \
#       --strip-prefix opt/libjpeg-turbo
#
# Exit codes per .agents/tools/README.md: 0 proven, 1 broken, 3 could-not-run.
set -uo pipefail

NAME= VERSION= URL= STRIP_PREFIX=
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)         NAME="$2"; shift 2 ;;
        --version)      VERSION="$2"; shift 2 ;;
        --url)          URL="$2"; shift 2 ;;
        --strip-prefix) STRIP_PREFIX="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$NAME" && -n "$VERSION" && -n "$URL" && -n "$STRIP_PREFIX" ]] || {
    echo "usage: $0 --name N --version V --url U --strip-prefix opt/foo" >&2; exit 2; }

WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"
SRC="$WORK/src"; DIST="$WORK/dist"; PAYLOAD="$WORK/payload/$NAME-$VERSION"
mkdir -p "$SRC" "$DIST" "$(dirname "$PAYLOAD")"

log()  { echo "[repack:$NAME] $*"; }
fail() { echo "[repack:$NAME] FAIL: $*" >&2; exit 1; }
skip() { echo "[repack:$NAME] SKIP: $*" >&2; exit 3; }

command -v dpkg-deb >/dev/null || command -v ar >/dev/null || skip "neither dpkg-deb nor ar"

DEB="$SRC/$(basename "$URL")"
[[ -f "$DEB" ]] || { log "fetching $(basename "$URL")"; curl -fsSL -o "$DEB" "$URL" || fail "download"; }

EXTRACT="$SRC/$NAME-$VERSION-deb"
rm -rf "$EXTRACT"; mkdir -p "$EXTRACT"
if command -v dpkg-deb >/dev/null; then
    dpkg-deb -x "$DEB" "$EXTRACT" || fail "dpkg-deb -x"
else
    (cd "$EXTRACT" && ar p "$DEB" data.tar.xz | tar xJ) || fail "ar|tar"
fi

ROOT="$EXTRACT/$STRIP_PREFIX"
[[ -d "$ROOT" ]] || fail "--strip-prefix '$STRIP_PREFIX' is not in this .deb"

rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD"
for d in bin include; do
    [[ -d "$ROOT/$d" ]] && cp -a "$ROOT/$d" "$PAYLOAD/$d"
done
# lib64 -> lib, because every other payload in this index has a flat lib/ and
# sysroot.declare_libs / the elfpatch pass both look there.
mkdir -p "$PAYLOAD/lib"
for d in lib64 lib; do
    [[ -d "$ROOT/$d" ]] && cp -a "$ROOT/$d/." "$PAYLOAD/lib/"
done

find "$PAYLOAD" -name '*.a' -delete
rm -rf "$PAYLOAD/classes" "$PAYLOAD/man" "$PAYLOAD/share/man" "$PAYLOAD/share/doc"

# The .pc and cmake files point at the .deb's own prefix. Rewrite to /usr and
# let sysroot.relocate_pkgconfig do the rest at install time -- the same
# contract every built payload in this index ships under.
while IFS= read -r -d '' f; do
    sed -i "s|/$STRIP_PREFIX/lib64|\${prefix}/lib|g; s|/$STRIP_PREFIX|/usr|g" "$f"
done < <(find "$PAYLOAD" \( -name '*.pc' -o -name '*.cmake' \) -type f -print0)

# The soname symlinks the .deb leaves to its postinst/ldconfig. A payload is
# never ldconfig'd, so a consumer linking -ljpeg needs libjpeg.so here.
( cd "$PAYLOAD/lib"
  for real in *.so.*.*.*; do
      [[ -f "$real" ]] || continue
      soname="$(readelf -d "$real" 2>/dev/null | sed -n 's/.*soname: \[\(.*\)\].*/\1/p')"
      [[ -n "$soname" && ! -e "$soname" ]] && ln -sf "$real" "$soname"
      base="${soname%%.so.*}.so"
      [[ -n "$base" && ! -e "$base" ]] && ln -sf "${soname:-$real}" "$base"
  done )

# PROVE the ELFs are upstream's, byte for byte, rather than saying so.
log "verifying shipped ELFs against the .deb"
mismatch=0
while IFS= read -r -d '' f; do
    rel="${f#$PAYLOAD/lib/}"
    for cand in "$ROOT/lib64/$rel" "$ROOT/lib/$rel"; do
        [[ -f "$cand" ]] || continue
        a=$(sha256sum "$f"    | cut -d' ' -f1)
        b=$(sha256sum "$cand" | cut -d' ' -f1)
        [[ "$a" == "$b" ]] || { echo "    MISMATCH $rel"; mismatch=$((mismatch+1)); }
        break
    done
done < <(find "$PAYLOAD/lib" -maxdepth 1 -type f ! -type l -print0)
[[ $mismatch -eq 0 ]] || fail "$mismatch file(s) differ from the .deb"
log "  all shipped ELFs identical to upstream's"

# Report -- do not silently rewrite -- an RPATH that names the .deb's own
# layout. Rewriting it would edit the ELF and cost the byte-identity checked
# just above, which is the whole reason this path exists instead of a build.
# xlings' elfpatch replaces DT_RPATH at install time regardless, so the value
# here is inert; what is not acceptable is nobody knowing it is there.
while IFS= read -r -d '' f; do
    rp="$(patchelf --print-rpath "$f" 2>/dev/null || true)"
    case "$rp" in
        ''|'$ORIGIN'*) ;;
        *) log "  note: ${f#$PAYLOAD/} keeps upstream's RPATH [$rp] (inert; elfpatch replaces it on install)" ;;
    esac
done < <(find "$PAYLOAD" -name '*.so*' -type f ! -type l -print0)

OUT="$DIST/$NAME-$VERSION-linux-x86_64.tar.gz"
tar --sort=name --owner=0 --group=0 --numeric-owner \
    --mtime="@${SOURCE_DATE_EPOCH:-0}" --format=gnu \
    -cf - -C "$WORK/payload" "$NAME-$VERSION" | gzip -n -9 > "$OUT"
log "→ $OUT  ($(du -h "$OUT" | cut -f1))"
sha256sum "$OUT" | sed 's/^/[repack] sha256: /'

# Stage into the build subos so the next tier can configure against it.
if [[ "${XLINGS_GFX_STAGE:-1}" == "1" ]]; then
    SUBOS="$HOME/.xlings/subos/${XLINGS_GFX_SUBOS:-gtk4build}"
    if [[ -d "$SUBOS" ]]; then
        mkdir -p "$SUBOS/usr"
        cp -a "$PAYLOAD/." "$SUBOS/usr/"
        while IFS= read -r -d '' pc; do
            sed -i "s|^prefix=/usr$|prefix=$SUBOS/usr|; s|=/usr/|=$SUBOS/usr/|g" "$pc"
        done < <(find "$SUBOS/usr" -name '*.pc' -type f -print0)
        log "  staged into ${XLINGS_GFX_SUBOS:-gtk4build}'s sysroot"
    fi
fi
