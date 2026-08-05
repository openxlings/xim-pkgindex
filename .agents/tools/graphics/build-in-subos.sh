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
#       [--system autotools|meson|cmake] [--deps 'xorgproto libX11'] \
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
    echo "usage: $0 --name N --version V --url U [--system auto|autotools|meson|cmake] [--deps '...'] [-- args]" >&2
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
# `usr/bin` as well as `bin`: `bin` holds the shims xlings installed, and
# `usr/bin` is where a package THIS SCRIPT built puts its tools. mesa looks up
# `glslangValidator` by name, and glslang is one of ours — without this it is
# reported missing while sitting two directories away.
export PATH="$SUBOS/bin:$SUBOS/usr/bin:$PATH"

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

# So the binaries the BUILD runs can actually run.
#
# wayland builds `wayland-scanner` and then executes it to generate its own
# protocol sources. `-Wl,-rpath,$ORIGIN` is right for a payload and useless for
# a tool being run out of a build directory, so the scanner dies on
# `libexpat.so.1: cannot open shared object file` with the library sitting in
# the sysroot.
#
# An rpath and NOT LD_LIBRARY_PATH, which was tried first and is a trap:
# LD_LIBRARY_PATH applies to every process the build starts, including meson
# and python, which are elfpatched to a particular glibc. A second libc ahead
# of theirs segfaults them in the vDSO (`__vdso_time`) before they print
# anything — which reads as a broken toolchain rather than as one env var.
#
# These subos paths do not ship: the staging pass below rewrites every ELF in
# the payload back to $ORIGIN, and the leak check then fails the build if any
# survived.
GLIBC_LIB64="$(dirname "$(readlink -f "$SUBOS/lib/libc.so.6" 2>/dev/null)" 2>/dev/null)"
# --disable-new-dtags: emit DT_RPATH, which is TRANSITIVE, rather than
# DT_RUNPATH, which is not.
#
# That distinction is the whole problem here. A build-time tool needs not only
# its own libraries but its libraries' libraries — wayland-scanner links
# libxml2, libxml2 needs libm — and DT_RUNPATH is consulted only for an
# object's direct dependencies. libm was therefore looked up with no path at
# all and fell through to ld.so's built-in default, which for the published
# glibc is the prefix of the machine that built it. The error names libm and
# the fix is one link flag.
#
# Only build-tree binaries keep this: the staging pass rewrites every ELF in
# the payload to $ORIGIN before it ships.
LDFLAGS="$LDFLAGS -Wl,--disable-new-dtags -Wl,-rpath,$SUBOS/usr/lib -Wl,-rpath,$SUBOS/lib"
[[ -n "$GLIBC_LIB64" ]] && LDFLAGS="$LDFLAGS -Wl,-rpath,$GLIBC_LIB64"

# And the loader needs to be told where libc's siblings are.
#
# `ld.so` carries a built-in default search path — glibc's configure prefix,
# which for the published package is the path on the machine that BUILT it
# (`/home/xlings/.xlings_data/...`). Nothing on any other machine is there, so
# a freshly linked tool dies on `libm.so.6: cannot open shared object file`
# while `objdump -p` shows a RUNPATH that plainly contains it. Everything else
# works because xlings's elfpatch writes explicit RUNPATHs at install time, and
# a binary in a build directory has not been through that.
#
# glibc's OWN lib64 and nothing else. `<subos>/lib` was tried and segfaults
# meson in the vDSO: it is a symlink farm holding gcc's runtime beside glibc's,
# and putting that ahead of an elfpatched python's own libraries is a libc/
# libstdc++ mismatch. This directory is the same glibc the toolchain already
# runs on, so nothing changes for the tools and the loader gains the one path
# it was missing.
# Scoped to the compile/install step (see BUILD_ENV below), never exported for
# the whole script: meson and ninja are shims into the xlings binary, and any
# libc ahead of the one THEY were elfpatched against segfaults them in the vDSO
# before they print a word. Configure runs clean; only the tools this build
# produces need the extra path.
BUILD_ENV=()

