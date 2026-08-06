#!/usr/bin/env bash
# Verify nvidia-gl-host-link end to end: EGL and GLX both render on the host's
# NVIDIA GPU, through OUR payload, with no LD_LIBRARY_PATH.
#
# What this checks that a renderer string alone cannot:
#
#   1. PROVENANCE. `glxinfo` inside a subos prints the NVIDIA renderer even
#      when every object came from /usr/lib -- the host binary under the host
#      loader. Measured 2026-08-06. So each probe reports the path of every
#      GL object it mapped, and this script asserts our interposer is among
#      them.
#   2. BOTH ENTRY POINTS. glvnd dlopens each vendor library by name, so EGL
#      and GLX are separate load-chain roots. With only libEGL interposed,
#      EGL passed and GLX silently used the host's dependency closure.
#   3. NO LD_LIBRARY_PATH. That variable is what the interposer replaces; if
#      it is set, the result proves nothing about DT_RPATH.
#
# Usage: verify-host-link.sh <XLINGS_HOME> [subos]
# Requires: the home already has nvidia-gl-host-link installed, an X server on
# $DISPLAY, and an NVIDIA driver on the host.
set -euo pipefail

HOME_DIR="${1:?usage: verify-host-link.sh <XLINGS_HOME> [subos]}"
SUBOS="${2:-default}"
SYS="$HOME_DIR/subos/$SUBOS"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0; skipped=0
ok()   { echo "  ✓ $*"; pass=$((pass+1)); }
bad()  { echo "  ✗ $*"; fail=$((fail+1)); }
# A check that did not run is its own outcome, counted and reported in the
# verdict. Before this, three places in this script skipped in a `·` line that
# the summary never mentioned -- so "PASS: 12 checks" was compatible with two of
# them never having executed.
skip() { echo "  ! $*"; skipped=$((skipped+1)); }
sect() { echo; echo "── $* ─────────────────────────────"; }

XB="${XLINGS_BIN:-}"
[[ -n "$XB" ]] || XB="$(command -v xlings)"

# NOT `gcc` off PATH. In a shell that has xlings on PATH, `gcc` is an xlings
# shim and resolves to whatever toolchain is selected -- measured here as a
# musl gcc, whose output segfaults the moment it touches the glibc-linked
# vendor. The probes must be built by a compiler that produces host-ABI
# objects, so name it explicitly and let the caller override.
CC="${CC:-}"
if [[ -z "$CC" ]]; then
  for c in /usr/bin/gcc /usr/bin/cc /usr/bin/clang; do
    [[ -x "$c" ]] && { CC="$c"; break; }
  done
fi
[[ -n "$CC" ]] || { echo "no host compiler (/usr/bin/gcc); set CC=" >&2; exit 2; }

# Headers come from the payloads, not the sysroot: the subos's own
# `usr/include` is glibc's, and libglvnd's EGL/GL headers are not linked into
# it. Resolve them where they actually are.
GLVND_INC="$(find "$HOME_DIR/data/xpkgs" -maxdepth 4 -type d -path '*libglvnd*/include' | head -1)"

echo "home:  $HOME_DIR"
echo "subos: $SUBOS"
echo "cc:    $CC"

sect "0. the payload's entry points are interposers, not host symlinks"
NVLIB="$(find "$HOME_DIR/data/xpkgs" -maxdepth 3 -type d -path '*nvidia-gl-host-link*/lib' | head -1)"
if [[ -z "$NVLIB" ]]; then
  bad "nvidia-gl-host-link is not installed in this home"
