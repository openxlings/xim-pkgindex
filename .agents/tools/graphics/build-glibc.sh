#!/usr/bin/env bash
# Build glibc from source into an xlings payload.
#
# Separate from build-in-subos.sh because glibc is not an ordinary package:
#
#   * it must be configured out-of-tree, and refuses to run in the source dir
#   * `--prefix` is not only where files go — it is compiled into ld.so as the
#     DEFAULT LIBRARY SEARCH PATH, consulted whenever an object asks for a
#     library with no RUNPATH of its own. The published 2.39 carries
#     `/home/xlings/.xlings_data/xim/xpkgs/fromsource-x-glibc/2.39/lib`, the
#     path on the machine that built it, and that is why a freshly linked tool
#     whose dependency's dependency has no RUNPATH dies on `libm.so.6: cannot
#     open shared object file` while `objdump -p` shows a path containing it.
#     There is no prefix that is right on every machine — xlings rewrites
#     INTERP and RPATH at install time, which is what actually resolves this.
#     Since AD-11 the value is an explicitly reserved placeholder rather than
#     whatever the build host happened to be; see the PREFIX assignment below.
#   * it is the one package whose payload cannot be patched by elfpatch: it IS
#     the loader. Its own layout has to be right at build time.
#
# Usage:  build-glibc.sh <version>            (e.g. build-glibc.sh 2.44)
set -uo pipefail

VERSION="${1:?usage: build-glibc.sh <version>}"
NAME=glibc
SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxbuild}"
XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS="$XHOME/subos/$SUBOS_NAME"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"
SRC="$WORK/src"
STAGE="$WORK/stage/$NAME-$VERSION"
DIST="$WORK/dist"

log()  { echo "[gfx-build:$NAME] $*"; }
fail() { echo "[gfx-build:$NAME] FAIL: $*" >&2; exit 1; }

[[ -d "$SUBOS" ]] || fail "subos '$SUBOS_NAME' not found"
rm -rf "$STAGE"; mkdir -p "$SRC" "$STAGE" "$DIST"

# Same shape as the published 2.39, so a home holding both resolves them the
# same way. Nothing is expected to exist at this path.
# The default library search path compiled into ld.so, and the INTERP of
# glibc's own binaries. See AD-11 in
# xlings/.agents/docs/2026-08-06-subos-architecture-proposal.md.
#
# It must not exist, and it must be DELIBERATE about not existing. For a
# relocatable package the build prefix can never equal the install path, so a
# default search that finds nothing is structural, not an accident: everything
# has to come from DT_RPATH, which is rule 2 stated as a property of the
# artifact rather than as an intention.
#
# What was wrong with the old value is not that it pointed nowhere. It is that
# it pointed at the BUILD MACHINE -- `/home/xlings/.xlings_data/...`, a home
# layout xlings abandoned years ago -- so the artifact leaked the builder's
# disk layout, and the next person to read it could not tell a deliberate dead
# path from a stale one. The current name says which it is without a document.
#
# `/nonexistent` has distribution precedent (Debian gives it to system users),
# so nobody creates one by accident.
#
# Consequences, all of them intended:
#   * an unpatched binary fails LOUDLY at execve with ENOENT, rather than
#     silently picking up the host's loader and mispairing GLIBC_PRIVATE
#   * ld.so.cache never hits; we do not use ldconfig
#   * `--prefix` and DESTDIR are separate, so the install layout is unaffected
PREFIX="/nonexistent/xlings-use-rpath-not-default-search"

TARBALL="$SRC/glibc-$VERSION.tar.xz"
[[ -f "$TARBALL" ]] || {
    log "fetching glibc-$VERSION.tar.xz"
    curl -fsSL --retry 3 -o "$TARBALL" \
        "https://ftp.gnu.org/gnu/glibc/glibc-$VERSION.tar.xz" || fail "download"
}
BUILDDIR="$SRC/glibc-$VERSION"
rm -rf "$BUILDDIR"; mkdir -p "$BUILDDIR"
tar xf "$TARBALL" -C "$BUILDDIR" --strip-components=1 || fail "extract"

export PATH="$SUBOS/bin:$SUBOS/usr/bin:$PATH"
export CC="$SUBOS/bin/gcc" CXX="$SUBOS/bin/g++"
[[ -x "$CC" ]] || fail "no gcc in the subos"

# NO CPPFLAGS/LDFLAGS pointing at the subos.
#
# glibc builds against the KERNEL headers and nothing else; handing it the
# sysroot's include directory puts the OLD glibc's headers ahead of the ones it
# is building, and the failures read as glibc's own source being broken.
unset CPPFLAGS LDFLAGS LD_LIBRARY_PATH

