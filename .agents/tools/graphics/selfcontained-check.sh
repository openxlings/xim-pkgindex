#!/usr/bin/env bash
# Is the xlings graphics stack actually self-contained?
#
# Runs a real GL client inside a bwrap container with NO /usr and NO /lib —
# only the subos, /dev/dri and a read-only /sys. Anything the stack still needs
# from the host shows up here as a loader error, because there is no host left
# to fall back to.
#
# Design: xlings/.agents/docs/2026-08-05-graphics-stack-ecosystem-closure.md §8
#
# The four assertions, and why each exists:
#
#   S1  the process does not die in the dynamic loader
#          → something in the closure is still missing
#   S2  GL_RENDERER contains llvmpipe
#          → we are running OUR software rasteriser
#   S3  GL_RENDERER does NOT contain NVIDIA
#          → the host stack did not leak in
#   S4  glReadPixels returns the colour we cleared to
#          → it actually rendered
#
# S3 is the one that matters most. A run that "works" by quietly loading the
# host's libGL produces output identical to a genuine success, so the only way
# to tell them apart is to assert the host's driver is absent. S2 alone does not
# do it — a host with mesa installed also says llvmpipe.
#
# Exit 0 only when all four hold. Until the graphics packages exist this script
# is expected to FAIL, and that failure is the baseline: it is what says the
# criterion is real rather than written to match whatever we happened to build.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxcheck}"

log()  { echo "[gfx-check] $*"; }
fail() { echo "[gfx-check] FAIL: $*" >&2; exit 1; }
skip() { echo "[gfx-check] SKIP: $*"; exit 0; }

command -v bwrap  >/dev/null || skip "bwrap not available (xlings install bwrap)"
XLINGS_BIN="${XLINGS_BIN:-$(command -v xlings)}"
[[ -x "$XLINGS_BIN" ]] || skip "no xlings on PATH; set XLINGS_BIN"

XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS_DIR="$XHOME/subos/$SUBOS_NAME"
[[ -d "$SUBOS_DIR" ]] || fail "subos '$SUBOS_NAME' does not exist — create it and install \`mesa\` into it first"

# ── the probe ───────────────────────────────────────────────────────────
# Built against the SUBOS's headers and libraries, not the host's. Building it
# against the host would link it to host sonames and make the whole exercise
# circular.
PROBE="$SUBOS_DIR/bin/glprobe"
if [[ ! -x "$PROBE" || "$HERE/glprobe.c" -nt "$PROBE" ]]; then
    log "building glprobe against the subos"
    # The subos's compiler, or nothing. Falling back to whatever `gcc` is on
    # PATH does not degrade the test, it invalidates it: on this machine that
    # is the real home's musl-gcc shim, which pairs musl's <stdarg.h> with the
    # subos's glibc <stdio.h> and fails on `va_list` -- a libc mismatch that
    # reads as a broken graphics stack. A compiler outside the subos also
    # cannot prove anything about a subos that is meant to be self-contained.
    CC="$SUBOS_DIR/bin/gcc"
    [[ -x "$CC" ]] || fail "no gcc in subos '$SUBOS_NAME' (xlings install gcc)"
    # No pipe into head here: the exit status would be head's, and a failed
    # compile would sail past `|| fail` to be reported later as a missing
    # binary inside the container — which reads as an incomplete closure
    # rather than as "it never compiled".
    if ! "$CC" -O1 -o "$PROBE" "$HERE/glprobe.c" \
            -I"$SUBOS_DIR/usr/include" -L"$SUBOS_DIR/lib" -L"$SUBOS_DIR/usr/lib" \
            -Wl,-rpath,"$SUBOS_DIR/usr/lib" -Wl,-rpath,"$SUBOS_DIR/lib" \
            -lEGL -lGL > "$SUBOS_DIR/glprobe-build.log" 2>&1; then
        sed 's/^/    /' "$SUBOS_DIR/glprobe-build.log" | head -15
        fail "cannot build glprobe against the subos (is libglvnd installed?)"
    fi
fi