else
  for f in libEGL_nvidia.so.0 libGLX_nvidia.so.0 libGLESv1_CM_nvidia.so.1 libGLESv2_nvidia.so.2; do
    if [[ ! -e "$NVLIB/$f" ]]; then
      skip "$f absent on this host — that entry point is unproven"
    elif [[ -L "$NVLIB/$f" ]]; then
      bad "$f is a symlink into $(readlink "$NVLIB/$f") — its deps resolve from the host"
    else
      # An interposer is not just "a real file": assert the shape patchelf
      # was asked to produce, on the artifact.
      need="$(patchelf --print-needed "$NVLIB/$f" 2>/dev/null | head -1)"
      son="$(patchelf --print-soname "$NVLIB/$f" 2>/dev/null)"
      if [[ "$son" == "$f" && "$need" == /* && "$need" == */"$f" ]]; then
        ok "$f interposes $need"
      else
        bad "$f soname='$son' needed='$need' — not the interposer shape"
      fi
    fi
  done
fi

sect "1. EGL renders a pixel, through our payload"
if [[ -e "$SYS/lib/libEGL.so.1" ]]; then
  # Build against the subos, run under the subos's loader, DT_RPATH so the
  # transitive search reaches glvnd's dlopen of the vendor.
  if "$CC" -O0 -o "$WORK/glprobe" "$HERE/glprobe.c" \
        ${GLVND_INC:+-I"$GLVND_INC"} -L"$SYS/lib" -lEGL -lGL \
        -Wl,--dynamic-linker="$SYS/lib/ld-linux-x86-64.so.2" \
        -Wl,-rpath,"$SYS/lib" -Wl,--disable-new-dtags 2>"$WORK/egl.build"; then
    out="$(env -u LD_LIBRARY_PATH "$WORK/glprobe" 2>&1 || true)"
    grep -q "^RESULT=ok" <<<"$out" && ok "EGL rendered ($(grep -m1 '^PIXEL=' <<<"$out"))" \
      || bad "EGL: $(grep -m1 '^RESULT=' <<<"$out" || echo 'no RESULT line')"
    grep -qi "GL_RENDERER=.*NVIDIA" <<<"$out" \
      && ok "EGL renderer: $(grep -m1 -i '^GL_RENDERER=' <<<"$out")" \
      || bad "EGL renderer is not NVIDIA: $(grep -m1 -i '^GL_RENDERER=' <<<"$out" || echo '(none)')"
    grep -q "^LOADED=$NVLIB/libEGL_nvidia.so.0$" <<<"$out" \
      && ok "EGL went through OUR interposer" \
      || bad "EGL did NOT load our interposer — it used $(grep -m1 'LOADED=.*EGL_nvidia' <<<"$out" || echo 'no nvidia vendor at all')"
  else
    bad "EGL probe did not build: $(tail -1 "$WORK/egl.build")"
  fi
else
  bad "no libEGL.so.1 in $SYS/lib"
fi

sect "2. GLX renders, through our payload"
if [[ -z "${DISPLAY:-}" ]]; then
  skip "DISPLAY unset, GLX skipped — this leaves entry point 2 of 4 unproven"
else
  if "$CC" -O0 -o "$WORK/glxprobe" "$HERE/glxprobe.c" -ldl \
        -Wl,--dynamic-linker="$SYS/lib/ld-linux-x86-64.so.2" \
        -Wl,-rpath,"$SYS/lib" -Wl,--disable-new-dtags 2>"$WORK/glx.build"; then
    out="$(env -u LD_LIBRARY_PATH "$WORK/glxprobe" 2>&1 || true)"
    grep -qi "GLX GL_RENDERER:.*NVIDIA" <<<"$out" \
      && ok "GLX renderer: $(grep -m1 'GLX GL_RENDERER:' <<<"$out" | sed 's/.*: //')" \
      || bad "GLX renderer is not NVIDIA: $(grep -m1 'GLX GL_RENDERER:' <<<"$out" || echo '(none)')"
    grep -q "GLX LOADED $NVLIB/libGLX_nvidia.so.0$" <<<"$out" \
      && ok "GLX went through OUR interposer" \
      || bad "GLX did NOT load our interposer — it used $(grep -m1 'LOADED.*GLX_nvidia' <<<"$out" || echo 'no nvidia vendor at all')"
    grep -q "^GLX LOADED /usr/lib.*libGLX_nvidia.so\.[0-9]" <<<"$out" \
      && ok "the host's real vendor was pulled in by absolute DT_NEEDED" \
      || bad "the host vendor was never loaded — the interposer resolved to something else"
  else
    bad "GLX probe did not build: $(tail -1 "$WORK/glx.build")"
  fi
