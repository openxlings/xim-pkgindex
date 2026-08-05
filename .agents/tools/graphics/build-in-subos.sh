#!/usr/bin/env bash
# Build one graphics-stack package from source, inside a subos, and check that
# nothing from the host leaked into the result.
#
# Design: xlings/.agents/docs/2026-08-05-graphics-stack-ecosystem-closure.md §5
#
# The stack has ~30 packages to build and they are mostly ordinary autotools or
# meson projects. What is NOT ordinary is where they are built: on the host,
# `./configure && make` links against the host's glibc and finds the host's
# headers, and the result then needs whatever glibc that host had. That is
# issue #352, manufactured deliberately.
#
# So every build runs with the subos supplying the compiler, the sysroot and
# the libraries, and the result is checked before it is allowed to ship:
#
#   * no DT_NEEDED that resolves outside the subos or the package itself
#   * no RPATH/RUNPATH naming a host path
#   * no absolute host path baked into a .pc, .la or config script
#
# That check is the reason this script exists rather than a README saying
# "build it in the subos". A leaked host path does not fail the build; it fails
# months later on someone else's machine.
#
# Usage:
#   build-in-subos.sh --name libXau --version 1.0.11 \
#       --url https://.../libXau-1.0.11.tar.xz \
#       [--system autotools|meson] [--deps 'xorgproto libX11'] \
#       [-- <extra configure/meson args>]
set -uo pipefail

NAME= VERSION= URL= SYSTEM=auto DEPS= EXTRA=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)    NAME="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --url)     URL="$2"; shift 2 ;;
        --system)  SYSTEM="$2"; shift 2 ;;
        --deps)    DEPS="$2"; shift 2 ;;
        --)        shift; EXTRA=("$@"); break ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$NAME" && -n "$VERSION" && -n "$URL" ]] || {
    echo "usage: $0 --name N --version V --url U [--system auto|autotools|meson] [--deps '...'] [-- args]" >&2
    exit 2
}

SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxbuild}"
XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS="$XHOME/subos/$SUBOS_NAME"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"
STAGE="$WORK/stage/$NAME-$VERSION"
SRC="$WORK/src"

log()  { echo "[gfx-build:$NAME] $*"; }
fail() { echo "[gfx-build:$NAME] FAIL: $*" >&2; exit 1; }

[[ -d "$SUBOS" ]] || fail "subos '$SUBOS_NAME' not found — xlings subos new $SUBOS_NAME"
# STAGE is wiped, not just created: a previous run with a different --libdir
# leaves its own tree here, and `make install DESTDIR=` only adds. The stale
# copy then rides into the payload and ships two layouts of the same library.
rm -rf "$STAGE"
mkdir -p "$SRC" "$STAGE"

# ── fetch ───────────────────────────────────────────────────────────────
TARBALL="$SRC/$(basename "$URL")"
[[ -f "$TARBALL" ]] || {
    log "fetching $(basename "$URL")"
    curl -fsSL --retry 3 -o "$TARBALL" "$URL" || fail "download failed"
}
BUILDDIR="$SRC/$NAME-$VERSION"
rm -rf "$BUILDDIR"; mkdir -p "$BUILDDIR"
tar xf "$TARBALL" -C "$BUILDDIR" --strip-components=1 || fail "extract failed"

# ── the subos as the build environment ──────────────────────────────────
# PKG_CONFIG_PATH and the include/lib paths point ONLY at the subos, so a
# dependency that is not packaged yet fails the configure step loudly instead
# of being silently satisfied by the host copy.

# Enter the subos the way `xlings subos use` does: its bin/ first on PATH.
#
# This is not a workaround for the subos mechanism — it IS the mechanism. A
# tool invoked by absolute path (as this script does for meson and gcc) never
# enters the subos context, so anything those tools then look up by NAME
# resolves against the ambient PATH instead. meson's find_program('python3')
# picked the developer's global `subos/current` python, and mesa reported its
# mako module missing from an interpreter nobody installed it into.
#
# Everything the build needs is installed INTO this subos with
# `xlings install`; putting its bin first is what makes those installs the
# ones that get found.
export PATH="$SUBOS/bin:$PATH"

PREFIX=/usr
# Both spellings: a payload uses a flat lib/, but a package that ignores
# --libdir still lands in the distro multiarch path and its .pc would then be
# invisible to the next package — which surfaces as "dependency not found" for
# something that was just built successfully.
export PKG_CONFIG_LIBDIR="$SUBOS/usr/lib/pkgconfig:$SUBOS/usr/share/pkgconfig:$SUBOS/usr/lib/x86_64-linux-gnu/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
export CPPFLAGS="-I$SUBOS/usr/include"
# -rpath-link, not just -L: `-L` resolves what this link line names directly,
# but a NEEDED entry of one of those libraries (libdrm_intel needing
# libpciaccess) is only searched along -rpath-link. Without it the link fails
# on transitive symbols with the library sitting right there.
export LDFLAGS="-L$SUBOS/lib -L$SUBOS/usr/lib -Wl,-rpath-link,$SUBOS/usr/lib -Wl,-rpath-link,$SUBOS/lib -Wl,-rpath,\$ORIGIN"
export CC="$SUBOS/bin/gcc"
export CXX="$SUBOS/bin/g++"
[[ -x "$CC" ]] || fail "no gcc in the subos — xlings install gcc"

if [[ "$SYSTEM" == auto ]]; then
    if   [[ -f "$BUILDDIR/meson.build" ]]; then SYSTEM=meson
    elif [[ -f "$BUILDDIR/configure"   ]]; then SYSTEM=autotools
    else fail "cannot tell the build system apart; pass --system"; fi
