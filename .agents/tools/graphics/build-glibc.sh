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
ARCH="${XLINGS_GFX_ARCH:-$(uname -m)}"
case "$ARCH" in
    x86_64|aarch64) ;;
    arm64) ARCH=aarch64 ;;
    *) echo "[gfx-build:glibc] unsupported architecture: $ARCH" >&2; exit 2 ;;
esac
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
#   * a managed payload uses its own etc/cache; a logical root uses /etc
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
export CC="${XLINGS_GFX_CC:-$SUBOS/bin/gcc}" CXX="${XLINGS_GFX_CXX:-$SUBOS/bin/g++}"
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
# --without-selinux: configure probes libselinux by LINKING, which finds the
#   host's library, while the subos compiler cannot see the host's headers --
#   so a host with libselinux fails in nss/makedb.c, and one where both are
#   visible links a host library into the payload. 2.44.2 was built without it
#   (its makedb NEEDs libc.so.6 only); this makes that a decision, not a host
#   accident.
../configure \
    --prefix="$PREFIX" \
    --libdir="$PREFIX/lib" \
    --with-headers="$SUBOS/usr/include" \
    --enable-kernel=4.19 \
    --disable-werror \
    --disable-profile \
    --disable-nscd \
    --enable-stack-protector=strong \
    --without-selinux \
    > "$WORK/$NAME-configure.log" 2>&1 \
    || { tail -30 "$WORK/$NAME-configure.log"; fail "configure"; }

log "building (this takes a while)"
make -j"${XLINGS_GFX_JOBS:-$(nproc)}" > "$WORK/$NAME-build.log" 2>&1 \
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
STEM="$NAME-$ASSET_VERSION-linux-$ARCH"
PAYLOAD="$WORK/payload/$STEM"
rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD"
cp -a "$STAGE$PREFIX/." "$PAYLOAD/" || fail "payload copy"

# lib64 beside lib, because that is where the recipe and every elfpatched
# consumer look for the loader (`exports.runtime.loader = lib64/ld-linux-...`).
if [[ ! -d "$PAYLOAD/lib64" ]]; then
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
    # The compiled fallback must retain the private prefix. The logical-root
    # suffix is also /etc/ld.so.preload; string pooling differs by architecture,
    # so its presence alone cannot identify the path the loader will open.
    # check-glibc-root-cache.sh proves both runtime choices below.
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
# without the relocation: C.utf8 compiled by the payload's own localedef from
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

XLINGS_GFX_CC="$CC" bash "$PATCHDIR/../check-glibc-root-cache.sh" "$PAYLOAD" \
    || fail "logical-root cache / preload boundary"

(( leaks == 0 )) || fail "$leaks problem(s) — payload not packaged"

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
