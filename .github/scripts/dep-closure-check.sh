#!/usr/bin/env bash
# Does what a payload NEEDS match what its recipe DECLARES?
#
# Invoked per package from posix-test.sh, after the install succeeded.
#
#   dep-closure-check.sh <payload-dir> <recipe-file> <platform> [<xpkgs-dir>]
#
# THE DEFECT THIS EXISTS FOR
# --------------------------
# A recipe's `deps` list is the only input to the RPATH closure xlings stamps
# onto the payload at install time (elfpatch's `closure_lib_paths`, which reads
# the DIRECT runtime deps -- not the transitive set). So a library the payload
# genuinely loads but the recipe never declared is simply absent from the
# closure. Nothing fails at install time. Nothing fails on a developer machine
# either, because the host happens to have a copy. It fails on a machine that
# does not, and the error names a soname rather than the package that forgot to
# declare it.
#
# That is how libxcb came to search for libXau with no libXau on any search
# path -- an entire index-wide sweep of 28 recipes was needed to repair it, and
# the declaration that would have prevented it is one line. This check is that
# one line, enforced.
#
# THE TWO ASSERTIONS
# ------------------
# D1  every external soname that some INSTALLED package provides must be
#     declared as a direct dep of this recipe.
#
#     Transitivity does not save you here and that is the whole point: A -> B
#     -> C puts only B's libdirs in A's closure, so if A itself names a C
#     soname, A must declare C. Reading "B already depends on C" as sufficient
#     is the mistake.
#
# D2  if this payload's interpreter points inside XLINGS_HOME, then EVERY
#     external soname must have a provider -- a host-only soname is a hard
#     failure, not a note.
#
#     Because our glibc's ld.so carries the build machine's cache path
#     (`/home/xlings/.xlings_data/.../etc/ld.so.cache`), which exists on no
#     machine. On a multiarch distro the host's libraries are reachable ONLY
#     through that cache, so switching PT_INTERP removes the host fallback
#     outright. Measured on jdk-temurin 2026-08-08: headless Java is perfect
#     and AWT dies with `libX11.so.6: cannot open shared object file`, against
#     a working unpatched control on the same machine. "It is only dlopen'd,
#     so it degrades no further than today" is false -- today it resolves off
#     the host, afterwards it resolves nowhere.
#
#     For a payload still on the host loader (`code`, the JDKs) host-only
#     sonames are expected and reported as notes.
#
# A declared dep that nothing in the payload needs is a WARNING, never a
# failure: build-only tools, plugins loaded by path and data-only packages are
# all legitimate reasons, and failing on them would train people to delete
# correct declarations.
#
# EXIT CODES -- the contract in .agents/tools/README.md
#   0 proven   1 broken   2 inconclusive   3 could not be exercised here
set -uo pipefail

PAYLOAD="${1:-}"
RECIPE="${2:-}"
PLATFORM="${3:-linux}"
XPKGS="${4:-${XLINGS_HOME:-$HOME/.xlings}/data/xpkgs}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

say()  { echo "  $*"; }
fail() { echo "  [FAIL] $*" >&2; }

# 3, not 0. A missing tool means this machine could not evaluate the assertion,
# which is a different statement from the assertion holding -- and 0 is what the
# caller reads as "checked, clean".
skip() { echo "  [SKIP] $*"; exit 3; }

[[ -n "$PAYLOAD" && -n "$RECIPE" ]] || { echo "usage: dep-closure-check.sh <payload-dir> <recipe> <platform> [<xpkgs>]" >&2; exit 2; }
[[ -d "$PAYLOAD" ]] || skip "payload dir does not exist: $PAYLOAD"
[[ -f "$RECIPE"  ]] || skip "recipe does not exist: $RECIPE"
command -v readelf >/dev/null 2>&1 || skip "no readelf (binutils) on this machine"
command -v lua >/dev/null 2>&1 || LUA=""
LUA="$(command -v lua5.4 || command -v lua || true)"
[[ -n "$LUA" ]] || skip "no lua interpreter; cannot read deps structurally"
[[ -f "$HERE/check-dep-namespace.lua" ]] || skip "check-dep-namespace.lua not present next to this script"

