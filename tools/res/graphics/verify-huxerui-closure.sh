#!/usr/bin/env bash
# Does the index actually satisfy huxerui's shared-library closure?
#
# #749 packaged huxerui and recorded three sonames its SDK needs that this
# index did not have:
#
#     libgtk-4.so.1   libgdk_pixbuf-2.0.so.0   libsoup-3.0.so.0
#
# so a GUI application built against it had to fall back to the host's GTK
# stack. That is the gap the gtk4 series closes, and this is the check that
# says whether it closed -- measured on the real SDK, not on the issue text.
#
# WHAT IT ACTUALLY MEASURES
#
# For every DT_NEEDED of huxerui's `lib/libhuxerui.so`, transitively, it asks
# ONE question: is this soname provided by a payload under data/xpkgs, or is
# it coming from the host? A soname that resolves only because this machine
# has libgtk-4-1 installed is a FAILURE here -- that is precisely the state
# #749 described, and it looks identical to success on a developer box.
#
# It does NOT need a display, a GPU or a running GTK: DT_NEEDED closure is a
# static property of the ELF files.
#
# Usage:
#   verify-huxerui-closure.sh                 # against $XLINGS_HOME
#   XLINGS_HOME=/tmp/throwaway verify-huxerui-closure.sh
#
# Exit codes per .agents/tools/README.md: 0 proven, 1 broken, 3 could-not-run.
set -uo pipefail

XHOME="${XLINGS_HOME:-$HOME/.xlings}"
XPKGS="$XHOME/data/xpkgs"

log()  { echo "[huxerui-closure] $*"; }
fail() { echo "[huxerui-closure] BROKEN: $*" >&2; exit 1; }
skip() { echo "[huxerui-closure] SKIP: $*" >&2; exit 3; }

command -v readelf >/dev/null || skip "no readelf"
[[ -d "$XPKGS" ]] || skip "no payload dir: $XPKGS"

SDK="$(find "$XPKGS" -maxdepth 3 -type d -name 'huxerui*' 2>/dev/null | head -1)"
[[ -n "$SDK" ]] || SDK="$(find "$XPKGS"/*huxerui*/ -maxdepth 1 -type d 2>/dev/null | head -1)"
[[ -n "$SDK" && -d "$SDK" ]] || skip "huxerui is not installed in $XHOME (xlings install huxerui)"

ROOT_LIB="$(find "$SDK" -name 'libhuxerui.so' -type f 2>/dev/null | head -1)"
[[ -n "$ROOT_LIB" ]] || skip "no libhuxerui.so under $SDK"
log "root: ${ROOT_LIB#$XHOME/}"

# Everything every installed payload provides, by soname.
declare -A PROVIDER
while IFS= read -r so; do
    base="$(basename "$so")"
    [[ -n "${PROVIDER[$base]:-}" ]] && continue
    rel="${so#$XPKGS/}"
    PROVIDER["$base"]="${rel%%/*}"
done < <(find "$XPKGS" -name '*.so' -o -name '*.so.*' 2>/dev/null | sort)

# glibc's own set is provided by the glibc payload; they show up above already,
# but ld-linux is reached through PT_INTERP rather than DT_NEEDED.
declare -A SEEN
# Assigned, not just declared. Under `set -u` bash treats a declared-but-unset
# array as unbound, so `${#HOSTONLY[@]}` on the clean path -- nothing missing,
# which is the outcome this script exists to report -- aborted with
# `HOSTONLY: unbound variable` instead of printing success. (`${#X[@]:-0}` is
# not the fix: that is a bad substitution, and bash says so.)
declare -a QUEUE=() MISSING=() HOSTONLY=()
QUEUE=("$ROOT_LIB")
resolved=0

while [[ ${#QUEUE[@]} -gt 0 ]]; do
    cur="${QUEUE[0]}"; QUEUE=("${QUEUE[@]:1}")
    [[ -n "${SEEN[$cur]:-}" ]] && continue
    SEEN["$cur"]=1
    while read -r need; do
        [[ -z "$need" ]] && continue
        owner="${PROVIDER[$need]:-}"
        if [[ -z "$owner" ]]; then
            # Not in any payload. Is it on the host? Either way it is a gap;
            # distinguishing the two only changes how the failure reads --
            # but read it correctly: ldconfig prints
            #     \tlibstdc++.so.6 (libc6,x86-64) => /lib/...
            # with a LEADING TAB, so a pattern anchored on " $need " matches
            # nothing and every host-resolved soname is misreported as
            # unresolvable anywhere.
            if ldconfig -p 2>/dev/null | grep -qE "(^|[[:space:]])$(printf '%s' "$need" | sed 's/[.[\*^$]/\\&/g')[[:space:]]"; then
                HOSTONLY+=("$need (needed by $(basename "$cur"))")
            else
                MISSING+=("$need (needed by $(basename "$cur"))")
            fi
            continue
        fi
        resolved=$((resolved+1))
        nxt="$(find "$XPKGS/$owner" -name "$need" 2>/dev/null | head -1)"
        [[ -n "$nxt" ]] && QUEUE+=("$nxt")
    done < <(readelf -d "$cur" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
done

log "walked ${#SEEN[@]} object(s), $resolved DT_NEEDED edge(s) resolved inside data/xpkgs"

# The three #749 named, called out by name so the answer is legible.
log "the three sonames #749 recorded as missing:"
rc=0
for n in libgtk-4.so.1 libgdk_pixbuf-2.0.so.0 libsoup-3.0.so.0; do
    if [[ -n "${PROVIDER[$n]:-}" ]]; then
        echo "    OK       $n  <- ${PROVIDER[$n]}"
    else
        echo "    MISSING  $n"
        rc=1
    fi
done

if [[ ${#HOSTONLY[@]} -gt 0 ]]; then
    echo "[huxerui-closure] resolved from the HOST, not from a payload:" >&2
    printf '    %s\n' "${HOSTONLY[@]}" >&2
    rc=1
fi
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "[huxerui-closure] not resolvable at all:" >&2
    printf '    %s\n' "${MISSING[@]}" >&2
    rc=1
fi

[[ $rc -eq 0 ]] && log "closure is complete: nothing reaches outside data/xpkgs"
exit $rc
