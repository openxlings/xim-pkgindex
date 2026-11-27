#!/usr/bin/env bash
# Does a glibc payload's loader still read the HOST's /etc/ld.so.preload?
#
# Usage:  verify-preload-closure.sh [<glibc payload dir>]
#         (default: the installed xim-x-glibc that `xvm` resolves)
#
# WHY THIS CHECK EXISTS
#
# /etc/ld.so.preload is a list of shared objects the loader puts into EVERY
# process it starts, before that process's own dependencies. glibc names the
# path as a literal, so a payload loader reads the list belonging to the
# machine it is running on rather than the one belonging to the payload.
#
# The objects on that list are host-built. Ours is a different libc. Both
# outcomes are invisible to the program:
#
#   * a host object whose own dependency is not in our closure kills the
#     process at startup, naming a library nothing we built ever referenced
#   * a self-contained one loads and runs against OUR libc
#
# mcpp-community/mcpp#484 is the first: `g++ --version`, compilation, linking
# and the produced binaries all exit 127 on such a host. The file is empty on
# dev boxes and on CI, and present on audited, managed and cloud hosts -- so
# the failure lives exactly where users deploy and nowhere we test.
#
# THE CONTROL, AND WHY IT IS HALF THIS SCRIPT
#
# "The program ran, so the host list was ignored" is not a finding. The
# program also runs when the harness silently did nothing -- when bwrap did
# not overlay /etc, when the probe failed to build, when the loader never
# consults any preload file at all. Each of those produces the same green.
#
# So the same probe is used twice with one difference:
#
#   A  XLINGS_LD_PRELOAD_FILE points at it   -> its marker MUST appear
#   B  the host's /etc/ld.so.preload lists it -> its marker MUST NOT appear
#
# A failing means the harness cannot see a preload it asked for, which makes
# B's silence worthless: that is exit 2, not exit 0. Only A passing gives B
# any meaning.
#
# Exit codes: see .agents/tools/README.md (0 proven, 1 broken, 2 inconclusive,
# 3 could-not-run).
set -uo pipefail

say()  { echo "[preload-closure] $*"; }
bad()  { echo "[preload-closure] BROKEN: $*" >&2; exit 1; }
huh()  { echo "[preload-closure] INCONCLUSIVE: $*" >&2; exit 2; }
skip() { echo "[preload-closure] SKIP: $*" >&2; exit 3; }

