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
#   * no RPATH/RUNPATH naming a host path
#   * no absolute host path baked into a .pc, .la or config script
#
# and, since 2026-08-08, the other half of the same question:
#
#   * nothing the build was CONFIGURED against came from the host either
#
# That last one is not a refinement of the first two, it is the gap they left.
# See "the check on the INPUTS" below for the two shipped packages that walked
# straight through the payload check.
#
# KNOWN GAP. This list used to open with "no DT_NEEDED that resolves outside
# the subos or the package itself". No such check has ever existed in this file
# — grep it. It is the one that would catch an autotools package that picked up
# a host library through a bare `-lfoo`: no absolute path for the input check
# to see, and a bare SONAME for the payload check to shrug at. Recorded here
# rather than quietly deleted, because it is the complement of the input check
# and not a duplicate of it.
#
# That check is the reason this script exists rather than a README saying
# "build it in the subos". A leaked host path does not fail the build; it fails
# months later on someone else's machine.
#
# Exit codes (the contract in .agents/tools/README.md):
#   0  proven — built, and neither its inputs nor its payload reach the host
#   1  broken — a host reference, in the inputs or in the payload
#   2  inconclusive — could not read what the build linked against
#   3  could not be exercised here — a precondition this machine does not meet
#
# Usage:
#   build-in-subos.sh --name libXau --version 1.0.11 \
#       --url https://.../libXau-1.0.11.tar.xz \
#       [--system autotools|meson|cmake] [--deps 'xorgproto libX11'] \
#       [-- <extra configure/meson args>]
#
#   build-in-subos.sh --check-inputs <builddir>      # just the input check
set -uo pipefail

NAME= VERSION= URL= SYSTEM=auto DEPS= EXTRA=() CHECK_INPUTS=
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)    NAME="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --url)     URL="$2"; shift 2 ;;
        --system)  SYSTEM="$2"; shift 2 ;;
        --deps)    DEPS="$2"; shift 2 ;;
        # Run the input check alone, against a build tree that already exists.
        #
        # A check that can only be exercised by rerunning a two-hour mesa build
        # is a check nobody reruns, and both builds that motivated it are
        # already sitting in $XLINGS_GFX_WORK/src. Being able to point it at
        # one of those is what makes its verdict evidence rather than a claim.
        --check-inputs) CHECK_INPUTS="$2"; NAME="${NAME:-inputs}"; shift 2 ;;
        --)        shift; EXTRA=("$@"); break ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$CHECK_INPUTS" || ( -n "$NAME" && -n "$VERSION" && -n "$URL" ) ]] || {
    echo "usage: $0 --name N --version V --url U [--system auto|autotools|meson|cmake] [--deps '...'] [-- args]" >&2
    echo "       $0 --check-inputs <builddir>" >&2
    exit 2
}

# This script's own directory, for `patches/` below.
#
# Resolved from BASH_SOURCE rather than $0 so it is correct when the script is
# sourced or invoked through a symlink. Worth stating because the first version of
# the patch hook referenced an undefined $HERE, which expanded to `/patches` --
# a directory that does not exist, so the glob matched nothing, no patch applied,
# and the build failed with the exact error the patch removes. A missing patch is
# invisible; that is why this line is here and not inlined.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxbuild}"
XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS="$XHOME/subos/$SUBOS_NAME"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"
STAGE="$WORK/stage/$NAME-$VERSION"
SRC="$WORK/src"

log()  { echo "[gfx-build:$NAME] $*"; }
fail() { echo "[gfx-build:$NAME] FAIL: $*" >&2; exit 1; }
# 2 and 3 are not decoration. `fail` says the package is broken; these two say
# the check did not get to run, which is a different thing to act on, and
# neither of them is 0.
inconclusive() { echo "[gfx-build:$NAME] INCONCLUSIVE: $*" >&2; exit 2; }
skip()         { echo "[gfx-build:$NAME] SKIP: $*" >&2; exit 3; }