# ── what the recipe declares ────────────────────────────────────────────
# Structurally, via the shared reader -- never by grepping the recipe. A dep
# list spans lines and appears under several xpm sections, so a line sweep
# both misses and mis-attributes entries, and both failures look clean.
#
# `*` is the descriptor-level list that applies to every platform. Version-
# scoped rows are included: a dep declared only under one version still governs
# that version's closure, and this runs against exactly one installed version.
rel_recipe="${RECIPE#"$ROOT"/}"
# A recipe outside this checkout produces no rows from --list, which would leave
# `declared` empty and make every soname look undeclared. That fails closed, so
# it is not dangerous -- but it reports a dependency defect for what is really
# a wrong argument, and someone would go edit the deps. Say which it is.
case "$rel_recipe" in
    pkgs/*) ;;
    *) echo "  [SKIP] recipe is not inside this index ($RECIPE); cannot read its deps"
       exit 3 ;;
esac
declared=""
while IFS=$'\t' read -r f plat _scope kind _idx dep; do
    [[ "$f" == "$rel_recipe" ]] || continue
    [[ "$plat" == "$PLATFORM" || "$plat" == "*" ]] || continue
    # `build` deps are not in the runtime closure, so they cannot satisfy a
    # DT_NEEDED. Positional (`list`) counts: the client copies it into both.
    [[ "$kind" == "build" ]] && continue
    name="${dep##*:}"; name="${name%%@*}"
    declared+="$name"$'\n'
done < <("$LUA" "$HERE/check-dep-namespace.lua" --list "$ROOT" 2>/dev/null)

is_declared() { [[ -n "$declared" ]] && grep -qxF "$1" <<<"$declared"; }

# ── who provides what ───────────────────────────────────────────────────
# Over every INSTALLED payload except the one under test. Store dir layout is
# <xpkgs>/<ns>-x-<name>/<version>/, so the package name comes off the path.
#
# Symlinks count, and that is not a detail: an soname is almost always the
# symlink (`libstdc++.so.6` -> `libstdc++.so.6.0.33`), so `-type f` alone finds
# the real file under a name nothing ever asks for and reports the actual
# soname as host-only. That mistake makes this check accuse correct recipes.
#
# ALL candidates are kept, not the first one found. Package names are not
# unique per soname -- `libgcc_s.so.1` is shipped by gcc-runtime and by every
# cross-toolchain in the home, including aarch64 ones -- and `find` order is
# alphabetical, so first-wins answers `aarch64-linux-musl-gcc` for an x86_64
# payload. Resolving the ambiguity by preferring a DECLARED candidate is both
# correct and useful: it is the recipe that says which one it meant.
declare -A PROVIDERS
if [[ -d "$XPKGS" ]]; then
    while IFS= read -r so; do
        case "$so" in "$PAYLOAD"/*) continue ;; esac
        b="${so##*/}"
        rest="${so#"$XPKGS"/}"; store="${rest%%/*}"
        name="${store#*-x-}"
        case " ${PROVIDERS[$b]:-} " in
            *" $name "*) ;;
            *) PROVIDERS["$b"]="${PROVIDERS[$b]:-}${PROVIDERS[$b]:+ }$name" ;;
        esac
    done < <(find "$XPKGS" -mindepth 3 -maxdepth 6 -name '*.so*' \( -type f -o -type l \) 2>/dev/null)
fi

# ── what the payload provides itself ────────────────────────────────────
declare -A SELF
while IFS= read -r so; do SELF["${so##*/}"]=1; done \
    < <(find "$PAYLOAD" -name '*.so*' \( -type f -o -type l \) 2>/dev/null)

# ── what the payload needs, and whether its loader is ours ──────────────
#
# `sealed` is the discriminator for how strict to be, and it has to be measured
# rather than assumed. Two ways a payload can be resolving from our tree:
# its executables point at our interpreter, or its objects carry an RPATH into
# xpkgs (what selfcontain.seal stamps on a library package, which has no
# interpreter to inspect at all).
#
# A payload that is neither is integrated with the host on purpose -- `code`,
# the JDKs -- and for it the host IS the provider. Applying D1 there would
# demand that every such package declare `xim:glibc` for a libc it does not use,
# and a check that fires on correct recipes gets switched off.
declare -A NEEDED_BY
ours_interp=""; sealed=0; scanned=0
# Only executables and *.so* are considered, and that is a rule rather than a
# sample: DT_NEEDED is resolved by soname, so a shared object has to be
# `.so`-named for anything to ask for it, and a program has to be executable
# for anything to run it. A file that is neither cannot participate in the
# loader's work no matter what its ELF header says. Scanning everything instead
# meant an `od` per file over payloads like godot and llvm -- minutes each, in a
# check that runs per package in CI.
while IFS= read -r -d '' f; do
    # `od`, not `head -c4` in a command substitution: a payload is full of
    # non-ELF files (.jar, .png, .dat) whose first bytes contain NUL, and bash
    # strips those with a warning on every one of them -- pages of noise around
    # the actual result. Compare the hex instead.
    [[ "$(od -An -tx1 -N4 "$f" 2>/dev/null | tr -d ' ')" == "7f454c46" ]] || continue
    scanned=$((scanned + 1))
    interp="$(readelf -p .interp "$f" 2>/dev/null | grep -oE '/[^ ]*ld-[^ ]*' | head -1)"
    case "$interp" in *"/xpkgs/"*) ours_interp="$interp"; sealed=1 ;; esac
    rp="$(readelf -d "$f" 2>/dev/null | grep -oP '\((?:RPATH|RUNPATH)\).*\[\K[^\]]+')"
    case "$rp" in *"/xpkgs/"*) sealed=1 ;; esac
    while IFS= read -r n; do
        # A DT_NEEDED may itself be a path (`$ORIGIN/../lib/libpython3.13.so.1.0`).
        # It is the basename that has to be provided by someone.
        n="${n##*/}"
        [[ -n "${SELF[$n]:-}" ]] && continue
        NEEDED_BY["$n"]="${NEEDED_BY[$n]:-}${NEEDED_BY[$n]:+ }${f##*/}"
    done < <(readelf -d "$f" 2>/dev/null | grep -oP 'Shared library: \[\K[^\]]+')