fi

sect "3. no LD_LIBRARY_PATH is doing the work"
envout="$("$XB" subos use "$SUBOS" --cmd 'echo "LLP=[${LD_LIBRARY_PATH}]"' 2>/dev/null | grep -m1 '^LLP=' || echo 'LLP=[?]')"
[[ "$envout" == "LLP=[]" ]] && ok "LD_LIBRARY_PATH is empty in the subos" \
  || bad "the subos sets $envout — the results above do not isolate DT_RPATH"

sect "4. the host's driver files were not modified"
# The vendor directory is PROBED, not written down.
#
# This used to say `/usr/lib/x86_64-linux-gnu/$f` with `[[ -e "$p" ]] || continue`
# -- the Debian multiarch path, skipped in silence everywhere else. On Fedora,
# RHEL or SUSE (64-bit in /usr/lib64) and on Arch (64-bit in /usr/lib) the check
# therefore examined NOTHING and still printed a ✓ and counted toward PASS.
# That is the same layout assumption as mcpp#352, one layer worse: this file
# exists to prove something.
#
# Same three rules as libs/hostlib.lua, in shell: `ldconfig -p` with the ABI
# token first, then the three layouts, ELF class checked, first hit wins.
host_vendor_dir() {
  local soname="$1" p d
  while read -r p; do
    [[ -f "$p" ]] || continue
    [[ "$(od -An -tu1 -j4 -N1 "$p" 2>/dev/null | tr -d ' ')" == 2 ]] || continue
    dirname "$p"; return 0
  done < <(ldconfig -p 2>/dev/null \
             | awk -v s="$soname" 'index($0, s) && /x86-64/ {print $NF}')
  for d in /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu \
           /usr/lib64 /lib64 /usr/lib /lib; do
    p="$d/$soname"
    [[ -f "$p" ]] || continue
    [[ "$(od -An -tu1 -j4 -N1 "$p" 2>/dev/null | tr -d ' ')" == 2 ]] || continue
    echo "$d"; return 0
  done
  return 1
}

NVHOST="$(host_vendor_dir libGLX_nvidia.so.0 || true)"
if [[ -z "$NVHOST" ]]; then
  # NOT a silent skip. A run that could not find the host's vendor cannot make
  # any claim about it, and saying nothing reads identically to "checked, fine".
  skip "no 64-bit host NVIDIA vendor found — check 4 NOT PERFORMED"
else
  echo "  · host vendor dir: $NVHOST"
  hostbad=0
  for f in libEGL_nvidia.so.0 libGLX_nvidia.so.0; do
    p="$NVHOST/$f"
    [[ -e "$p" ]] || continue
    # An interposer written over a followed symlink would land HERE. The shape
    # is the check: the host's vendor names its own private libs, never an
    # absolute path into a store.
    if patchelf --print-needed "$p" 2>/dev/null | grep -q '^/'; then
      bad "$p has an absolute DT_NEEDED — it was overwritten"
      hostbad=1
    fi
  done
  [[ $hostbad -eq 0 ]] && ok "host vendor libraries are untouched"
fi

echo
# Skips are reported in the verdict, not only next to the check they replaced.
# A reader who sees "PASS: 12 checks" and does not scroll up must still learn
# that one of them did not happen.
if [[ $skipped -gt 0 ]]; then
  echo "NOT PERFORMED: $skipped check(s) — see the ! lines above"
fi
if [[ $fail -eq 0 ]]; then
  echo "PASS: $pass checks$([[ $skipped -gt 0 ]] && echo ", $skipped not performed")"
  exit 0
else
  echo "FAIL: $fail failed, $pass passed$([[ $skipped -gt 0 ]] && echo ", $skipped not performed")"
  exit 1
fi