mkdir -p "$BUILDDIR/_b" && cd "$BUILDDIR/_b" || fail "cd"
log "configuring $VERSION (prefix=$PREFIX)"
# --enable-kernel: the oldest kernel this build supports. 4.19 is the floor
#   most distributions target; raising it drops compatibility code, lowering it
#   is pointless for a payload that ships with xlings.
# --disable-werror: glibc treats new gcc diagnostics as errors, and this is
#   built with a compiler newer than the release.
# --with-headers: the subos's kernel headers, which is the one thing it does
#   take from there.
../configure \
    --prefix="$PREFIX" \
    --libdir="$PREFIX/lib" \
    --with-headers="$SUBOS/usr/include" \
    --enable-kernel=4.19 \
    --disable-werror \
    --disable-profile \
    --disable-nscd \
    --enable-stack-protector=strong \
    > "$WORK/$NAME-configure.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-configure.log"; fail "configure"; }

log "building (this takes a while)"
make -j"$(nproc)" > "$WORK/$NAME-build.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-build.log"; fail "make"; }

log "staging"
make install DESTDIR="$STAGE" >> "$WORK/$NAME-build.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-build.log"; fail "make install"; }

PAYLOAD="$WORK/payload/$NAME-$VERSION"
rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD"
cp -a "$STAGE$PREFIX/." "$PAYLOAD/" || fail "payload copy"

# lib64 beside lib, because that is where the recipe and every elfpatched
# consumer look for the loader (`exports.runtime.loader = lib64/ld-linux-...`).
if [[ ! -d "$PAYLOAD/lib64" ]]; then
    ln -s lib "$PAYLOAD/lib64" || fail "lib64 link"
fi

# ── the checks ──────────────────────────────────────────────────────────
log "checking the payload"
leaks=0
LOADER="$(find "$PAYLOAD" -maxdepth 2 -name 'ld-linux-*.so.*' ! -type l | head -1)"
[[ -n "$LOADER" ]] || { echo "    no ld-linux in the payload"; leaks=$((leaks+1)); }

# The one that matters: the loader has to run and report the version we asked
# for. A glibc that builds and does not run is not detectable from file lists.
if [[ -n "$LOADER" ]]; then
    got="$("$LOADER" --version 2>/dev/null | head -1)"
    case "$got" in
        *"$VERSION"*) log "  loader reports: $got" ;;
        *) echo "    loader reports '$got', expected $VERSION"; leaks=$((leaks+1)) ;;
    esac
fi

# The prefix is a decision about the ARTIFACT, so check the artifact (R4).
#
# Without this, a `--prefix` that silently failed to take -- or a future edit
# that reverts it -- produces a payload whose default search path is a real
# directory on the build machine, and nothing anywhere says so. That is exactly
# how the old prefix survived across several releases.
if [[ -n "$LOADER" ]]; then
    if strings "$LOADER" 2>/dev/null | grep -qF "$PREFIX"; then
        log "  default search path: $PREFIX (reserved, cannot exist)"
    else
        echo "    the loader does not carry the reserved prefix; its default"
        echo "    library search path is something else:"
        strings "$LOADER" 2>/dev/null | grep -E "^/[^ ]*/lib(64)?$" | head -3 \
            | sed 's/^/      /'
        leaks=$((leaks+1))
    fi
    # And it must not name this machine. The payload is published; a build
    # path in it is a fact about the builder's disk, not about glibc.
    if strings "$LOADER" 2>/dev/null | grep -qF "$HOME"; then
        echo "    the loader carries a path from this machine's \$HOME"
        leaks=$((leaks+1))
    fi
fi

# And libc has to load under it, which is the pairing that actually gets used.
if [[ -n "$LOADER" && -f "$PAYLOAD/lib/libc.so.6" ]]; then
    if ! "$LOADER" --library-path "$PAYLOAD/lib" "$PAYLOAD/lib/libc.so.6" \
            >/dev/null 2>&1; then
        echo "    libc.so.6 does not run under the built loader"
        leaks=$((leaks+1))
    fi
fi

(( leaks == 0 )) || fail "$leaks problem(s) — payload not packaged"

TAR="$DIST/$NAME-$VERSION-linux-x86_64.tar.gz"
rm -f "$TAR"
tar czf "$TAR" -C "$(dirname "$PAYLOAD")" "$(basename "$PAYLOAD")" || fail "tar"
log "packaged $(basename "$TAR") ($(du -h "$TAR" | cut -f1))"
log "sha256 $(sha256sum "$TAR" | cut -d' ' -f1)"