# ══ the check on the INPUTS ═════════════════════════════════════════════
#
# Everything else in this script inspects the PAYLOAD. That is necessary and it
# is not sufficient, and two shipped packages are the proof:
#
#   * mesa 25.0.7.1 cannot have been built against the index's `llvm` package.
#     That package ships bin/llvm-config and none of the ~40 component .a files
#     and no LLVM API headers, so neither of meson's two detection methods can
#     succeed against it. The published mesa was built against the HOST's LLVM.
#     The payload check reported "no host references" — correctly, on its own
#     terms: a static .a leaves no DT_NEEDED at all, and a shared libLLVM
#     leaves a bare SONAME with no path in it.
#
#   * building LLVM here on 2026-08-07, cmake resolved zstd to the host's
#     /usr/lib/x86_64-linux-gnu/libzstd.so. There is no zstd package in this
#     home at all. Nothing in the build said so; a runtime failure on another
#     machine did.
#
# Both builds were configured against something that will not exist on the
# user's machine, and the files they produced said nothing about it. So this
# asks the other half of the question: what went IN.
#
# ── why this reads logs instead of sealing the container ────────────────
#
# The check you would rather have is the one selfcontained-check.sh uses for
# runtime: run the build inside bwrap with no /usr bound, so the host cannot be
# consumed because it is not there. Measured on this machine 2026-08-08, that
# cannot work for a BUILD, for two independent reasons:
#
#   * the subos carries no POSIX userland. sh, sed, grep, awk, m4, install, ln,
#     mkdir, cp, env, make, pkg-config — every one of those resolves to /usr on
#     a gfxbuild subos with the full graphics stack installed. `./configure` is
#     a /bin/sh script and `<subos>/bin/meson` begins `#!/bin/sh`; with /usr
#     gone, neither can start.
#
#   * the subos's own toolchain entries are xlings shims that dispatch through
#     xvm, and dispatching needs the host. Measured, with $XLINGS_HOME bound
#     and `<subos>/bin/gcc --version` as the whole command:
#
#         /usr + /bin + /lib64 present  → rc 0, prints the version
#         any subset of those           → rc 127, nothing on stdout or stderr
#
#     The real gcc under data/xpkgs/ runs sealed perfectly well. It is the shim
#     layer that does not, so a sealed build cannot reach `gcc --version`.
#
# A sealed build would therefore not measure host leakage, it would measure
# whether bwrap started — and it would fail identically for a clean package and
# a dirty one, which is the exact failure mode this whole file exists to avoid.
# Reading what the build wrote down is weaker: it can only see inputs the build
# recorded. But what it does see is real.
#
# ── probed-and-rejected vs resolved-and-used ────────────────────────────
#
# The reason this is a parser and not a grep for "/usr". mesa's meson-log.txt
# is 4711 lines and 841 of them contain "/usr"; flag those and the check is
# commented out inside a week. Three separate things produce that noise, and
# each needs its own rule:
#
#   1. the subos's own paths END in /usr — `<subos>/usr/lib/pkgconfig`. So a
#      path only counts when it starts at the filesystem root. That alone takes
#      mesa from 841 to 328.
#
#   2. of those 328: /usr/bin/pkg-config (321), /usr/bin/bison, /usr/bin/flex,
#      /usr/bin/ln — host PROGRAMS the build ran. A clean autotools config.log
#      is the same story: xz's resolved-variables section holds 12 /usr paths
#      and all 12 are grep, sed, msgfmt, install, mkdir. Programs generate
#      source and do not end up in the result.
#
#   3. and /usr/lib/gbm, /usr/lib/dri, /usr/lib/libvulkan_radeon.so — mesa's
#      own INSTALL destinations, because --prefix is /usr. Under this script
#      every install path looks exactly like a host path.
#
#   So the rule is not "a /usr path appears" but "a path was handed to the
#   compiler as a search path, or to the linker as a file": -I, -isystem,
#   -iquote, -idirafter, -L, and absolute *.so/*.a arguments. Neither a program
#   nor an install destination ever takes that shape. Library FILES get one
#   extra test — the file must exist — because that is what separates
#   /usr/lib/libvulkan_radeon.so, where mesa will install, from
#   /usr/lib/x86_64-linux-gnu/libzstd.so, which cmake actually linked.
#
#   The records themselves are filtered before any of that: meson logs every
#   subprocess with its exit status, and a `-> 1` block is a dependency it
#   probed and was told no; cmake writes *-NOTFOUND for the same thing, and
#   LLVM's cache here has ZLIB_LIBRARY_DEBUG:FILEPATH=ZLIB_LIBRARY_DEBUG-NOTFOUND
#   sitting two lines from a real one.
#
#   Be honest about the meson half of that, though: measured against mesa's
#   log, dropping the `-> 1` blocks changes the verdict not at all. 4711 lines
#   become 541; the 105 lines of rejected blocks contain no -I or -L path that
#   is not also in an accepted one, and the only root-/usr path in them is
#   /usr/bin/pkg-config, which the shape rule already ignores. The filter is
#   kept because a rejected `llvm-config --libs` or `pkg-config --cflags` can
#   still print a -L before failing, and because reading a rejected probe as an
#   input is the kind of wrong answer that gets a check deleted. It is not
#   carrying the noise reduction — rules 1 to 3 above are.
#
#   CMakeFiles/CMakeError.log is deliberately NOT read. It is by definition the
#   record of probes that failed, so every path in it is one the build did not
#   use; parsing it would manufacture the noise the rest of this is avoiding.
#
# ── an allowlist of ours, not a denylist of theirs ──────────────────────
#
# "/usr, /lib, /lib64" is one distro wide. The mesa tree in this work dir right
# now resolves LLVM to
#     -I/tmp/.../scratchpad/llvmsrc/out/include
#     -L/tmp/.../scratchpad/llvmsrc/out/lib
# a scratch build tree that is neither /usr nor XLINGS_HOME and that ships
# every bit as badly — that is the mesa/LLVM instance above, caught in the act.
# /opt/rocm, /nix/store and ~/.local are the same shape. So the test is the
# other way round: a resolved input is inside XLINGS_HOME, or inside this
# script's own work tree, or it is a leak.

