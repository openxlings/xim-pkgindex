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
# Usage:  build-glibc.sh <upstream> [<package-version> [<revision>]]
#           build-glibc.sh 2.44              -> glibc-2.44-linux-x86_64.tar.gz
#           build-glibc.sh 2.44 2.44.3       -> glibc-2.44.3-linux-x86_64.tar.gz
#           build-glibc.sh 2.44 2.44.3 1     -> glibc-2.44.3-r1-linux-x86_64.tar.gz
#
# THE PACKAGE VERSION AND THE REVISION
#
# <package-version> is the index key, and it differs from <upstream> for
# history only: 2.44.1 to 2.44.3 are upstream 2.44, each rebuilt for a reason
# of ours (a prefix, a patch). They were given new versions because a
# published url and sha256 are immutable -- a client holding a cached index
# still has the old hash, so new bytes behind the old url fail its integrity
# check -- and because nothing else told a machine already on the old payload
# that it was stale. The new version had to sort ABOVE the one it replaced:
# a range such as `xim:glibc@>=2.38` resolves through `semver::select_best`,
# the maximum satisfying version, which is why `2.44r1` (a pre-release of 2.44
# to xlings' semver) was abandoned for `2.44.1`.
#
# That scheme spent a version key per packaging fix and made the binding --
# the payload directory name -- change with it (openxlings/xlings#620). A
# rebuild for a reason of ours now keeps the version key and raises
# `revision` on the version entry (docs/V2/xpackage-spec.md). The url and the
# sha256 stay immutable, so the rebuilt asset needs a name of its own:
# <revision> adds `-r<N>` to the asset and to its release tag, and the recipe
# entry keeps its key, takes the new url and sha256, and states the new
# revision. A client that implements revision reinstalls a payload whose
# recorded revision differs; an older one installs the new asset on its next
# fresh install only.
set -uo pipefail

UPSTREAM="${1:?usage: build-glibc.sh <upstream> [<package-version> [<revision>]]}"
VERSION="${2:-$UPSTREAM}"   # the index key the artifact is published under
REVISION="${3:-0}"          # the entry's `revision`; names the asset when > 0
[[ "$REVISION" =~ ^(0|[1-9][0-9]*)$ ]] || {
    echo "[gfx-build:glibc] revision must be a non-negative integer: $REVISION" >&2
    exit 2
}
if (( REVISION > 0 )); then
    ASSET_VERSION="$VERSION-r$REVISION"   # also the release tag
else
    ASSET_VERSION="$VERSION"
fi
NAME=glibc
SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxbuild}"
XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS="$XHOME/subos/$SUBOS_NAME"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"
SRC="$WORK/src"
STAGE="$WORK/stage/$NAME-$ASSET_VERSION"
DIST="$WORK/dist"

log()  { echo "[gfx-build:$NAME] $*"; }
fail() { echo "[gfx-build:$NAME] FAIL: $*" >&2; exit 1; }
# 3, not 1: nothing was built because there was nowhere to build it. See the
# exit-code contract in .agents/tools/README.md.
skip() { echo "[gfx-build:$NAME] SKIP: $*" >&2; exit 3; }

