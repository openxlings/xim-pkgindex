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
# Usage:  build-glibc.sh <upstream> [<package-version>]
#           build-glibc.sh 2.44              -> glibc-2.44-linux-x86_64.tar.gz
#           build-glibc.sh 2.44 2.44.1       -> glibc-2.44.1-linux-x86_64.tar.gz
#
# TWO ARGUMENTS, AND WHY THE PACKAGE VERSION HAS TO SORT ABOVE THE ONE IT
# REPLACES
#
# When a payload is rebuilt for a reason that is ours rather than upstream's --
# a patch, a prefix, a packaging fix -- the bytes change while the glibc
# version does not. Publishing those bytes as "2.44" again gives one name to
# two artifacts, and it breaks the party that did nothing wrong: a client
# holding a cached index still has the OLD sha256, downloads the NEW asset,
# and fails the integrity check. It also leaves everyone already on 2.44 with
# nothing that distinguishes the fixed copy. So the package gets its own
# version, and the upstream one it was built from is a separate argument.
#
# WHICH version is not a matter of taste. Recipes depend on this package as
# `xim:glibc@>=2.38` (libllvm, glslang, elfutils, graphite2, ...), and
# `select_version_` answers a range with `semver::select_best`, which returns
# the MAXIMUM satisfying version -- not the one `latest` points at. So a
# revision that sorts BELOW the artifact it supersedes is not merely untidy;
# every ranged dependency resolves straight back to the copy being replaced.
#
# The first attempt here was `2.44r1`, and it has exactly that defect.
# xlings' semver splits a field at digit/alpha boundaries and reads a missing
# segment as numeric 0, so an alpha segment loses to it: their own pinned
# corpus asserts `compare("6.5", "6.5rc1") > 0`. `2.44r1` is therefore a
# PRE-release of 2.44 as far as every range expression is concerned.
#
# `2.44.1` sorts above `2.44` by the same rule read the other way (1 > the
# missing 0). It is also the same string in the index key, the git tag, the
# asset name and both urls -- unlike `+1`, where jdk-temurin's `["25.0.4+7"]`
# needs `%2B` in the GLOBAL url and a rename to `25.0.4_7` on the CN mirror --
# and unlike `-1`, which publish.sh's `${stem##*-}` would truncate.
#
# It does collide with a hypothetical upstream glibc 2.44.1. Upstream has not
# shipped a three-component release in this series; if it ever does, take the
# next free revision rather than reusing this shape.
set -uo pipefail

UPSTREAM="${1:?usage: build-glibc.sh <upstream> [<package-version>]}"
VERSION="${2:-$UPSTREAM}"   # what the artifact is called and published as
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

(( leaks == 0 )) || fail "$leaks problem(s) — payload not packaged"

TAR="$DIST/$NAME-$VERSION-linux-x86_64.tar.gz"
rm -f "$TAR"
tar czf "$TAR" -C "$(dirname "$PAYLOAD")" "$(basename "$PAYLOAD")" || fail "tar"
log "packaged $(basename "$TAR") ($(du -h "$TAR" | cut -f1))"
log "sha256 $(sha256sum "$TAR" | cut -d' ' -f1)"
