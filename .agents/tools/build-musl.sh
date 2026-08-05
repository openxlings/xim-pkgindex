#!/usr/bin/env bash
# Build musl libc from source into an xlings payload.
#
# musl is far less hostile to package than glibc (see
# graphics/build-glibc.sh), but two of its defaults are wrong for a payload
# that has to be relocatable:
#
#   * `--syslibdir` defaults to /lib, and `make install` puts the loader
#     symlink `ld-musl-<arch>.so.1` THERE, not under --prefix. A payload built
#     with the default has no loader in it at all — the one artifact the
#     package exists to ship. Point it inside the prefix.
#   * that symlink is written as an ABSOLUTE path to $prefix/lib/libc.so, and
#     $prefix is a build-machine path that does not exist on any user's disk.
#     Rewrite it relative so the payload resolves wherever it is unpacked.
#
# `--disable-gcc-wrapper` is deliberate too: musl ships a `musl-gcc` wrapper
# script, and `pkgs/m/musl-gcc.lua` already registers that program name with
# xvm. Two packages claiming one (name, version) is refused outright, so this
# package must not ship it.
#
# Unlike glibc, musl bakes no default library search path from --prefix into
# the loader (it reads /etc/ld-musl-<arch>.path, else falls back to
# /lib:/usr/local/lib:/usr/lib), so the prefix here only has to be inert. It
# follows glibc's shape for consistency.
#
# Usage:  build-musl.sh <version>            (e.g. build-musl.sh 1.2.6)
set -uo pipefail

VERSION="${1:?usage: build-musl.sh <version>}"
NAME=musl
ARCH="$(uname -m)"
WORK="${XLINGS_MUSL_WORK:-${TMPDIR:-/tmp}/xlings-musl}"
SRC="$WORK/src"
STAGE="$WORK/stage/$NAME-$VERSION"
DIST="$WORK/dist"

log()  { echo "[build:$NAME] $*"; }
fail() { echo "[build:$NAME] FAIL: $*" >&2; exit 1; }

[[ "$ARCH" == "x86_64" ]] || fail "this script only builds the x86_64 payload (host is $ARCH)"

rm -rf "$STAGE"; mkdir -p "$SRC" "$STAGE" "$DIST"

PREFIX="/home/xlings/.xlings_data/xim/xpkgs/fromsource-x-$NAME/$VERSION"

TARBALL="$SRC/musl-$VERSION.tar.gz"
[[ -f "$TARBALL" ]] || {
    log "fetching musl-$VERSION.tar.gz"
    curl -fsSL --retry 3 -o "$TARBALL" \
        "https://musl.libc.org/releases/musl-$VERSION.tar.gz" || fail "download"
}

BUILDDIR="$SRC/musl-$VERSION"
rm -rf "$BUILDDIR"; mkdir -p "$BUILDDIR"
tar xf "$TARBALL" -C "$BUILDDIR" --strip-components=1 || fail "extract"

cd "$BUILDDIR" || fail "cd"

# musl builds against the kernel headers and its own tree only. Anything
# inherited from a subos here would put another libc's headers ahead of the
# one being built.
unset CPPFLAGS LDFLAGS LD_LIBRARY_PATH

log "configuring $VERSION (prefix=$PREFIX)"
./configure \
    --prefix="$PREFIX" \
    --syslibdir="$PREFIX/lib" \
    --disable-gcc-wrapper \
    --enable-shared \
    --enable-static \
    > "$WORK/$NAME-configure.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-configure.log"; fail "configure"; }

log "building"
make -j"$(nproc)" > "$WORK/$NAME-build.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-build.log"; fail "make"; }

log "staging"
make install DESTDIR="$STAGE" >> "$WORK/$NAME-build.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-build.log"; fail "make install"; }

PAYLOAD="$WORK/payload/$NAME-$VERSION"
rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD"
cp -a "$STAGE$PREFIX/." "$PAYLOAD/" || fail "payload copy"

# The loader symlink, made relative. `cp -a` preserved whatever `make install`
# wrote, which is an absolute path into $PREFIX.
LOADER_LINK="$PAYLOAD/lib/ld-musl-$ARCH.so.1"
if [[ -L "$LOADER_LINK" ]]; then
    ln -sfn libc.so "$LOADER_LINK" || fail "loader symlink"
fi

# lib64 beside lib. Nothing in this package points at lib64, but a consumer
# elfpatched against a glibc payload looks there, and a subos holding both
# should find a directory rather than a dangling path.
[[ -d "$PAYLOAD/lib64" ]] || ln -s lib "$PAYLOAD/lib64" || fail "lib64 link"

# ── the checks ──────────────────────────────────────────────────────────
log "checking the payload"
leaks=0

LOADER="$PAYLOAD/lib/libc.so"
[[ -f "$LOADER" ]] || { echo "    no lib/libc.so in the payload"; leaks=$((leaks+1)); }
[[ -L "$LOADER_LINK" ]] || { echo "    no lib/ld-musl-$ARCH.so.1 symlink"; leaks=$((leaks+1)); }
[[ -e "$LOADER_LINK" ]] || { echo "    loader symlink is dangling"; leaks=$((leaks+1)); }

# The one that matters: the loader has to run and report the version we asked
# for. A libc that builds and does not run is not detectable from file lists.
if [[ -f "$LOADER" ]]; then
    got="$("$LOADER" 2>&1 | head -2 | tr '\n' ' ')"
    case "$got" in
        *"$VERSION"*) log "  loader reports: $got" ;;
        *) echo "    loader reports '$got', expected $VERSION"; leaks=$((leaks+1)) ;;
    esac
fi

# And a program actually linked against it has to run under it. This is the
# pairing that gets used, and the only check that would catch a payload whose
# loader and libc disagree.
if [[ -f "$LOADER" ]]; then
    cat > "$WORK/hello.c" <<'EOF'
#include <stdio.h>
int main(void) { printf("musl payload ok\n"); return 0; }
EOF
    if gcc -nostdinc -nostdlib -static-libgcc \
           -isystem "$PAYLOAD/include" \
           -o "$WORK/hello" \
           "$PAYLOAD/lib/crt1.o" "$PAYLOAD/lib/crti.o" \
           "$WORK/hello.c" \
           -L"$PAYLOAD/lib" -lc "$PAYLOAD/lib/crtn.o" \
           -Wl,--dynamic-linker="$LOADER_LINK" \
           > "$WORK/hello.log" 2>&1; then
        out="$("$WORK/hello" 2>&1)"
        [[ "$out" == "musl payload ok" ]] \
            || { echo "    program linked against the payload printed '$out'"; leaks=$((leaks+1)); }
    else
        tail -10 "$WORK/hello.log"
        echo "    could not link a program against the payload"
        leaks=$((leaks+1))
    fi
fi

# musl-gcc must not be in here (musl-gcc.lua owns that xvm program name).
if [[ -e "$PAYLOAD/bin/musl-gcc" ]]; then
    echo "    payload ships bin/musl-gcc — --disable-gcc-wrapper did not take"
    leaks=$((leaks+1))
fi

(( leaks == 0 )) || fail "$leaks problem(s) — payload not packaged"

TAR="$DIST/$NAME-$VERSION-linux-$ARCH.tar.gz"
rm -f "$TAR"
tar czf "$TAR" -C "$(dirname "$PAYLOAD")" "$(basename "$PAYLOAD")" || fail "tar"
log "packaged $(basename "$TAR") ($(du -h "$TAR" | cut -f1))"
log "sha256 $(sha256sum "$TAR" | cut -d' ' -f1)"