# ── inputs ──────────────────────────────────────────────────────────────
PAYLOAD="${1:-}"
if [[ -z "$PAYLOAD" ]]; then
    for c in "$HOME/.mcpp/registry/data/xpkgs/xim-x-glibc"/* \
             "${XLINGS_HOME:-$HOME/.xlings}/data/xpkgs/xim-x-glibc"/*; do
        [[ -d "$c" ]] && PAYLOAD="$c"
    done
fi
[[ -n "$PAYLOAD" && -d "$PAYLOAD" ]] || skip "no glibc payload given and none found"

LOADER="$(find "$PAYLOAD" -maxdepth 2 -name 'ld-linux-*.so.*' ! -type l 2>/dev/null | head -1)"
[[ -n "$LOADER" ]] || skip "no loader in $PAYLOAD"
LIBC="$(find "$PAYLOAD" -maxdepth 2 -name 'libc.so.6' 2>/dev/null | head -1)"
[[ -n "$LIBC" ]] || skip "no libc.so.6 in $PAYLOAD"

command -v bwrap >/dev/null || skip "bwrap not available"
CC=""
for c in /usr/bin/cc /usr/bin/gcc; do [[ -x "$c" ]] && CC="$c" && break; done
[[ -n "$CC" ]] || skip "no host compiler to build the probe"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
MARKER="xlings-preload-probe-was-loaded"
BW_SETENV=()

# The probe announces itself from a constructor, which runs whether or not the
# program does anything. stderr, because the program under test writes stdout.
cat > "$WORK/probe.c" <<EOF
#include <unistd.h>
#include <string.h>
__attribute__((constructor)) static void probe (void)
{
  const char *m = "$MARKER\n";
  ssize_t r = write (2, m, strlen (m));
  (void) r;
}
EOF
"$CC" -shared -fPIC -o "$WORK/libprobe.so" "$WORK/probe.c" 2>"$WORK/cc.log" \
    || huh "probe did not build: $(tail -3 "$WORK/cc.log")"

# An /etc we can write into: symlink every real entry, then add our own file.
# bwrap cannot create a file inside a read-only bind of the host's /etc.
ETC="$WORK/etc"; mkdir -p "$ETC"
for e in /etc/*; do ln -s "$e" "$ETC/$(basename "$e")" 2>/dev/null; done

# NOTHING MAY STAND BETWEEN bwrap AND THE PROGRAM UNDER TEST.
#
# The first version of this ran `env VAR=x <loader> <libc>` inside the
# sandbox, and control B failed on a payload that was in fact correct. `env`
# is a HOST binary started by the HOST loader, inside the namespace where we
# had just installed the probe as /etc/ld.so.preload -- so the host loader
# preloaded the probe into `env`, and the marker on stderr came from the
# helper rather than from the process being measured.
#
# That is the failure mode this whole script exists to catch, one level up:
# the observation was real, the attribution was wrong. bwrap's own --setenv
# does the job with no extra process.
run_under () {  # run_under <etc-dir> <prog> [args...]   [env via BW_SETENV]
    local etcdir="$1"; shift
    bwrap --dev-bind / / --ro-bind "$etcdir" /etc \
          --unsetenv LD_PRELOAD --unsetenv LD_LIBRARY_PATH \
          "${BW_SETENV[@]}" "$@" 2>&1
}

# The program under test is the payload's own libc, launched through the
# payload's own loader. It needs no compiler and exists in every payload.
#
# Launched EXPLICITLY, not by PT_INTERP: a payload's libc.so.6 carries the
# build machine's loader path as its interpreter, so `./libc.so.6` fails with
# a bare "No such file or directory" that names libc rather than the missing
# interpreter. That is the same baked-path leak this payload has in three
# ELFs; it is not what this script is measuring, and going through the loader
# by hand keeps it from being mistaken for a preload failure.
#
# /etc/ld.so.preload is still processed for an explicit loader invocation --
# it is read by the loader, not by execve -- so this does not weaken B.
PROG=("$LOADER" "$LIBC")

# ── A: the harness can see a preload it asked for ───────────────────────
rm -f "$ETC/ld.so.preload"
echo "$WORK/libprobe.so" > "$WORK/preload.list"
BW_SETENV=(--setenv XLINGS_LD_PRELOAD_FILE "$WORK/preload.list")
outA="$(run_under "$ETC" "${PROG[@]}")"
if ! grep -qF "$MARKER" <<<"$outA"; then
    huh "the loader did not load a preload file it was pointed at.
    Either this payload predates the preload patch (then B below proves
    nothing), or the harness is not reaching the process at all.
    output: $(head -3 <<<"$outA")"
fi
say "control A: a requested preload file IS loaded"

# ── B: the host's list is NOT read ──────────────────────────────────────
echo "$WORK/libprobe.so" > "$ETC/ld.so.preload"
BW_SETENV=()
outB="$(run_under "$ETC" "${PROG[@]}")"
if grep -qF "$MARKER" <<<"$outB"; then
    bad "the loader read the host's /etc/ld.so.preload.
    A host object is being injected into every process this payload starts,
    including the binaries we ship. See mcpp-community/mcpp#484."
fi
say "control B: the host's /etc/ld.so.preload is NOT read"

# ── C: the #484 symptom itself ──────────────────────────────────────────
# A host object with a dependency our closure cannot resolve. Under the old
# behaviour this is fatal at startup; the message names a library that appears
# nowhere in what we built, which is what made the original report hard to
# place.
"$CC" -shared -fPIC -o "$WORK/libdep.so" "$WORK/probe.c" \
      -Wl,--no-as-needed -lz 2>/dev/null \
    && echo "$WORK/libdep.so" > "$ETC/ld.so.preload" \
    && {
        BW_SETENV=()
        outC="$(run_under "$ETC" "${PROG[@]}")"
        if grep -qiE "error while loading shared libraries|cannot open shared object" <<<"$outC"; then
            bad "the #484 symptom reproduces: $(head -1 <<<"$outC")"
        fi
        say "control C: a host preload with an unreachable dependency is harmless"
    }

say "PROVEN — $PAYLOAD ignores the host preload list"
exit 0