# --deps: xlings packages whose payload is a build dependency but which do not
# stage themselves into the subos sysroot.
#
# Most of this stack does stage itself, because these recipes declare headers
# and libraries. Packages predating those declarations — libxml2 is the one
# this stack needs — install a payload and put nothing in `<subos>/usr`, so
# wayland's `Dependency "libxml-2.0" not found` is true of the sysroot and
# false of the machine.
#
# Adding the payload directly is not a hole in the isolation: the whole point
# of PKG_CONFIG_LIBDIR pointing only at the subos is to keep the HOST out, and
# a path under `data/xpkgs/` is as much ours as the sysroot is. What it must
# not become is a wildcard over everything installed — each package is named
# here, so a dependency that is not declared still fails loudly.
for dep in $DEPS; do
    depdir="$(ls -d "$XHOME"/data/xpkgs/*-"$dep"/*/ 2>/dev/null | head -1)"
    if [[ -z "$depdir" ]]; then
        fail "--deps $dep: not installed in $XHOME (xlings install $dep)"
    fi
    log "  dep $dep -> ${depdir#"$XHOME"/data/xpkgs/}"
    if [[ -d "$depdir/lib/pkgconfig" ]]; then
        # Rewrite `prefix=` into a scratch copy rather than use the payload's
        # .pc as-is. libxml2's ships `prefix=/tmp/libxml2-install` — the
        # directory it was built in, on a machine that no longer exists — so
        # pkg-config answers with -I/tmp/libxml2-install/include/libxml2 and
        # the compile fails on a header that is right there. Configure still
        # SUCCEEDS, because pkg-config only reports what the file says; the
        # failure lands one step later, at the first #include.
        #
        # The payload is not touched: it is shared between subos and read-only
        # as far as a build is concerned.
        pcdir="$WORK/pc/$dep"
        mkdir -p "$pcdir"
        for pc in "$depdir"/lib/pkgconfig/*.pc; do
            [[ -e "$pc" ]] || continue
            sed "s#^prefix=.*#prefix=${depdir%/}#" "$pc" > "$pcdir/$(basename "$pc")"
        done
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$pcdir"
    fi
    [[ -d "$depdir/include" ]] && CPPFLAGS="$CPPFLAGS -I$depdir/include"
    if [[ -d "$depdir/lib" ]]; then
        # A staged copy with an RPATH, not the payload itself.
        #
        # DT_RUNPATH is NOT transitive. libxml2.so.2 needs libm, and the
        # payload's copy carries no RUNPATH at all, so libm is looked up
        # against libxml2's (empty) path and falls through to ld.so's built-in
        # default — which for the published glibc is the prefix of the machine
        # that built it, `/home/xlings/.xlings_data/...`. The tool then dies on
        # `libm.so.6: cannot open shared object file` while its own RUNPATH
        # plainly lists a directory containing it, because that RUNPATH was
        # never going to be consulted for a dependency's dependency.
        #
        # LD_LIBRARY_PATH would fix it and cannot be used: the build's own
        # tools (meson, ninja, python) are NOT elfpatched — python's INTERP is
        # the host's /lib64/ld-linux — so any xlings libc ahead of theirs
        # segfaults them in the vDSO before they print anything.
        #
        # So: copy, patch the copy, link against the copy. The payload is
        # shared between subos and stays untouched.
        deplib="$WORK/deplib/$dep"
        rm -rf "$deplib"; mkdir -p "$deplib"
        cp -a "$depdir"/lib/*.so* "$deplib/" 2>/dev/null || true
        for so in "$deplib"/*.so*; do
            [[ -f "$so" && ! -L "$so" ]] || continue
            patchelf --set-rpath "\$ORIGIN${GLIBC_LIB64:+:$GLIBC_LIB64}" "$so" 2>/dev/null || true
        done
        LDFLAGS="$LDFLAGS -L$deplib -Wl,-rpath-link,$deplib -Wl,-rpath,$deplib"
    fi
done
export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR" CPPFLAGS LDFLAGS

if [[ "$SYSTEM" == auto ]]; then
    if   [[ -f "$BUILDDIR/meson.build" ]]; then SYSTEM=meson
    elif [[ -f "$BUILDDIR/configure"   ]]; then SYSTEM=autotools
    elif [[ -f "$BUILDDIR/CMakeLists.txt" ]]; then SYSTEM=cmake
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
    "${BUILD_ENV[@]}" make -j"$(nproc)" > "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "make"; }
    "${BUILD_ENV[@]}" make install DESTDIR="$STAGE" >> "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "make install"; }
    ;;
  meson)
    "$SUBOS/bin/meson" setup _b --prefix="$PREFIX" --libdir=lib \
        --buildtype=release -Ddefault_library=shared "${EXTRA[@]}" > "$WORK/$NAME-configure.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-configure.log"; fail "meson setup"; }
    "${BUILD_ENV[@]}" "$SUBOS/bin/ninja" -C _b > "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "ninja"; }
    DESTDIR="$STAGE" "$SUBOS/bin/meson" install -C _b >> "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "meson install"; }
    ;;
  cmake)
    # Out-of-tree, and CMAKE_INSTALL_PREFIX=/usr with DESTDIR so the staged
    # layout matches what the other two systems produce.
    "$SUBOS/bin/cmake" -S . -B _b -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
        "${EXTRA[@]}" > "$WORK/$NAME-configure.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-configure.log"; fail "cmake configure"; }
    "${BUILD_ENV[@]}" "$SUBOS/bin/ninja" -C _b > "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "ninja"; }
    DESTDIR="$STAGE" "$SUBOS/bin/cmake" --install _b >> "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "cmake install"; }
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
#
# Every ELF, not just *.so*: a payload can ship executables (wayland's
# `wayland-scanner`, and it is the one downstream packages run), and those were
# linked with the build-time rpath above. Matching on the name missed them
# entirely — both here and in the leak check below — so a subos path could ship
# in a binary while every library came out clean.
is_elf() { [[ "$(head -c4 "$1" 2>/dev/null)" == $'\x7fELF' ]]; }
while IFS= read -r -d '' f; do
    is_elf "$f" || continue
    case "${f#"$PAYLOAD"/}" in
        # A binary looks for its libraries one level up, not beside itself.
        bin/*) patchelf --set-rpath '$ORIGIN/../lib:$ORIGIN' "$f" 2>/dev/null || true ;;
        *)     patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true ;;
    esac
done < <(find "$PAYLOAD" -type f ! -type l -print0)

# ── the check that makes this worth scripting ───────────────────────────
leaks=0
report_leak() { echo "    $*"; leaks=$((leaks+1)); }

log "checking for host leakage"
while IFS= read -r -d '' f; do
    is_elf "$f" || continue
    rp="$(patchelf --print-rpath "$f" 2>/dev/null || true)"
    case "$rp" in
        ''|'$ORIGIN'*) ;;
        *) report_leak "RPATH names a path outside the payload: ${f#$PAYLOAD/} → $rp" ;;
    esac
done < <(find "$PAYLOAD" -type f ! -type l -print0)

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

    # The copy that goes into the SUBOS gets subos paths, not the payload's
    # $ORIGIN. These two copies are the same files with different jobs: the
    # payload ships and is relocated by xlings's elfpatch at install time,
    # while this one is run right here, by the next package's build, with
    # nothing to relocate it.
    #
    # wayland is the case that needs it: wayland-protocols invokes the
    # installed `wayland-scanner`, whose payload RPATH of `$ORIGIN/../lib`
    # points at `<subos>/usr/lib`, and libexpat lives in `<subos>/lib`. The
    # error names libexpat and looks like a missing package.
    while IFS= read -r -d '' f; do
        is_elf "$f" || continue
        # --force-rpath: DT_RPATH, which is transitive. Without it patchelf
        # writes DT_RUNPATH and the scanner finds libxml2 but not libxml2's
        # libm — the same non-transitivity that the link flag above works
        # around, arriving a second time through a different door.
        patchelf --force-rpath --set-rpath \
            "$SUBOS/usr/lib:$SUBOS/lib${GLIBC_LIB64:+:$GLIBC_LIB64}" \
            "$f" 2>/dev/null || true
    done < <(find "$SUBOS/usr/bin" -type f ! -type l -print0 2>/dev/null)

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