done < <(find "$PAYLOAD" -type f ! -type l \
             \( -perm -u+x -o -name '*.so' -o -name '*.so.*' \) -print0 2>/dev/null)

if [[ $scanned -eq 0 ]]; then
    # Not a pass. A payload with no ELF in it (a header-only package, a data
    # package, a pure script) has nothing for this check to say, and saying
    # "clean" would be a claim it has not earned.
    say "no ELF objects in this payload; dependency closure not evaluated"
    exit 3
fi

# ── the assertions ──────────────────────────────────────────────────────
undeclared=(); hostonly=(); used=()
for n in $(printf '%s\n' "${!NEEDED_BY[@]}" | sort); do
    cands="${PROVIDERS[$n]:-}"
    if [[ -z "$cands" ]]; then
        hostonly+=("$n (needed by ${NEEDED_BY[$n]%% *})")
        continue
    fi
    hit=""
    for c in $cands; do is_declared "$c" && { hit="$c"; break; }; done
    if [[ -n "$hit" ]]; then
        used+=("$hit")
    else
        undeclared+=("$n -> provided by {${cands// /, }} (needed by ${NEEDED_BY[$n]%% *})")
    fi
done

rc=0

if [[ $sealed -eq 0 ]]; then
    say "this payload resolves from the host (no xlings interpreter, no xpkgs RPATH);"
    say "D1/D2 are reported but not enforced -- the host is its provider by design."
    [[ ${#undeclared[@]} -gt 0 ]] && say "  would-be undeclared: ${#undeclared[@]}"
    [[ ${#hostonly[@]}   -gt 0 ]] && say "  host-provided sonames: ${#hostonly[@]}"
    exit 0
fi

if [[ ${#undeclared[@]} -gt 0 ]]; then
    fail "D1: ${#undeclared[@]} soname(s) resolve to an installed package this recipe does not declare:"
    for u in "${undeclared[@]}"; do echo "        $u" >&2; done
    echo "      Add them to deps. A transitive dep does NOT put its libdir in this" >&2
    echo "      payload's RPATH closure -- only direct deps do." >&2
    rc=1
fi

if [[ ${#hostonly[@]} -gt 0 ]]; then
    if [[ -n "$ours_interp" ]]; then
        fail "D2: this payload uses OUR loader ($ours_interp)"
        fail "    but ${#hostonly[@]} soname(s) have no provider in the index:"
        for h in "${hostonly[@]}"; do echo "        $h" >&2; done
        echo "      There is no host fallback behind our loader -- its ld.so.cache path" >&2
        echo "      does not exist on any machine. These will not be found at runtime," >&2
        echo "      including the ones only reached via dlopen." >&2
        rc=1
    else
        say "note: ${#hostonly[@]} soname(s) come from the host; this payload is on the"
        say "      host loader, so that is the documented arrangement, not a leak:"
        for h in "${hostonly[@]}"; do say "        $h"; done
    fi
fi

# Warning only, deliberately -- see the header.
used_list="$(printf '%s\n' ${used[@]+"${used[@]}"} | sort -u)"
while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    grep -qxF "$d" <<<"$used_list" \
        || say "warn: declares '$d', but nothing in the payload names a soname it provides"
done <<<"$declared"

if [[ $rc -eq 0 ]]; then
    say "dependency closure: $scanned ELF, ${#NEEDED_BY[@]} external soname(s), all accounted for"
fi
exit $rc