# -I/-L/-isystem/-iquote/-idirafter search paths, absolute only.
_gfx_search_paths() {   # <record-stream-file>
    { grep -oE -- '-(I|L)/[-A-Za-z0-9_.+@%~/]*'                 "$1"
      grep -oE -- '-i(system|quote|dirafter)[ =]*/[-A-Za-z0-9_.+@%~/]*' "$1"
    } 2>/dev/null | sed -E 's/^-(I|L|i(system|quote|dirafter)[ =]*)//' | sort -u
}
# Absolute library files named on a command line. The leading class keeps this
# from matching the tail of a longer path (a subos path ends in .so too).
_gfx_lib_files() {      # <record-stream-file>
    grep -oE -- '(^|[^-A-Za-z0-9_.+@%~/])/[-A-Za-z0-9_.+@%~/]*\.(so|a)(\.[0-9]+)*' "$1" \
        2>/dev/null | sed -E 's#^[^/]*##' | sort -u
}

check_build_inputs() {   # <builddir> → 0 clean, 1 host input, 2 no record read
    local bd="$1" tmpd real f p line n=0 leaks=0
    tmpd="$(mktemp -d "${TMPDIR:-/tmp}/gfx-inputs.XXXXXX")" || {
        echo "[gfx-build:$NAME] INCONCLUSIVE: cannot create a temp dir" >&2; return 2; }

    # Ours: XLINGS_HOME covers the subos and data/xpkgs; WORK covers src/,
    # deplib/ (the rpath-patched dependency copies) and pc/ (the rewritten .pc
    # files) — all three are this script's own and none of them ship.
    local -a allow=("$XHOME" "$WORK")
    for real in "$XHOME" "$WORK"; do
        p="$(readlink -f "$real" 2>/dev/null)"
        [[ -n "$p" && "$p" != "$real" ]] && allow+=("$p")
    done

    # ── the records, one filtered stream per source ──
    local -a used=()          # what we actually read, for the pass line
    local -a origin=()        # parallel: which file each stream came from
    local -a mode=()          # parallel: flags | values

    # meson. Every subprocess is logged as
    #     Called: `<argv>` -> <rc>  /  stdout: … / -----------
    # and only rc 0 is a resolution. The argv is kept as well as the output:
    # llvm-config's own -I/-L come back on stdout, but a compiler check that
    # SUCCEEDED with a host include path put it in the argv.
    for f in "$bd/_b/meson-logs/meson-log.txt" "$bd/meson-logs/meson-log.txt"; do
        [[ -f "$f" ]] || continue
        awk '/^Called: `.*` -> [0-9]+$/ { keep = /-> 0$/ }
             keep                       { print }
             /^-+$/                     { keep = 0 }' "$f" > "$tmpd/meson-log"
        used+=("$tmpd/meson-log"); origin+=("$f"); mode+=(flags); break
    done

    # meson and cmake both emit build.ninja, and it is the stronger record:
    # meson-log.txt says what was detected, build.ninja is the command line
    # that will actually run.
    for f in "$bd/_b/build.ninja" "$bd/build.ninja"; do
        [[ -f "$f" ]] || continue
        used+=("$f"); origin+=("$f"); mode+=(flags); break
    done

    # cmake's cache, for the entries that hold a resolved path. -NOTFOUND is
    # cmake's way of saying it looked and did not find, and CMAKE_INSTALL_* is
    # a destination — neither matches the name pattern.
    for f in "$bd/_b/CMakeCache.txt" "$bd/CMakeCache.txt"; do
        [[ -f "$f" ]] || continue
        grep -E '^[A-Za-z_][A-Za-z0-9_]*(_LIBRARY|_LIBRARIES|_LIBRARY_DIR|_LIBRARY_DIRS|_LIBRARY_PATH|_INCLUDE_DIR|_INCLUDE_DIRS|_INCLUDE_PATH)(_[A-Z0-9]+)?:[A-Z]+=' "$f" \
            | grep -vi 'NOTFOUND' | sed -E 's/^[^=]*=//' | tr ';' '\n' > "$tmpd/cmake-cache"
        grep -E '^[A-Za-z_][A-Za-z0-9_]*FLAGS[A-Za-z0-9_]*:[A-Z]+=' "$f" > "$tmpd/cmake-flags"
        used+=("$tmpd/cmake-cache" "$tmpd/cmake-flags")
        origin+=("$f" "$f"); mode+=(values flags); break
    done

    # autotools. The transcript above the cache is every probe, successful or
    # not; the two sections at the end are what configure SETTLED on. Only
    # variables that carry compiler or linker arguments — which is why
    # `oldincludedir='/usr/include'`, an install default no build ever uses,
    # does not come through: it is lowercase and it is not a flags variable.
    if [[ -f "$bd/config.log" ]]; then
        awk '/^## Cache variables/{s=1} /^## confdefs.h/{s=0} s' "$bd/config.log" \
            | grep -E '^[A-Za-z_][A-Za-z0-9_]*(CFLAGS|CPPFLAGS|CXXFLAGS|LDFLAGS|LIBS|INCLUDES)[A-Za-z0-9_]*=' \
            > "$tmpd/config-log"
        used+=("$tmpd/config-log"); origin+=("$bd/config.log"); mode+=(flags)
    fi

    if [[ ${#used[@]} -eq 0 ]]; then
        echo "[gfx-build:$NAME] INCONCLUSIVE: no configure record under $bd" >&2
        echo "    looked for: _b/meson-logs/meson-log.txt, _b/build.ninja," >&2
        echo "                _b/CMakeCache.txt, config.log" >&2
        echo "    the build's inputs are UNCHECKED. That is not a pass." >&2
        rm -rf "$tmpd"; return 2
    fi

    log "checking what the build linked AGAINST"
    local i
    for ((i = 0; i < ${#used[@]}; i++)); do
        local stream="${used[$i]}" src="${origin[$i]}"
        local -a paths=()
        if [[ "${mode[$i]}" == values ]]; then
            # Already one bare path per line.
            mapfile -t paths < <(grep -E '^/' "$stream" | sort -u)
        else
            mapfile -t paths < <(_gfx_search_paths "$stream")
            # A library file only counts if it is on the disk: with --prefix=/usr
            # this build's own install destinations are spelled the same way as
            # a host library, and they do not exist yet.
            while IFS= read -r p; do
                [[ -e "$p" ]] && paths+=("$p")
            done < <(_gfx_lib_files "$stream")
        fi
        for p in "${paths[@]}"; do
            [[ -n "$p" ]] || continue
            n=$((n + 1))
            local ok=1 a
            for a in "${allow[@]}"; do
                [[ -n "$a" && ( "$p" == "$a" || "$p" == "$a"/* ) ]] && { ok=0; break; }
            done
            [[ $ok -eq 0 ]] && continue
            line="$(grep -nF -m1 -- "$p" "$src" 2>/dev/null | cut -d: -f1)"
            echo "    $p"
            echo "        ← ${src#"$bd"/}${line:+:$line}"
            leaks=$((leaks + 1))
        done
    done
    rm -rf "$tmpd"

    # Say what was read and how much was checked, on the way past. A pass that
    # prints only "ok" is indistinguishable from a pass that examined nothing,
    # and this file has already shipped that bug once.
    local names=""
    for ((i = 0; i < ${#origin[@]}; i++)); do names="$names ${origin[$i]#"$bd"/}"; done
    log "  read:$(echo "$names" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

    if [[ $leaks -gt 0 ]]; then
        echo "[gfx-build:$NAME] FAIL: $leaks of $n resolved input path(s) are outside" >&2
        echo "    XLINGS_HOME ($XHOME) and this script's work tree ($WORK)." >&2
        echo "    The build consumed something that will not exist on the user's" >&2
        echo "    machine. The payload can still come out clean — that is how" >&2
        echo "    mesa 25.0.7.1 shipped against the host's LLVM." >&2
        return 1
    fi
    log "  all $n resolved input path(s) are ours"
    return 0
}

# --check-inputs: just that, against a tree already on disk. Before the subos
# and fetch preconditions below, because none of them apply.
if [[ -n "$CHECK_INPUTS" ]]; then
    [[ -d "$CHECK_INPUTS" ]] || skip "no such build directory: $CHECK_INPUTS"
    check_build_inputs "$CHECK_INPUTS"
    exit $?
fi

# A missing subos is not a broken package — it is this machine not being set up
# to answer the question, which is exit 3.
[[ -d "$SUBOS" ]] || skip "subos '$SUBOS_NAME' not found — xlings subos new $SUBOS_NAME"
# And patchelf, before anything relies on it. Every use of it below is
# `patchelf … 2>/dev/null || true`, which is right for a file it cannot rewrite
# and disastrous for a machine that does not have it: the payload check reads
# `patchelf --print-rpath` into an empty string and an empty RPATH is precisely
# what "clean" looks like. Absent tool, silent pass — probe for it instead.
command -v patchelf >/dev/null || skip "no patchelf (xlings install patchelf)"
# STAGE is wiped, not just created: a previous run with a different --libdir
# leaves its own tree here, and `make install DESTDIR=` only adds. The stale
# copy then rides into the payload and ships two layouts of the same library.
rm -rf "$STAGE"
mkdir -p "$SRC" "$STAGE"

# ── fetch ───────────────────────────────────────────────────────────────
# Cached under NAME-VERSION, not under the URL's basename.
#
# Every GitHub archive URL is `.../archive/refs/tags/v<tag>.tar.gz`, so the
# basename carries the tag and nothing about the project. Vulkan-Headers and
# Vulkan-Loader are both released as v1.4.313, so the second build found the
# first one's `v1.4.313.tar.gz` already in $SRC, skipped the download, and
# configured, built, staged, leak-checked and PACKAGED the wrong source --
# producing a `vulkan-loader` payload containing Vulkan-Headers, with every step
# reporting success. It was caught only because the resulting package had no
# lib/ directory.
#
# The basename is kept as a suffix so the file is still recognisable on disk.
TARBALL="$SRC/${NAME}-${VERSION}-$(basename "$URL")"
[[ -f "$TARBALL" ]] || {
    log "fetching $(basename "$URL")"
    curl -fsSL --retry 3 -o "$TARBALL" "$URL" || fail "download failed"
}
BUILDDIR="$SRC/$NAME-$VERSION"
rm -rf "$BUILDDIR"; mkdir -p "$BUILDDIR"
tar xf "$TARBALL" -C "$BUILDDIR" --strip-components=1 || fail "extract failed"

# ── patches, by convention ──────────────────────────────────────────────
#
# `patches/<name>-<version>-*.patch` next to this script, applied in sorted
# order with `patch -p1`. Nothing to declare at the call site: a patch exists
# for a (package, version) pair or it does not.
#
# Needed because upstream releases go stale against a MOVING sysroot. mesa
# 25.0.7 is the last of its series and cannot compile against glibc 2.44: ISO
# C23 moved once_flag/call_once into <stdlib.h>, glibc >= 2.42 followed, and
# mesa's own src/c11 shim redefines both --
#
#   error: conflicting types for 'once_flag'; have 'pthread_once_t' {aka 'int'}
#
# The shipped mesa 25.0.7.1 was built when this sysroot was glibc 2.39, so the
# same source and the same command now fail where they once worked. That is a
# recurring shape here, not a one-off, and it deserves a mechanism rather than a
# hand-edit somebody has to remember.
#
# Applied with --forward and treated as fatal on failure. A patch that no longer
# applies means the source moved under it, and continuing would build something
# nobody described -- the silent-success shape this tree keeps finding.
PATCHDIR="$HERE/patches"
if [[ -d "$PATCHDIR" ]]; then
    shopt -s nullglob
    patches=("$PATCHDIR/$NAME-$VERSION"-*.patch)
    shopt -u nullglob
    if [[ ${#patches[@]} -gt 0 ]]; then
        command -v patch >/dev/null || fail "${#patches[@]} patch(es) apply to $NAME $VERSION but \`patch\` is not available"
        for p in "${patches[@]}"; do
            log "patch: $(basename "$p")"
            ( cd "$BUILDDIR" && patch -p1 --forward --silent < "$p" ) \
                || fail "applying $(basename "$p") -- the source moved under it; re-generate the patch rather than skipping it"
        done
    fi
fi

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

# Libraries that must WIN over the subos farm, by SONAME.
#
# XLINGS_GFX_LDFLAGS_FIRST is prepended, so its -Wl,-rpath entries precede every
# subos path in the resulting RPATH. RPATH is first-wins, and that ordering is the
# whole point of this hook.
#
# The case that forced it: TWO payloads ship `libLLVM.so.20.1` with the same
# SONAME and different contents.
#
#   libllvm 20.1.7    X86;AMDGPU          LLVMInitializeSPIRVTarget: 0 symbols
#   llvm-dev 20.1.7.1 X86;AMDGPU;SPIRV    LLVMInitializeSPIRVTarget: 3 symbols
#
# mesa links `mesa_clc` against llvm-dev (llvm-config's libdir) but the subos farm
# carries libllvm's copy, and it came FIRST in the RPATH. So mesa_clc linked
# against one library and loaded the other:
#
#   ldd mesa_clc -> libLLVM.so.20.1 => <subos>/lib/libLLVM.so.20.1
#   mesa_clc: symbol lookup error: undefined symbol: LLVMInitializeSPIRVTarget,
#             version LLVM_20.1
#
# 1348 targets in, with an error naming a symbol rather than a library, and
# nothing in the link step warned -- both files satisfy the same SONAME, so the
# linker had no reason to object. Same shape as the runtime `one question, many
# answerers` cases: two things answer, and only order decides.
#
# Deliberately not fixed by putting SPIRV into libllvm. That library is what every
# user loads; SPIRV is needed only by a build tool, and widening the runtime
# payload to serve the build would be paying every install for it.
if [[ -n "${XLINGS_GFX_LDFLAGS_FIRST:-}" ]]; then
    LDFLAGS="$XLINGS_GFX_LDFLAGS_FIRST $LDFLAGS"
    export LDFLAGS
    log "ldflags (first): $XLINGS_GFX_LDFLAGS_FIRST"
fi
export CC="$SUBOS/bin/gcc"
export CXX="$SUBOS/bin/g++"
[[ -x "$CC" ]] || skip "no gcc in the subos — xlings install gcc"

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
        skip "--deps $dep: not installed in $XHOME (xlings install $dep)"
    fi
    log "  dep $dep -> ${depdir#"$XHOME"/data/xpkgs/}"

    # A dep's bin/ goes on PATH, because some deps are BUILD TOOLS.
    #
    # mesa wants `glslangValidator` (meson.build:648) to compile its Vulkan
    # drivers' built-in shaders. The glslang payload ships bin/glslangValidator,
    # bin/glslang and bin/spirv-remap -- but its recipe registers only a release
    # anchor, so the single shim in the subos is `glslang` and the name mesa
    # actually asks for is unreachable. Configure then dies with
    #
    #   ERROR: Program 'glslangValidator' not found or not executable
    #
    # while the tool sits in an installed payload.
    #
    # Fixed here rather than in glslang.lua on purpose. Registering the two extra
    # names as `programs` would put user-facing shims on them and change shim
    # OWNERSHIP -- a semantics change, audited by the orphan-shim check -- to
    # solve what is purely a build-time lookup. Deps of a build are exactly the
    # things whose tools that build may invoke, so PATH is where this belongs,
    # and it now works for any future dep that ships one.
    #
    # Prepended, so a dep's tool beats a host one of the same name.
    if [[ -d "${depdir%/}/bin" ]]; then
        PATH="${depdir%/}/bin:$PATH"
        export PATH
    fi
    # BOTH pkgconfig locations, and the second one is not a nicety.
    #
    # `lib/pkgconfig` is where a library puts its .pc. A PROTOCOL-ONLY package
    # installs no library at all and puts its .pc in `share/pkgconfig` --
    # xorgproto ships 40 of them there (xineramaproto, damageproto, ...), and
    # xcb-proto is the same shape.
    #
    # Looking only at `lib/` therefore made every protocol package invisible to
    # pkg-config while its HEADERS were still spliced in by `-I` below. That
    # combination is why the gap survived: mesa builds fine, because it includes
    # the headers and never asks pkg-config for a protocol module. libXinerama
    # does ask, and dies on `XINERAMA_CFLAGS ... no such package` for a package
    # that is sitting right there and whose headers are already on the command
    # line.
    for pcsrc in "$depdir/lib/pkgconfig" "$depdir/share/pkgconfig"; do
        [[ -d "$pcsrc" ]] || continue
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
        #
        # `prefix=` alone is not enough, and that took the input check below to
        # notice. A payload built by THIS script was configured with
        # --prefix=/usr --libdir=/usr/lib, so its .pc reads
        #
        #     prefix=<rewritten>
        #     libdir=/usr/lib          ← absolute, does not use ${prefix}
        #     includedir=${prefix}/include
        #
        # and pkg-config duly answers `-L/usr/lib -lelf`. mesa's build was
        # handed a host library search path for elfutils, libxcb, libX11,
        # libXext, libXi, libXrender, libXcursor, libxshmfence and the rest —
        # 40 of the .pc copies in the work tree carried it. It linked the
        # right libraries anyway, but only because Debian puts them in
        # /usr/lib/x86_64-linux-gnu; on Arch, where /usr/lib IS the library
        # directory, that link picks up the host's copy and nothing says so.
        # The payload check cannot see it either: it wants `/usr/lib/` with a
        # trailing slash, so `libdir=/usr/lib` reads as clean.
        #
        # And running pkg-config by hand does not show it. pkg-config drops a
        # -L for a directory it considers a system one, so `pkg-config --libs
        # libelf` prints `-lelf` and looks fine — while meson, which sets
        # PKG_CONFIG_ALLOW_SYSTEM_LIBS=1 on purpose, gets `-L/usr/lib -lelf`.
        # Measured both ways against elfutils' .pc on 2026-08-08.
        #
        # So every absolute /usr in the copy is rewritten, not just prefix.
        pcdir="$WORK/pc/$dep"
        mkdir -p "$pcdir"
        for pc in "$pcsrc"/*.pc; do
            [[ -e "$pc" ]] || continue
            sed -e "s#^prefix=.*#prefix=${depdir%/}#" \
                -e "s#=/usr\$#=${depdir%/}#" \
                -e "s#=/usr/#=${depdir%/}/#g" \
                -e "s#\(-[IL]\)/usr/#\1${depdir%/}/#g" \
                "$pc" > "$pcdir/$(basename "$pc")"
        done
        case ":$PKG_CONFIG_LIBDIR:" in
            *":$pcdir:"*) ;;
            *) PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$pcdir" ;;
        esac
    done
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
# Build-only packages, which the --deps path deliberately cannot reach.
#
# `--deps` resolves a name to a payload and rewrites its .pc files, but it only
# looks at packages the SUBOS SYSROOT links, and a `status = "dev"` package is
# precisely one that does not link itself into the sysroot -- llvm-dev exports no
# programs, no sysroot headers and no libdirs a consumer would ever see. So
# mesa's `dependency('libclc')` cannot be satisfied through --deps without making
# llvm-dev pretend to be a runtime package, which would defeat the reason it is
# a separate package at all.
#
# Hence an explicit hook. It takes payload-absolute pkgconfig directories:
#
#   XLINGS_GFX_PKGCONFIG_EXTRA=/path/llvm-dev/share/pkgconfig:/path/dxh/share/pkgconfig
#
# These are still OUR artifacts -- a published package payload or this tree's own
# build output -- so the host-leakage audit downstream stays meaningful. It is
# appended AFTER the subos entries so it can add names, never shadow one.
if [[ -n "${XLINGS_GFX_PKGCONFIG_EXTRA:-}" ]]; then
    IFS=':' read -r -a __extra_pc <<< "$XLINGS_GFX_PKGCONFIG_EXTRA"
    for d in "${__extra_pc[@]}"; do
        [[ -n "$d" ]] || continue
        [[ -d "$d" ]] || fail "XLINGS_GFX_PKGCONFIG_EXTRA names '$d', which is not a directory"
        # Refuse a host path outright. The whole point of this hook is to add
        # our own build-only inputs; letting it name /usr/lib/pkgconfig would
        # turn it into the exact hole the audit is here to close.
        case "$d" in
            "$XHOME"/*|"$WORK"/*) ;;
            *) fail "XLINGS_GFX_PKGCONFIG_EXTRA may only name paths under XLINGS_HOME ($XHOME) or the work dir ($WORK); got '$d'" ;;
        esac
        PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$d"
        log "extra pkgconfig: $d ($(ls "$d"/*.pc 2>/dev/null | xargs -r -n1 basename | tr '\n' ' '))"
    done
fi

export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR" CPPFLAGS LDFLAGS

# Resolve a meson to drive the build with.
#
# There is NO `meson` package in this index -- `xlings install meson` answers
# "package 'meson' not found". This line used to read `"$SUBOS/bin/meson"`
# unconditionally, which means every meson build here (mesa included) has in fact
# been driven by whatever meson the developer's host happened to have on PATH,
# usually a `pip --user` install. That is a build input nobody named or pinned,
# and it is the same class of thing the host-leakage audit below exists to catch
# -- the audit just never looked at the DRIVER, only at what the driver found.
#
# Order of preference:
#   1. `$SUBOS/bin/meson` — if meson ever becomes a package, it wins with no
#      further change here.
#   2. a pinned meson fetched into the work directory and run under the SUBOS's
#      python. Reproducible and version-stated, which host meson is not.
#
# A vendored copy rather than a new package because meson contributes no code and
# no linkage to the payload: it reads meson.build and writes build.ninja. ninja
# and the compiler, which do touch the output, are already packages. Packaging
# meson is still worth doing (openxlings/xim-pkgindex#562) -- this makes the
# build honest in the meantime instead of silently depending on the host.
MESON_PIN="${MESON_PIN:-1.8.2}"
__resolve_meson() {
    if [[ -x "$SUBOS/bin/meson" ]]; then
        MESON=("$SUBOS/bin/meson")
        log "meson: $("$SUBOS/bin/meson" --version 2>/dev/null || echo '?') (packaged)"
        return
    fi

    local py=""
    for c in "$SUBOS/bin/python3" "$SUBOS/bin/python"; do
        [[ -x "$c" ]] && { py="$c"; break; }
    done
    [[ -n "$py" ]] || skip "no meson and no python in subos '$SUBOS_NAME'; a meson build needs one of them (install python, or see #562)"

    local root="$WORK/tools/meson-$MESON_PIN"
    if [[ ! -f "$root/meson.py" ]]; then
        mkdir -p "$WORK/tools"
        local tb="$WORK/tools/meson-$MESON_PIN.tar.gz"
        [[ -f "$tb" ]] || curl -fsSL --retry 3 -o "$tb" \
            "https://github.com/mesonbuild/meson/releases/download/$MESON_PIN/meson-$MESON_PIN.tar.gz" \
            || fail "fetching pinned meson $MESON_PIN"
        tar -C "$WORK/tools" -xzf "$tb" || fail "extracting meson $MESON_PIN"
    fi
    [[ -f "$root/meson.py" ]] || fail "meson $MESON_PIN tarball has no meson.py"

    MESON=("$py" "$root/meson.py")
    log "meson: $MESON_PIN vendored, driven by $("$py" --version 2>&1 | head -1)"

    __vendor_python_modules "$py"
}

# Python modules a meson build needs at CODEGEN time.
#
# mesa generates a large amount of C from Mako templates, so its meson probes
# `import mako` and refuses to configure without it. Our python payload is a bare
# interpreter -- no mako -- so this is the same gap as meson itself (#562) and
# gets the same answer: pinned, fetched, under OUR interpreter, on PYTHONPATH
# rather than installed into the payload.
#
# Not installed into site-packages on purpose. The python payload is shared
# between subos and is content-addressed by the index; mutating it would make an
# installed package differ from its published bytes, and every self-containment
# check that hashes a payload would start disagreeing with the recipe.
#
# `--target` into the work dir keeps it per-build and disposable. mako pulls
# MarkupSafe, whose C extension gets compiled by our own gcc against our own
# python -- in-tree, and it falls back to pure Python if that fails.
# `packaging` is not optional here, and the reason is a dead fallback.
#
# mesa's probe (meson.build:943) is:
#
#   try:    from packaging.version import Version
#   except: from distutils.version import StrictVersion as Version
#   import mako
#   assert Version(mako.__version__) >= Version("0.8.0")
#
# distutils was REMOVED in Python 3.12, and our payload is 3.13.12 -- so on this
# interpreter the `except` branch raises too, and the whole snippet exits
# non-zero even when mako is perfectly importable. mesa then reports
#
#   Python (3.x) mako module >= 0.8.0 required to build mesa
#
# which names the one module that is NOT the problem. Vendoring mako alone
# reproduces exactly that: measured 2026-08-08, `import mako` succeeded and
# printed 1.3.10 while mesa's configure still failed on the same line.
# Enumerated from the consumer, not discovered one build at a time.
#
# mesa has exactly two python module gates -- `grep -n 'required to build mesa'`
# gives meson.build:954 (mako) and :963 (yaml) and nothing else. Finding them by
# rebuilding until it stops complaining costs one full configure per module and
# stops at the first one that happens to be satisfied on the machine you tried.
MAKO_PIN="${MAKO_PIN:-1.3.10}"
PACKAGING_PIN="${PACKAGING_PIN:-25.0}"
PYYAML_PIN="${PYYAML_PIN:-6.0.2}"
__vendor_python_modules() {
    local py="$1"
    local vendor="$WORK/tools/pyvendor"

    # mesa's OWN predicates, verbatim, as the probe -- not `import mako`.
    #
    # Checking the mechanism instead of the effect is what hid the `packaging`
    # problem for a whole build cycle: `import mako` printed 1.3.10 and the
    # consumer still refused, because mesa's snippet needs packaging too.
    local probe='
try:
  from packaging.version import Version
except:
  from distutils.version import StrictVersion as Version
import mako
assert Version(mako.__version__) >= Version("0.8.0")
import yaml
'
    if "$py" -c "$probe" 2>/dev/null; then
        log "python: mesa's module predicates already satisfied"
        return
    fi

    if [[ ! -d "$vendor/mako" || ! -d "$vendor/packaging" || ! -d "$vendor/yaml" ]]; then
        log "python: vendoring mako $MAKO_PIN + packaging $PACKAGING_PIN + PyYAML $PYYAML_PIN into $vendor"
        "$py" -m pip install --quiet --disable-pip-version-check \
              --target "$vendor" "Mako==$MAKO_PIN" "packaging==$PACKAGING_PIN" "PyYAML==$PYYAML_PIN" \
              >"$WORK/pyvendor.log" 2>&1 \
            || { tail -20 "$WORK/pyvendor.log" >&2; fail "vendoring python modules (see $WORK/pyvendor.log)"; }
    fi
    export PYTHONPATH="${vendor}${PYTHONPATH:+:$PYTHONPATH}"

    "$py" -c "$probe" || fail "mesa's python module predicates still fail after vendoring; PYTHONPATH=$PYTHONPATH"
    log "python: mako $("$py" -c 'import mako;print(mako.__version__)')," \
        "packaging $("$py" -c 'import packaging;print(packaging.__version__)')," \
        "yaml $("$py" -c 'import yaml;print(yaml.__version__)')"
}

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
    __resolve_meson
    "${MESON[@]}" setup _b --prefix="$PREFIX" --libdir=lib \
        --buildtype=release -Ddefault_library=shared "${EXTRA[@]}" > "$WORK/$NAME-configure.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-configure.log"; fail "meson setup"; }
    "${BUILD_ENV[@]}" "$SUBOS/bin/ninja" -C _b > "$WORK/$NAME-build.log" 2>&1 \
        || { tail -30 "$WORK/$NAME-build.log"; fail "ninja"; }
    DESTDIR="$STAGE" "${MESON[@]}" install -C _b >> "$WORK/$NAME-build.log" 2>&1 \
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

# Inputs before payload, and before anything is packaged.
#
# Ordering, not taste: a host input is the cause and a host path in the payload
# is one of its symptoms, so reporting the cause first is what stops someone
# patching an RPATH and calling it fixed. And failing here means no tarball is
# written — the mesa that shipped against the host's LLVM had already been
# packaged and staged by the time anyone looked.
#
# Its exit code is this script's exit code: 1 for a host input, 2 for "could
# not read what the build linked against". Neither becomes 0.
check_build_inputs "$BUILDDIR" || exit $?

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

# ── the check on the OUTPUT ─────────────────────────────────────────────
# The inputs were checked above. This is the payload: what a host path in here
# breaks is the NEXT machine, not this one.
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