[[ -n "${GLIBC_BUILD_CC:-}" || -d "$SUBOS" ]] || skip "subos '$SUBOS_NAME' not found — xlings subos new $SUBOS_NAME"
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
#
# PADDED TO 255 BYTES, SO THAT THE INSTALL CAN RELOCATE IT (openxlings/xlings#621)
#
# The prefix is also where libc finds its own data: lib/locale (and its
# locale-archive), lib/gconv, share/locale, share/zoneinfo, etc/localtime,
# libexec/getconf. Left dead, none of it is reachable. Measured on 2.44.3
# under LANG=C.UTF-8: setlocale(LC_ALL, "") and setlocale(LC_ALL, "C.UTF-8")
# return NULL, and iconv_open("GBK", "UTF-8") fails although the payload
# ships 255 gconv modules.
#
# These paths are C strings inside ELF files, so the recipe rewrites them at
# install time without changing any length: each occurrence of the
# placeholder becomes the install directory followed by `/` up to the
# placeholder's length, and `<install>////lib/locale` names the same
# directory as `<install>/lib/locale`. The file, every string in it, and
# every length compiled in beside a string (sizeof, a strlen the compiler
# folded, ld.so's table of directory lengths) stay valid, so glibc's sources
# need no change for it. That requires the placeholder to be at least as long
# as the install path, and the 48-byte reserved prefix is shorter than an
# ordinary one (`/home/alice/.xlings/data/xpkgs/xim-x-glibc/2.44.3` is 49
# bytes, mcpp's registry path 56 or more).
#
# So the reserved prefix stays the leading part -- an unrelocated payload
# still resolves nothing on the host, which is the property above -- and one
# padding component brings the whole to 255 bytes, conda's length. Each
# component stays within NAME_MAX, and 255 bytes is the longest install
# directory the recipe accepts; it refuses a longer one by name.
RESERVED_PREFIX="/nonexistent/xlings-use-rpath-not-default-search"
PREFIX="$RESERVED_PREFIX/padding-to-255-bytes-for-install-time-relocation"
while (( ${#PREFIX} < 255 )); do PREFIX+="_"; done
# The recipe (pkgs/g/glibc.lua) spells the same string; both have to agree
# byte for byte. The recipe refuses a payload padded any other way.
(( ${#PREFIX} == 255 )) || fail "padded prefix is ${#PREFIX} bytes, not 255"
for component in ${PREFIX//\// }; do
    (( ${#component} <= 255 )) || fail "prefix component longer than NAME_MAX: $component"
done

TARBALL="$SRC/glibc-$UPSTREAM.tar.xz"
[[ -f "$TARBALL" ]] || {
    log "fetching glibc-$UPSTREAM.tar.xz"
    curl -fsSL --retry 3 -o "$TARBALL" \
        "https://ftp.gnu.org/gnu/glibc/glibc-$UPSTREAM.tar.xz" || fail "download"
}
if [[ "$UPSTREAM" == 2.44 ]]; then
    printf '%s  %s\n' 37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667 "$TARBALL" \
        | sha256sum -c - || fail "source archive SHA256 mismatch"
else
    fail "upstream $UPSTREAM has no reviewed source digest"
fi
BUILDDIR="$SRC/glibc-$UPSTREAM"
rm -rf "$BUILDDIR"; mkdir -p "$BUILDDIR"
tar xf "$TARBALL" -C "$BUILDDIR" --strip-components=1 || fail "extract"

# ── patches ─────────────────────────────────────────────────────────────
#
# Version-pinned by filename. A patch that stops applying is a HARD failure,
# not a warning: `patch` refusing to find its context is the only signal that
# the thing it was compensating for has moved, and a payload built without it
# looks identical from the outside.
PATCHDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patches"
shopt -s nullglob
for p in "$PATCHDIR/glibc-$UPSTREAM-"*.patch; do
    log "applying $(basename "$p")"
    patch -p1 -d "$BUILDDIR" --forward < "$p" || fail "patch $(basename "$p")"
done
shopt -u nullglob

# A native CI builder may bootstrap with its distribution compiler. The
# resulting payload still uses the same isolation patches and reserved prefix.
BUILD_ARCH="${GLIBC_BUILD_ARCH:-$(uname -m)}"
case "$BUILD_ARCH" in
    arm64|aarch64) BUILD_ARCH=aarch64; LIBDIR=lib; LOADER_NAME=ld-linux-aarch64.so.1 ;;
    x86_64) LIBDIR=lib64; LOADER_NAME=ld-linux-x86-64.so.2 ;;
    *) fail "unsupported glibc build architecture: $BUILD_ARCH" ;;
esac
[[ "$BUILD_ARCH" == "$(uname -m)" || "$BUILD_ARCH" == aarch64 && "$(uname -m)" == arm64 ]] \
    || fail "glibc builds and probes require a native $BUILD_ARCH host"
if [[ -n "${GLIBC_BUILD_CC:-}" ]]; then
    export CC="$GLIBC_BUILD_CC" CXX="${GLIBC_BUILD_CXX:-g++}"
    KERNEL_HEADERS="${GLIBC_BUILD_HEADERS:?GLIBC_BUILD_HEADERS is required for standalone builds}"
else
    export PATH="$SUBOS/bin:$SUBOS/usr/bin:$PATH"
    export CC="$SUBOS/bin/gcc" CXX="$SUBOS/bin/g++"
    KERNEL_HEADERS="$SUBOS/usr/include"
fi
command -v "$CC" >/dev/null || fail "compiler not found: $CC"
[[ -f "$KERNEL_HEADERS/linux/limits.h" ]] || fail "kernel UAPI headers absent: $KERNEL_HEADERS"

# NO CPPFLAGS/LDFLAGS pointing at the subos.
#
# glibc builds against the KERNEL headers and nothing else; handing it the
# sysroot's include directory puts the OLD glibc's headers ahead of the ones it
# is building, and the failures read as glibc's own source being broken.
unset CPPFLAGS LDFLAGS LD_LIBRARY_PATH LD_PRELOAD CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH GCC_EXEC_PREFIX COMPILER_PATH

mkdir -p "$BUILDDIR/_b" && cd "$BUILDDIR/_b" || fail "cd"
log "configuring $UPSTREAM (prefix=$PREFIX)"
# --enable-kernel: the oldest kernel this build supports. 4.19 is the floor
#   most distributions target; raising it drops compatibility code, lowering it
#   is pointless for a payload that ships with xlings.
# --disable-werror: glibc treats new gcc diagnostics as errors, and this is
#   built with a compiler newer than the release.
# --with-headers: the subos's kernel headers, which is the one thing it does
#   take from there.
# --without-selinux: configure probes libselinux by LINKING, which finds the
#   host's library, while the subos compiler cannot see the host's headers --
#   so a host with libselinux fails in nss/makedb.c, and one where both are
#   visible links a host library into the payload. 2.44.2 was built without it
#   (its makedb NEEDs libc.so.6 only); this makes that a decision, not a host
#   accident.
../configure \
    --prefix="$PREFIX" \
    --libdir="$PREFIX/lib" \
    --with-headers="$KERNEL_HEADERS" \
    --enable-kernel=4.19 \
    --disable-werror \
    --disable-profile \
    --disable-nscd \
    --enable-stack-protector=strong \
    --without-selinux \
    > "$WORK/$NAME-configure.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-configure.log"; fail "configure"; }

log "building (this takes a while)"
make -j"$(nproc)" > "$WORK/$NAME-build.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-build.log"; fail "make"; }

log "staging"
make install DESTDIR="$STAGE" >> "$WORK/$NAME-build.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-build.log"; fail "make install"; }

# The archive's top-level directory is the archive's own stem. The recipe
# derives the payload root as `install_file()` minus `.tar.gz`, and falls back
# to searching the shared extraction directory only when that is absent; the
# assets up to 2.44.3 revision 0 hold `glibc-<version>/` and always take the
# fallback, which picks the first directory holding a libc -- with a stale
# `glibc-2.44.3/` beside `glibc-2.44.3-r1-.../`, the wrong one.
STEM="$NAME-$ASSET_VERSION-linux-$BUILD_ARCH"
PAYLOAD="$WORK/payload/$STEM"
rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD"
cp -a "$STAGE$PREFIX/." "$PAYLOAD/" || fail "payload copy"

cp "$BUILDDIR/COPYING.LIB" "$PAYLOAD/LICENSE"
{
    printf 'Upstream: glibc %s\nPackage: %s revision %s\nArchitecture: %s\n' "$UPSTREAM" "$VERSION" "$REVISION" "$BUILD_ARCH"
    printf 'Bootstrap compiler: %s\n' "$("$CC" --version | head -1)"
    printf 'Source digest: '; sha256sum "$TARBALL"
    printf 'Isolation patches:\n'; sha256sum "$PATCHDIR/glibc-$UPSTREAM-"*.patch
} > "$PAYLOAD/PROVENANCE.txt"

# lib64 beside lib, because that is where the recipe and every elfpatched
# consumer look for the loader (`exports.runtime.loader = lib64/ld-linux-...`).
if [[ "$LIBDIR" == lib64 && ! -d "$PAYLOAD/lib64" ]]; then
    ln -s lib "$PAYLOAD/lib64" || fail "lib64 link"
fi

# The UTF-8 charmap uncompressed, beside the UTF-8.gz `make install` writes.
# The recipe compiles C.utf8 at install time with this payload's localedef
# (pkgs/g/glibc.lua, __generate_c_utf8), and localedef reads a `.gz` charmap
# by spawning `gzip -d -c` from PATH -- a host tool that xlings itself does not
# need, since it extracts archives in-process. localedef opens the plain name
# first, so shipping it removes the dependency for the one charmap used.
CHARMAPS="$PAYLOAD/share/i18n/charmaps"
gzip -dc "$CHARMAPS/UTF-8.gz" > "$CHARMAPS/UTF-8" || fail "UTF-8 charmap"
chmod 644 "$CHARMAPS/UTF-8"

# ── drop the RPATH the subos compiler injected ──────────────────────────
#
# gcc in the build subos links bin/* , sbin/* and libexec/getconf/* with
#
#   DT_RPATH = <builder home>/.xlings/data/xpkgs/xim-x-glibc/<ver>/lib64
#              :<builder home>/.xlings/data/xpkgs/xim-x-gcc/<ver>/lib64
#
# which is the build machine written into a published artifact, and it is not
# cosmetic. The first version of this check skipped these files on the
# reasoning that their PT_INTERP is the reserved prefix, so they can never
# start and their RPATH can never be followed. That reasoning is wrong at
# exactly one step: elfpatch REWRITES PT_INTERP at install time, so they do
# start -- and it rewrites this RPATH in place rather than recomputing it,
# so the payload identity baked in here is the one they get.
#
# Measured: installing such a payload alongside an older glibc gives every one
# of these 16 binaries an interpreter from the NEW payload and a RUNPATH into
# the OLD one, and xlings refuses the install:
#
#   loader/libc payload mismatch in 16 binary(ies)
#
# Removing it is the whole fix. These binaries need no RPATH of their own --
# install-time relocation is what gives them one, and it can only get the
# answer right if it is not handed a stale one to edit.
if command -v patchelf >/dev/null; then
    stripped=0
    for elf in $(find "$PAYLOAD" -type f \( -name '*.so' -o -name '*.so.*' -o -perm -u+x \) 2>/dev/null); do
        head -c 4 "$elf" 2>/dev/null | grep -q $'\x7fELF' || continue
        rp="$(readelf -dW "$elf" 2>/dev/null \
              | sed -n 's/.*\(RPATH\|RUNPATH\).*\[\(.*\)\]/\2/p')"
        [[ -n "$rp" && "$rp" == *"$HOME"* ]] || continue
        patchelf --remove-rpath "$elf" 2>/dev/null && stripped=$((stripped+1))
    done
    [[ $stripped -eq 0 ]] || log "removed the builder's RPATH from $stripped binaries"
else
    fail "patchelf not found — cannot remove the build subos's injected RPATH"
fi

# ── the checks ──────────────────────────────────────────────────────────
log "checking the payload"
leaks=0
LOADER="$(find "$PAYLOAD" -maxdepth 2 -name 'ld-linux-*.so.*' ! -type l | head -1)"
[[ -n "$LOADER" && "$(basename "$LOADER")" == "$LOADER_NAME" ]] || { echo "    no ld-linux in the payload"; leaks=$((leaks+1)); }

# The one that matters: the loader has to run and report the version we asked
# for. A glibc that builds and does not run is not detectable from file lists.
if [[ -n "$LOADER" ]]; then
    got="$("$LOADER" --version 2>/dev/null | head -1)"
    case "$got" in
        *"$UPSTREAM"*) log "  loader reports: $got" ;;
        *) echo "    loader reports '$got', expected $UPSTREAM"; leaks=$((leaks+1)) ;;
    esac
fi

# glibc's bundled 2009i timezone data is regression-only. Install the pinned
# IANA data with the native zic that was built from this glibc source.
TZ_VERSION=2026e
TZ_TARBALL="$SRC/tzdata$TZ_VERSION.tar.gz"
[[ -f "$TZ_TARBALL" ]] || curl -fsSL --retry 3 \
    "https://data.iana.org/time-zones/releases/tzdata$TZ_VERSION.tar.gz" \
    -o "$TZ_TARBALL" || fail "tzdata download"
printf '%s  %s\n' b26882805f26aac59d5b222978e6580484b834ccdc98be89df2f05a6dc53a652 "$TZ_TARBALL" \
    | sha256sum -c - || fail "tzdata source SHA256 mismatch"
TZ_SRC="$WORK/tzdata-$TZ_VERSION"
rm -rf "$TZ_SRC"; mkdir -p "$TZ_SRC" "$PAYLOAD/share/zoneinfo"
tar xf "$TZ_TARBALL" -C "$TZ_SRC" || fail "tzdata extract"
[[ "$(cat "$TZ_SRC/version")" == "$TZ_VERSION" ]] || fail "tzdata version mismatch"
"$LOADER" --library-path "$PAYLOAD/lib" "$BUILDDIR/_b/timezone/zic" \
    -b slim -d "$PAYLOAD/share/zoneinfo" \
    "$TZ_SRC/africa" "$TZ_SRC/antarctica" "$TZ_SRC/asia" "$TZ_SRC/australasia" \
    "$TZ_SRC/europe" "$TZ_SRC/northamerica" "$TZ_SRC/southamerica" \
    "$TZ_SRC/etcetera" "$TZ_SRC/backward" || fail "tzdata compilation"
cp "$TZ_SRC/LICENSE" "$PAYLOAD/TZDATA-LICENSE"
cp "$TZ_SRC/zone.tab" "$TZ_SRC/zone1970.tab" "$TZ_SRC/iso3166.tab" "$PAYLOAD/share/zoneinfo/"
{
    printf '\nTimezone data: IANA %s\nSource digest: ' "$TZ_VERSION"
    sha256sum "$TZ_TARBALL"
} >> "$PAYLOAD/PROVENANCE.txt"

# `strings X | grep -q Y` CANNOT BE USED HERE, and the reason is not style.
#
# This script runs under `set -o pipefail`. `grep -q` exits at the first match,
# `strings` then dies of SIGPIPE, and pipefail reports the pipeline as 141 --
# so a SUCCESSFUL match is read as a failure. Whether strings finishes writing
# before grep leaves is a race on file size and match position, which is why
# this looked like it worked.
#
# The two directions are not symmetric, and that is what makes it worth this
# comment. The prefix check fails LOUDLY on a correct artifact, so somebody
# notices. The $HOME check fails SILENTLY on a leaking one: a payload that
# does name the build machine matches, gets 141, and is reported clean. The
# guard written to stop exactly that artifact could never fire.
#
# So: dump once to a file, grep the file. No pipe, no signal, no race.
strings_of () {  # strings_of <elf> -> path to a cached strings dump
    local elf="$1" key
    key="$(echo "$elf" | tr -c 'A-Za-z0-9' '_')"
    local out="$WORK/strings/$key.txt"
    mkdir -p "$WORK/strings"
    [[ -s "$out" ]] || strings -a "$elf" > "$out" 2>/dev/null
    echo "$out"
}

# The prefix is a decision about the ARTIFACT, so check the artifact (R4).
#
# Without this, a `--prefix` that silently failed to take -- or a future edit
# that reverts it -- produces a payload whose default search path is a real
# directory on the build machine, and nothing anywhere says so. That is exactly
# how the old prefix survived across several releases.
if [[ -n "$LOADER" ]]; then
    ldump="$(strings_of "$LOADER")"
    if grep -qF "$PREFIX" "$ldump"; then
        log "  default search path: $PREFIX (reserved, cannot exist)"
    else
        echo "    the loader does not carry the reserved prefix; its default"
        echo "    library search path is something else:"
        grep -E "^/[^ ]*/lib(64)?$" "$ldump" | head -3 | sed 's/^/      /'
        leaks=$((leaks+1))
    fi

    # The preload path is a decision about the ARTIFACT too, and the same
    # reasoning as the prefix check above applies: a patch that silently
    # stopped applying leaves a loader that reads the HOST's list, which no
    # file listing shows and which only reproduces on a machine that has an
    # /etc/ld.so.preload -- rare on a dev box, common on the audited hosts
    # our users run the artifacts on.
    #
    # Two assertions, because either one alone passes for the wrong reason:
    # the literal must be GONE (the patch changed something) and the
    # sysconfdir form must be PRESENT (it changed it to the right thing).
    if grep -qx "/etc/ld.so.preload" "$ldump"; then
        echo "    the loader still reads the host's /etc/ld.so.preload"
        echo "    (glibc-$UPSTREAM-preload-follows-sysconfdir.patch did not take)"
        leaks=$((leaks+1))
    fi
    if ! grep -qxF "$PREFIX/etc/ld.so.preload" "$ldump"; then
        echo "    the loader does not carry $PREFIX/etc/ld.so.preload"
        leaks=$((leaks+1))
    fi
fi

# Every ELF in the payload, not just the loader -- but only the paths the
# LOADER WILL ACT ON.
#
# The loader is where the prefix decision shows up, so that is where the check
# was written. It is not the only object carrying a compiled-in path: every
# shared object and program here has a PT_INTERP, an absolute path to the
# loader as of build time. In the published 2.44 that is
# `/home/xlings/.xlings_data/...`, which is why `./libc.so.6` on a user's
# machine fails with a bare "No such file or directory" naming libc rather
# than the interpreter it could not find. One object checked out of many is
# how a correct-looking assertion covers a fraction of its subject.
#
# PT_INTERP and DT_RPATH/DT_RUNPATH, NOT `strings | grep $HOME`. An unstripped
# glibc names the builder's include directories all over its debug info -- 280
# objects here -- and none of that is ever resolved at run time. A check that
# cannot tell a path the loader follows from a path the compiler mentioned
# produces 280 findings and zero information, and the first person to see that
# wall deletes the check.
for elf in $(find "$PAYLOAD" -type f \( -name '*.so' -o -name '*.so.*' -o -perm -u+x \) 2>/dev/null); do
    head -c 4 "$elf" 2>/dev/null | grep -q $'\x7fELF' || continue
    rel="${elf#"$PAYLOAD"/}"

    interp="$(readelf -lW "$elf" 2>/dev/null \
              | sed -n 's/.*program interpreter: \(.*\)\]/\1/p')"
    if [[ -n "$interp" && "$interp" != "$PREFIX"/* ]]; then
        echo "    $rel: PT_INTERP is $interp (expected under $PREFIX)"
        leaks=$((leaks+1))
    fi

    # EVERY ELF, including the ones with an interpreter.
    #
    # This check used to skip them, reasoning that a program whose PT_INTERP
    # is the reserved prefix cannot start, so its RPATH cannot be followed.
    # elfpatch rewrites PT_INTERP at install time; they start. And it edits
    # this RPATH rather than recomputing one, so a stale entry decides which
    # payload they bind to. Skipping them is what let a payload through that
    # xlings then refused to install:
    #   loader/libc payload mismatch in 16 binary(ies)
    # The strip above is the fix; this is the assertion that it happened.
    rpath="$(readelf -dW "$elf" 2>/dev/null \
             | sed -n 's/.*\(RPATH\|RUNPATH\).*\[\(.*\)\]/\2/p')"
    if [[ -n "$rpath" && "$rpath" == *"$HOME"* ]]; then
        echo "    $rel: RPATH/RUNPATH names this machine: $rpath"
        leaks=$((leaks+1))
    fi
done

# glibc's `make install` runs ldconfig, so DESTDIR ends up with a cache keyed
# to $PREFIX -- a path that exists nowhere. The loader then consults a file it
# cannot open on every single lookup, and every report about it ("the private
# cache is stale") is about a file that was never read.
#
# We resolve through DT_RPATH, so there is nothing for a cache to add. Drop it
# rather than ship a decoy, and keep the check so a future layout change cannot
# put one back unnoticed.
rm -f "$PAYLOAD/etc/ld.so.cache"
if [[ -e "$PAYLOAD/etc/ld.so.cache" ]]; then
    echo "    payload carries an etc/ld.so.cache; we do not use ldconfig"
    leaks=$((leaks+1))
fi

# And libc has to load under it, which is the pairing that actually gets used.
if [[ -n "$LOADER" && -f "$PAYLOAD/lib/libc.so.6" ]]; then
    if ! "$LOADER" --library-path "$PAYLOAD/lib" "$PAYLOAD/lib/libc.so.6" \
            >/dev/null 2>&1; then
        echo "    libc.so.6 does not run under the built loader"
        leaks=$((leaks+1))
    fi
fi

# The loader's own directory is its default library directory
# (glibc-$UPSTREAM-default-dir-follows-loader.patch, xlings#605) -- checked as
# BEHAVIOUR, because the prefix string above is still in the loader either way.
#
# Both ways the loader finds its own name, since the patch takes a different
# branch for each:
#   * PT_INTERP: a program with NO RPATH at all must start, so libc.so.6 came
#     from the loader's directory, and its RUNPATH names nothing real, so a
#     glibc library it NEEDs can only have come from there too
#   * direct invocation (`ld.so --list`, what ldd runs): /proc/self/exe
# And the other half: a library only the HOST has stays unreachable. Without
# that, a patch that re-enabled the host's directories would pass.
if [[ -n "$LOADER" ]]; then
    PROBE="$WORK/default-dir-probe"; rm -rf "$PROBE"; mkdir -p "$PROBE"
    printf 'int main(void){return 0;}\n' > "$PROBE/main.c"
    if "$CC" "$PROBE/main.c" -o "$PROBE/main" >/dev/null 2>&1 \
       && patchelf --set-interpreter "$LOADER" --remove-rpath "$PROBE/main" \
       && patchelf --add-needed libresolv.so.2 --set-rpath /nonexistent-probe "$PROBE/main"; then
        if "$PROBE/main"; then
            log "  default dir: a RUNPATH-only program on this loader finds libc and libresolv"
        else
            echo "    a program with no usable search path does not start on this loader;"
            echo "    its own directory is not a default directory"
            "$PROBE/main" 2>&1 | head -2 | sed 's/^/      /'
            leaks=$((leaks+1))
        fi
        listed="$("$LOADER" --list "$PROBE/main" 2>&1)"
        if ! grep -q "libresolv.so.2 => $(dirname "$(readlink -f "$LOADER")")/libresolv.so.2" <<<"$listed"; then
            echo "    ld.so --list does not resolve libresolv.so.2 from the loader's directory:"
            sed 's/^/      /' <<<"$listed"
            leaks=$((leaks+1))
        fi
        host_only="$(ldconfig -p 2>/dev/null | awk '/libz\.so\.1 /{print $1; exit}')"
        if [[ -n "$host_only" && ! -e "$PAYLOAD/lib/$host_only" ]]; then
            patchelf --add-needed "$host_only" "$PROBE/main"
            if "$PROBE/main" 2>/dev/null; then
                echo "    $host_only, which only the host has, resolved under this loader"
                leaks=$((leaks+1))
            else
                log "  host-only $host_only stays unreachable"
            fi
        fi
    else
        echo "    could not build the default-directory probe"
        leaks=$((leaks+1))
    fi
fi

# Every compiled-in path carries the WHOLE padded prefix.
#
# The recipe relocates the padded string and then refuses a payload in which
# the reserved prefix survives, so a path that reached the payload in its
# 48-byte form -- a directory configured apart from --prefix, a string built
# from a truncated copy -- would fail the install on a user's machine. Found
# here instead, per file: every occurrence of the reserved prefix has to be
# the start of the padded one. A string that holds the prefix several times
# (a colon-separated search list) counts each.
while IFS= read -r -d '' f; do
    n_reserved="$(grep -oaF "$RESERVED_PREFIX" "$f" | wc -l)"
    n_padded="$(grep -oaF "$PREFIX" "$f" | wc -l)"
    if (( n_reserved != n_padded )); then
        echo "    ${f#"$PAYLOAD"/}: $((n_reserved - n_padded)) occurrence(s) of the reserved prefix without the padding"
        leaks=$((leaks+1))
    fi
done < <(grep -rlaFZ "$RESERVED_PREFIX" "$PAYLOAD")

# The locale and conversion data the recipe makes reachable, checked here
# before relocation: C.utf8 compiled by the payload's own localedef from
# its own sources and loaded by its own libc (LOCPATH stands in for the
# relocated lib/locale), and one conversion through its own gconv modules
# (GCONV_PATH stands in for lib/gconv). A failure here is a defect of the
# payload, not of the relocation, and it is cheaper to find before publishing.
# localedef exits 1 when it wrote the locale with warnings, so the verdict is
# the file it produced, not its status. It runs with an empty PATH, so a pass
# also shows that it needed no host tool (the uncompressed charmap above).
if [[ -n "$LOADER" ]]; then
    LPROBE="$WORK/locale-probe"; rm -rf "$LPROBE"; mkdir -p "$LPROBE"
    env PATH=/nonexistent I18NPATH="$PAYLOAD/share/i18n" \
        "$LOADER" --library-path "$PAYLOAD/lib" \
        "$PAYLOAD/bin/localedef" --no-archive -i C -f UTF-8 "$LPROBE/C.utf8" \
        > "$LPROBE/localedef.log" 2>&1
    if [[ -f "$LPROBE/C.utf8/LC_CTYPE" ]]; then
        mkdir -p "$PAYLOAD/lib/locale"
        cp -a "$LPROBE/C.utf8" "$PAYLOAD/lib/locale/" || fail "compiled C.utf8 staging"
        charmap="$(LOCPATH="$LPROBE" LC_ALL=C.UTF-8 "$LOADER" --library-path "$PAYLOAD/lib" \
                   "$PAYLOAD/bin/locale" charmap 2>&1)"
        if [[ "$charmap" == "UTF-8" ]]; then
            log "  C.utf8: compiled by the payload's localedef, loaded by its libc"
        else
            echo "    C.utf8 was compiled but does not load under this libc: $charmap"
            leaks=$((leaks+1))
        fi
    else
        echo "    the payload's localedef did not produce C.utf8:"
        tail -5 "$LPROBE/localedef.log" | sed 's/^/      /'
        leaks=$((leaks+1))
    fi
    # U+4E2D is D6 D0 in GBK.
    gbk="$(printf '\xe4\xb8\xad' | GCONV_PATH="$PAYLOAD/lib/gconv" \
           "$LOADER" --library-path "$PAYLOAD/lib" "$PAYLOAD/bin/iconv" -f UTF-8 -t GBK \
           2>/dev/null | od -An -tx1 | tr -d ' \n')"
    if [[ "$gbk" == "d6d0" ]]; then
        log "  gconv: UTF-8 -> GBK through the payload's own modules"
    else
        echo "    UTF-8 -> GBK through the payload's gconv modules gave '$gbk', expected d6d0"
        leaks=$((leaks+1))
    fi
fi

# Assert default timezone/locale/gconv paths after the same binary-prefix relocation the recipe
# applies. The raw published payload is untouched; only these private copies
# name the probe directory. No data-path override can mask a broken default.
TPROBE="$WORK/runtime-data-probe"
rm -rf "$TPROBE"; mkdir -p "$TPROBE/lib"
cp -L "$LOADER" "$TPROBE/lib/$LOADER_NAME"
cp -L "$PAYLOAD/lib/libc.so.6" "$TPROBE/lib/libc.so.6"
ln -s "$PAYLOAD/share" "$TPROBE/share"
ln -s "$PAYLOAD/lib/locale" "$TPROBE/lib/locale"
ln -s "$PAYLOAD/lib/gconv" "$TPROBE/lib/gconv"
# dlopen resolves only managed glibc modules through this private loader.
for so in "$PAYLOAD"/lib/*.so*; do
    [[ -f "$so" ]] || continue
    name="$(basename "$so")"
    [[ -e "$TPROBE/lib/$name" ]] || ln -s "$so" "$TPROBE/lib/$name"
done
python3 - "$PREFIX" "$TPROBE" "$TPROBE/lib/$LOADER_NAME" "$TPROBE/lib/libc.so.6" <<'PY' || fail "runtime data probe relocation"
import pathlib, sys
placeholder = sys.argv[1].encode()
root = sys.argv[2].encode()
if len(root) > len(placeholder):
    raise SystemExit("runtime data probe root exceeds the reserved prefix")
replacement = root + b"/" * (len(placeholder) - len(root))
for filename in sys.argv[3:]:
    file = pathlib.Path(filename)
    before = file.read_bytes()
    after = before.replace(placeholder, replacement)
    assert len(before) == len(after)
    file.write_bytes(after)
PY
cat > "$TPROBE/main.c" <<'C'
#define _DEFAULT_SOURCE
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <locale.h>
#include <langinfo.h>
#include <wchar.h>
#include <iconv.h>
#include <string.h>
#include <netdb.h>
#include <pwd.h>
#include <unistd.h>
int main(void) {
    const char *zones[] = {"Asia/Tokyo", "Etc/UTC"};
    const long offsets[] = {32400, 0};
    time_t epoch = 0;
    for (int i = 0; i < 2; ++i) {
        struct tm value;
        if (setenv("TZ", zones[i], 1)) return 1;
        tzset();
        if (!localtime_r(&epoch, &value) || value.tm_gmtoff != offsets[i]) return 2;
        printf("%s %ld\n", zones[i], value.tm_gmtoff);
    }
    if (!setlocale(LC_ALL, "C.UTF-8") || strcmp(nl_langinfo(CODESET), "UTF-8")) return 3;
    const char utf8[] = "\xe4\xb8\xad";
    wchar_t wc;
    mbstate_t state = {0};
    if (mbrtowc(&wc, utf8, 3, &state) != 3 || wc != 0x4e2d) return 4;
    iconv_t cd = iconv_open("GBK", "UTF-8");
    if (cd == (iconv_t)-1) return 5;
    char *input = (char *)utf8, output[8] = {0}, *out = output;
    size_t remaining = 3, capacity = sizeof(output);
    if (iconv(cd, &input, &remaining, &out, &capacity) == (size_t)-1 || remaining ||
        out - output != 2 || (unsigned char)output[0] != 0xd6 ||
        (unsigned char)output[1] != 0xd0) return 6;
    iconv_close(cd);
    puts("C.UTF-8 and managed GBK conversion PASS");
    /* NSS intentionally consumes host identity/network configuration. Its
       implementations remain those of this managed glibc. No host modules
       or locale data are supplied to this process. */
    struct addrinfo hints = {0}, *addresses = NULL;
    hints.ai_socktype = SOCK_STREAM;
    if (getaddrinfo("localhost", NULL, &hints, &addresses) || !addresses) return 7;
    freeaddrinfo(addresses);
    struct passwd value, *user = NULL;
    char buffer[16384];
    if (getpwuid_r(getuid(), &value, buffer, sizeof(buffer), &user) || !user ||
        user->pw_uid != getuid() || !user->pw_name || !*user->pw_name) return 8;
    printf("NSS localhost and getpwuid_r(%lu) PASS; host configuration policy\n",
           (unsigned long)getuid());
    return 0;
}
C
"$CC" "$TPROBE/main.c" -o "$TPROBE/main" || fail "runtime data probe compile"
patchelf --remove-rpath "$TPROBE/main" || fail "runtime data probe rpath"
patchelf --set-interpreter "$TPROBE/lib/$LOADER_NAME" "$TPROBE/main" || fail "runtime data probe interpreter"
env -u TZDIR -u LD_LIBRARY_PATH -u LD_PRELOAD -u LOCPATH -u GCONV_PATH \
    "$TPROBE/main" || fail "default managed runtime data / host NSS policy"
log "  default managed data: Tokyo/UTC, C.UTF-8, GBK; NSS uses explicit host configuration policy"
printf 'Runtime data policy: managed TZDIR, locale and gconv defaults; host NSS configuration/identity/network data, managed implementations only.\n' >> "$PAYLOAD/PROVENANCE.txt"

(( leaks == 0 )) || fail "$leaks problem(s) — payload not packaged"

: > "$PAYLOAD/ELF-MANIFEST.txt"
while IFS= read -r -d '' elf; do
    [[ "$(head -c 4 "$elf")" == $'\x7fELF' ]] || continue
    machine="Advanced Micro Devices X86-64"
    [[ "$BUILD_ARCH" != aarch64 ]] || machine=AArch64
    readelf -h "$elf" | grep -q "Machine:.*$machine" || fail "foreign ELF: $elf"
    {
        printf '\nFile: %s\n' "${elf#"$PAYLOAD/"}"
        sha256sum "$elf"
        readelf -h -l -d -V "$elf"
    } >> "$PAYLOAD/ELF-MANIFEST.txt"
done < <(find "$PAYLOAD" -type f -print0)

# Reproducible packaging, the form build-in-subos.sh uses and states the
# reason for: member order, owner and mtime fixed, and no gzip timestamp.
TAR="$DIST/$STEM.tar.gz"
rm -f "$TAR"
tar --sort=name \
    --owner=0 --group=0 --numeric-owner \
    --mtime="@${SOURCE_DATE_EPOCH:-0}" \
    --format=gnu \
    -cf - -C "$(dirname "$PAYLOAD")" "$STEM" \
  | gzip -n -9 > "$TAR" || fail "tar"
log "packaged $(basename "$TAR") ($(du -h "$TAR" | cut -f1))"
log "sha256 $(sha256sum "$TAR" | cut -d' ' -f1)"

(cd "$DIST" && sha256sum "$STEM.tar.gz" > "$STEM.tar.gz.sha256")
