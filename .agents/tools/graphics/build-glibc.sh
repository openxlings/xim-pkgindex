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
#         build-glibc.sh <version>r<rev>     (e.g. build-glibc.sh 2.44r1)
#
# THE `r<rev>` FORM, AND WHY REBUILDING 2.44 AS "2.44" IS NOT AN OPTION
#
# When a payload is rebuilt for a reason that is ours rather than upstream's --
# a patch, a prefix, a packaging fix -- the bytes change while the glibc
# version does not. Publishing those bytes as "2.44" again gives one name to
# two artifacts, and it breaks the party that did nothing wrong: a client
# holding a cached index still has the OLD sha256, downloads the NEW asset,
# and fails the integrity check. It also leaves everyone already on 2.44 with
# nothing that distinguishes the fixed copy.
#
# `r` and not `-`: publish.sh recovers the version from the tarball name with
# `${stem##*-}`, which returns only the trailing field of a dashed version.
#
# `r` and not `+`, which was the first choice because `["25.0.4+7"]` is
# already an index key: look at what jdk-temurin has to do to USE it. The
# GLOBAL url spells that version `jdk-25.0.4%2B7` and the CN mirror gives up
# and calls it `25.0.4_7`. A `+` in a version means the key, the git tag, the
# asset name and two urls stop being the same string, and every one of those
# is a place to get it wrong once. `r1` is the same string in all five.
set -uo pipefail

VERSION="${1:?usage: build-glibc.sh <version>[r<rev>]}"
UPSTREAM="${VERSION%%[!0-9.]*}"   # what to fetch and configure; glibc's own
                                  # versions are digits and dots, so the first
                                  # character outside that set starts our part
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
# 3, not 1: nothing was built because there was nowhere to build it. See the
# exit-code contract in .agents/tools/README.md.
skip() { echo "[gfx-build:$NAME] SKIP: $*" >&2; exit 3; }

[[ -d "$SUBOS" ]] || skip "subos '$SUBOS_NAME' not found — xlings subos new $SUBOS_NAME"
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

TARBALL="$SRC/glibc-$UPSTREAM.tar.xz"
[[ -f "$TARBALL" ]] || {
    log "fetching glibc-$UPSTREAM.tar.xz"
    curl -fsSL --retry 3 -o "$TARBALL" \
        "https://ftp.gnu.org/gnu/glibc/glibc-$UPSTREAM.tar.xz" || fail "download"
}
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
log "configuring $UPSTREAM (prefix=$PREFIX)"
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
        *"$UPSTREAM"*) log "  loader reports: $got" ;;
        *) echo "    loader reports '$got', expected $UPSTREAM"; leaks=$((leaks+1)) ;;
    esac
fi

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

    # RPATH is only checked on objects a loader can actually act on.
    #
    # The subos gcc links `bin/*` and `sbin/*` with an RPATH into the BUILD
    # machine's glibc and gcc payloads. That is a builder-disk path in a
    # published artifact and it looks alarming, but it can never be followed:
    # those same programs have PT_INTERP under the reserved prefix (asserted
    # just above), so execve fails with ENOENT before any RPATH is consulted.
    # Failing the build on it would be asserting a property of a code path
    # that AD-11 deliberately made unreachable.
    #
    # A shared library is different: it is loaded BY something else, its
    # PT_INTERP is not consulted, and its RPATH is. So that is where the
    # question has an answer that matters.
    [[ -n "$interp" ]] && continue
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

(( leaks == 0 )) || fail "$leaks problem(s) — payload not packaged"

TAR="$DIST/$NAME-$VERSION-linux-x86_64.tar.gz"
rm -f "$TAR"
tar czf "$TAR" -C "$(dirname "$PAYLOAD")" "$(basename "$PAYLOAD")" || fail "tar"
log "packaged $(basename "$TAR") ($(du -h "$TAR" | cut -f1))"
log "sha256 $(sha256sum "$TAR" | cut -d' ' -f1)"