# ── the empty host ──────────────────────────────────────────────────────
# No --ro-bind /usr, no /lib. /dev/dri is the kernel and /sys is how libdrm and
# libpciaccess enumerate devices; both are on the "cannot be ours" list.
# Mount order matters. --tmpfs /tmp goes FIRST: bwrap applies these in
# sequence, so a tmpfs mounted after the bind would shadow anything under /tmp
# — and an XLINGS_HOME under /tmp (a scratch home, as in CI) then vanishes,
# surfacing as "execvp: No such file or directory" for a binary that is plainly
# there. The ENOENT is the loader's, not the binary's, which sends you looking
# in the wrong place.

# The environment the container gets is not written here. It is read back out
# of the subos, where `mesa`'s config() put it through subos.env{} — the same
# `--shell` code path that sets it for a user who enters the subos, evaluated
# for a container instead of a login shell.
#
# This is the assertion, not the setup. An earlier revision of this script
# hand-wrote --setenv LIBGL_DRIVERS_PATH and passed, which proved only that
# mesa renders when told where its drivers are. Taking the values from the
# package's own declaration is what makes a pass mean the user gets this for
# free; if the declaration is dropped, S0 below fails instead of the script
# quietly supplying it.
SUBOS_ENV="$("$XLINGS_BIN" subos use "$SUBOS_NAME" --shell sh 2>/dev/null)"
# `set` emits `: "${VAR:=value}"; export VAR;`, `prepend` emits
# `export VAR="value${VAR:+:$VAR}";` — both shapes, names only.
DECLARED="$(printf '%s\n' "$SUBOS_ENV" \
    | sed -n -e 's/^export \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' \
             -e 's/^: "${\([A-Za-z_][A-Za-z0-9_]*\):=.*/\1/p' \
    | sort -u | grep -vxE 'PATH|XLINGS_[A-Z_]*')"

grep -qx "LIBGL_DRIVERS_PATH" <<<"$DECLARED" \
  || fail "S0: subos '$SUBOS_NAME' declares no LIBGL_DRIVERS_PATH — mesa's subos.env{} did not reach the manifest"
log "  S0 ok — the subos declares: $(tr '\n' ' ' <<<"$DECLARED")"

ENVARGS=()
while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    # Evaluated in an empty shell so the value is the declaration's, not this
    # shell's variable of the same name leaking in.
    value="$(env -i sh -c "$SUBOS_ENV"$'\n'"printf '%s' \"\${$name}\"")"
    ENVARGS+=(--setenv "$name" "$value")
done <<<"$DECLARED"

# No LD_LIBRARY_PATH either: the probe was linked with -rpath into the subos,
# which is how any program xlings installs finds its libraries. Handing one in
# would hide a stack that only resolves when someone sets a search path.
OUT="$(
  bwrap \
    --unshare-all --die-with-parent \
    --proc /proc --tmpfs /tmp \
    --ro-bind "$XHOME" "$XHOME" \
    --dev-bind /dev/dri /dev/dri \
    --ro-bind /sys /sys \
    --setenv XLINGS_HOME "$XHOME" \
    --setenv HOME /tmp \
    "${ENVARGS[@]}" \
    -- "$PROBE" 2>&1
)"
RC=$?

echo "$OUT" | sed 's/^/    /'

# ── assertions ──────────────────────────────────────────────────────────
[[ $RC -eq 0 ]] || fail "S1: probe exited $RC inside the empty host (closure incomplete)"
grep -q "RESULT=ok" <<<"$OUT" || fail "S1/S4: probe did not reach RESULT=ok"
log "  S1 ok — no loader error with no /usr present"

RENDERER="$(sed -n 's/^GL_RENDERER=//p' <<<"$OUT")"
[[ -n "$RENDERER" ]] || fail "S2: no GL_RENDERER reported"

grep -qi "llvmpipe" <<<"$RENDERER" \
  || fail "S2: renderer is '$RENDERER', expected llvmpipe (software path not taken)"
log "  S2 ok — rendering through our llvmpipe"

grep -qi "nvidia" <<<"$RENDERER" \
  && fail "S3: renderer is '$RENDERER' — the HOST stack leaked in; the container is not sealed"
log "  S3 ok — no host driver reachable"

grep -q "^PIXEL=336699$" <<<"$OUT" \
  || fail "S4: pixel readback was '$(sed -n 's/^PIXEL=//p' <<<"$OUT")', expected 336699"
log "  S4 ok — rendered and read back the expected colour"

log "graphics stack is self-contained: PASS"