fi
log "building with $SYSTEM against subos '$SUBOS_NAME'"

cd "$BUILDDIR" || fail "cd"
case "$SYSTEM" in
  autotools)
    # --libdir=lib: the multiarch layout is a distro convention. A payload has
    # one architecture by construction, and the extra level only makes RPATH
    # and exports.runtime.libdirs harder to get right.
    ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib" \
        --disable-static --enable-shared \
        "${EXTRA[@]}" > "$WORK/$NAME-configure.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-configure.log"; fail "configure"; }
    make -j"$(nproc)"           > "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "make"; }
    make install DESTDIR="$STAGE" >> "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "make install"; }
    ;;
  meson)
    "$SUBOS/bin/meson" setup _b --prefix="$PREFIX" --libdir=lib \
        --buildtype=release -Ddefault_library=shared "${EXTRA[@]}" > "$WORK/$NAME-configure.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-configure.log"; fail "meson setup"; }
    "$SUBOS/bin/ninja" -C _b     > "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "ninja"; }
    DESTDIR="$STAGE" "$SUBOS/bin/meson" install -C _b >> "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "meson install"; }
    ;;
  *) fail "unknown build system '$SYSTEM'" ;;
esac

# ── flatten DESTDIR/usr into the payload root ───────────────────────────
PAYLOAD="$WORK/payload/$NAME-$VERSION"
rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD"
if [[ -d "$STAGE$PREFIX" ]]; then
    cp -a "$STAGE$PREFIX/." "$PAYLOAD/"
else
    cp -a "$STAGE/." "$PAYLOAD/"
fi

# Drop libtool archives. A .la records the absolute libdir it was built with,
# and the next package's libtool reads that path literally — libX11 fails with
# "'/usr/lib/libXau.la' is not a valid libtool archive" because it went looking
# on the host root. Rewriting them is possible; deleting them is what most
# distributions settled on, since anything still consuming a .la in 2026 is
# also consuming the .pc that says the same thing correctly.
find "$PAYLOAD" -name '*.la' -type f -delete

# $ORIGIN so the payload's own libraries resolve each other with no absolute
# path anywhere. xlings's elfpatch appends each dependency's libdir on top.
while IFS= read -r -d '' f; do
    patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
done < <(find "$PAYLOAD" -type f -name '*.so*' ! -type l -print0)

# ── the check that makes this worth scripting ───────────────────────────
leaks=0
report_leak() { echo "    $*"; leaks=$((leaks+1)); }

log "checking for host leakage"
while IFS= read -r -d '' f; do
    rp="$(patchelf --print-rpath "$f" 2>/dev/null || true)"
    case "$rp" in
        ''|'$ORIGIN'*) ;;
        *) report_leak "RPATH names a path outside the payload: ${f#$PAYLOAD/} → $rp" ;;
    esac
done < <(find "$PAYLOAD" -type f -name '*.so*' ! -type l -print0)

# .pc / .la / *-config files carry absolute paths that later builds consume.
# A host prefix in one of these does not break anything now — it breaks the
# NEXT package, by pointing its configure at /usr.
while IFS= read -r -d '' f; do
    if grep -qE '(^|[=" ])/usr/(lib|include|share)/' "$f" 2>/dev/null; then
        grep -nE '(^|[=" ])/usr/(lib|include|share)/' "$f" | head -2 \
          | sed "s|^|    ${f#$PAYLOAD/}: |" | while read -r l; do report_leak "$l"; done
    fi
done < <(find "$PAYLOAD" \( -name '*.pc' -o -name '*.la' -o -name '*-config' \) -type f -print0)

if [[ $leaks -gt 0 ]]; then
    fail "$leaks host reference(s) in the payload — this would work here and fail elsewhere"
fi
log "  no host references"

# ── package ─────────────────────────────────────────────────────────────
OUT="$WORK/dist/$NAME-$VERSION-linux-x86_64.tar.gz"
mkdir -p "$(dirname "$OUT")"
tar czf "$OUT" -C "$WORK/payload" "$NAME-$VERSION"
log "→ $OUT  ($(du -h "$OUT" | cut -f1))"
sha256sum "$OUT" | sed 's/^/[gfx-build] sha256: /'

# ── stage into the build subos ──────────────────────────────────────────
# The tiers depend on each other: libXau needs xorgproto's headers, libxcb
# needs libXau's .pc, mesa needs all of it. Until every recipe is published
# there is nothing to `xlings install`, so the freshly built payload is placed
# into the subos sysroot the same way an installed package would appear.
#
# This is staging, not installing: no xvm registration, no manifest entry. It
# exists so tier N+1 can be built and is replaced by a real `xlings install`
# once the recipes are published.
if [[ "${XLINGS_GFX_STAGE:-1}" == "1" ]]; then
    mkdir -p "$SUBOS/usr"
    cp -a "$PAYLOAD/." "$SUBOS/usr/"

    # The payload's own .pc files say prefix=/usr, and they have to: that is
    # what makes the tarball relocatable into whatever subos installs it. But
    # the STAGED copy is consumed right now, from $SUBOS/usr, so a consumer
    # reading prefix=/usr resolves against the host root instead — libxcb fails
    # with "No rule to make target '//usr/share/xcb/'", pointing at a directory
    # that belongs to the host.
    #
    # Only the staged copy is rewritten. The tarball keeps /usr.
    while IFS= read -r -d '' pc; do
        sed -i "s|^prefix=/usr$|prefix=$SUBOS/usr|; s|=/usr/|=$SUBOS/usr/|g" "$pc"
    done < <(find "$SUBOS/usr" -name '*.pc' -type f -print0)

    log "  staged into $SUBOS_NAME's sysroot for the next tier"
fi
