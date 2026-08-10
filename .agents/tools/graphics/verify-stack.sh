#!/usr/bin/env bash
# Verify the xlings graphics stack on THIS machine, in a dedicated subos.
#
#   verify-stack.sh [--subos NAME] [--home DIR] [--keep] [--json]
#
#   exit 0 everything that ran passed · 1 something failed · 3 nothing ran
#   sending a run back from hardware we do not have: graphics/collect-matrix.md
#
# WHY THIS EXISTS
#
# Verification of this stack was three scripts that each covered one slice:
# verify-host-link.sh (NVIDIA only, needs a GPU), selfcontained-check.sh
# (empty host, needs bwrap and a subos compiler), and whatever the developer
# typed that day. Each had its own setup, none knew about the others, and the
# union was never reported anywhere. So "the ecosystem works" rested on one
# machine with one GPU -- an RTX 4080 -- and every other cell of the matrix was
# untested in a way that produced no output at all.
#
# THE RULE THIS ENCODES
#
# A cell that could not be exercised HERE is a third outcome, not a pass and
# not a failure. It is printed, counted, and carried into the summary. Anything
# else makes "we do not have that hardware" and "it works" look identical --
# which is the failure mode this whole stack keeps producing and keeps having to
# re-learn (see project_silent_success_pattern).
#
# HOW COVERAGE IS MEANT TO ACCUMULATE
#
# No single machine can cover the matrix: nobody has an NVIDIA, an AMD, an Intel
# and a WSL2 host at once. So this script is designed to be run by DIFFERENT
# people and its summary pasted into an issue. The union of runs is the
# ecosystem's coverage, and the SKIP lines are the recruitment list.
#
# Design: xlings/.agents/docs/2026-08-07-graphics-experience-industry-survey-and-plan.md §10
set -uo pipefail

# DT_RUNPATH, the default -- NOT --disable-new-dtags.
#
# These probes used to pass `-Wl,--disable-new-dtags`, which emits DT_RPATH.
# DT_RPATH is searched TRANSITIVELY up the load chain, so the probe's own
# rpath ended up serving glvnd's dlopen of the vendor from inside
# libGLX.so.0. That works, and no real consumer does it: every build system
# emits plain `-Wl,-rpath` with the modern default, which is DT_RUNPATH, and
# DT_RUNPATH is not transitive. So every green GLX check here was bought with
# a flag nobody passes -- openxlings/xlings#525, where mcpp's imgui template
# got "GLX: No GLXFBConfigs returned" on a host whose own glxinfo was fine.
#
# Vendor reachability now lives where it belongs: libglvnd's own libGLX.so.0
# carries $ORIGIN/glx-vendor. These probes therefore link the way a real
# consumer links, and a failure here is a real failure.
#
# XLINGS_GFX_LEGACY_DTAGS=1 restores the old flag. Keep it for diagnosis
# only: if the legacy build passes and the default one fails, the vendor
# directory is the thing that is broken, not the rest of the stack.
DTAGS=()
[[ -n "${XLINGS_GFX_LEGACY_DTAGS:-}" ]] && DTAGS=(-Wl,--disable-new-dtags)

SUBOS="gfxverify"; KEEP=0; JSON=0; XHOME_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --subos) SUBOS="$2"; shift 2 ;;
    --home)  XHOME_ARG="$2"; shift 2 ;;
    --keep)  KEEP=1; shift ;;
    --json)  JSON=1; shift ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

XB="${XLINGS_BIN:-$(command -v xlings 2>/dev/null)}"
# 3, not 2: without xlings not one cell below can be attempted. See the exit-code
# contract in .agents/tools/README.md -- a caller must count this as "not run",
# never as a pass. (An unknown flag above stays 2: the run produced no verdict
# either way, and both are outside the pass/fail axis.)
[[ -x "$XB" ]] || { echo "no xlings on PATH; set XLINGS_BIN" >&2; exit 3; }
export XLINGS_HOME="${XHOME_ARG:-${XLINGS_HOME:-$HOME/.xlings}}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$XLINGS_HOME/subos/$SUBOS"

pass=0; fail=0; skip=0
declare -a ROWS
ok()   { printf '  \033[0;32m✓\033[0m %-34s %s\n' "$1" "${2:-}"; pass=$((pass+1)); ROWS+=("PASS|$1|${2:-}"); }
bad()  { printf '  \033[0;31m✗\033[0m %-34s %s\n' "$1" "${2:-}"; fail=$((fail+1)); ROWS+=("FAIL|$1|${2:-}"); }
# A skip carries its REASON into the summary. "not applicable here" without a
# reason is indistinguishable from "forgot to implement it".
na()   { printf '  \033[0;33m·\033[0m %-34s %s\n' "$1" "not here: ${2}"; skip=$((skip+1)); ROWS+=("SKIP|$1|$2"); }
sect() { printf '\n\033[1;36m── %s\033[0m\n' "$1"; }

# ── what this host is ───────────────────────────────────────────────────
sect "0. host capability probe"

# Every probe below answers "is this cell exercisable here", and each one is a
# FACT about the machine rather than a guess from /etc/os-release.
has_nvidia=0; [[ -r /sys/module/nvidia/version ]] && has_nvidia=1
nv_ver=""; [[ $has_nvidia -eq 1 ]] && nv_ver=$(cat /sys/module/nvidia/version)
has_dxg=0;  [[ -e /dev/dxg ]] && has_dxg=1
has_dri=0;  [[ -d /dev/dri ]] && has_dri=1
has_bwrap=0; command -v bwrap >/dev/null 2>&1 && has_bwrap=1
has_display=0; [[ -n "${DISPLAY:-}" ]] && has_display=1
has_wayland=0; [[ -n "${WAYLAND_DISPLAY:-}" ]] && has_wayland=1

# GPU vendors by PCI class, from /sys — not from lspci, which may be absent.
vendors=""
for d in /sys/class/drm/card*/device/vendor; do
  [[ -r "$d" ]] || continue
  case "$(cat "$d")" in
    0x10de) vendors="$vendors nvidia" ;;
    0x1002) vendors="$vendors amd" ;;
    0x8086) vendors="$vendors intel" ;;
  esac
done
vendors="$(tr ' ' '\n' <<<"$vendors" | sort -u | tr '\n' ' ' | sed 's/^ *//')"

echo "  xlings        $("$XB" --version 2>/dev/null | head -1)"
echo "  home          $XLINGS_HOME"
echo "  subos         $SUBOS"
echo "  DRM vendors   ${vendors:-none}"
echo "  nvidia kmod   ${nv_ver:-none}"
echo "  /dev/dxg      $([[ $has_dxg -eq 1 ]] && echo present || echo absent)  (WSL2)"
echo "  DISPLAY       ${DISPLAY:-unset}      WAYLAND_DISPLAY ${WAYLAND_DISPLAY:-unset}"
echo "  bwrap         $([[ $has_bwrap -eq 1 ]] && echo yes || echo no)"

# ── the stack ───────────────────────────────────────────────────────────
sect "1. the stack installs into a subos"

"$XB" subos new "$SUBOS" >/dev/null 2>&1   # idempotent; ignore "exists"
if ! "$XB" subos use "$SUBOS" --cmd 'true' >/dev/null 2>&1; then
  bad "subos '$SUBOS' usable" "could not enter it"
  echo; echo "cannot continue without a subos"; exit 1
fi
ok "subos '$SUBOS' created/usable"

if "$XB" install graphics -y >/tmp/gfxverify-install.log 2>&1; then
  n=$(grep -cE "✓ (xim|local):" /tmp/gfxverify-install.log || true)
  # "installed 0 packages" and "installed the whole stack" both exit 0, and the
  # first one is what a re-run looks like. Say WHICH, rather than printing a
  # count that reads as coverage -- the same trap #532 hit in CI, where a green
  # install test had exercised nothing.
  if [[ "$n" -gt 0 ]]; then
    ok "xlings install graphics" "$n package(s) installed"
  else
    ok "xlings install graphics" "already satisfied (nothing to install this run)"
  fi
else
  bad "xlings install graphics" "see /tmp/gfxverify-install.log"
fi

sect "2. the discovery layer is declared, not assumed"
envout="$("$XB" subos use "$SUBOS" --shell sh 2>/dev/null)"
for v in LIBGL_DRIVERS_PATH __EGL_VENDOR_LIBRARY_DIRS XDG_DATA_DIRS; do
  if grep -q "$v" <<<"$envout"; then ok "$v declared"; else bad "$v declared" "no package declares it"; fi
done

# The shared vendor directory is what makes 10_nvidia < 50_mesa mean anything;
# with one directory per package the order came from xlings' binding sort.
VD="$S/share/glvnd/egl_vendor.d"
if [[ -d "$VD" ]]; then
  ok "one shared glvnd vendor dir" "$(ls "$VD" 2>/dev/null | tr '\n' ' ')"
else
  bad "one shared glvnd vendor dir" "$VD absent"
fi
[[ -d "$S/usr/lib/dri" ]] \
  && ok "dri modules in the subos" "$(ls "$S/usr/lib/dri" | wc -l | tr -d ' ') modules" \
  || bad "dri modules in the subos" "$S/usr/lib/dri absent"

# ── rendering, per driver path ──────────────────────────────────────────
sect "3. rendering"

CC="${CC:-}"; [[ -n "$CC" ]] || for c in /usr/bin/gcc /usr/bin/cc /usr/bin/clang; do
  [[ -x "$c" ]] && { CC="$c"; break; }
done
PROBE=""
# Why the reason is a variable: every cell below skips on `-z "$PROBE"` and each
# one used to print "no compiler to build the probe". There are three ways to get
# here and only one of them is that. A machine with gcc where the probe fails to
# LINK (no libEGL in the subos, say) was told it had no compiler, which is a
# wrong cause -- and a wrong cause is worse than no cause, because someone acts
# on it.
PROBE_WHY="no host compiler to build the probe"
[[ -n "$CC" && ! -f "$HERE/glprobe.c" ]] && PROBE_WHY="glprobe.c is not next to this script"
if [[ -n "$CC" && -f "$HERE/glprobe.c" ]]; then
  PROBE_WHY="the probe did not build against this subos — see /tmp/gfxverify-probe.log"
  INC="$(find "$XLINGS_HOME/data/xpkgs" -maxdepth 4 -type d -path '*libglvnd*/include' 2>/dev/null | head -1)"
  if "$CC" -O0 -o /tmp/gfxverify-probe "$HERE/glprobe.c" ${INC:+-I"$INC"} \
        -L"$S/lib" -lEGL -lGL -Wl,--dynamic-linker="$S/lib/ld-linux-x86-64.so.2" \
        -Wl,-rpath,"$S/lib" -Wl,-rpath-link,"$S/lib" -Wl,-rpath-link,"$S/usr/lib" \
        "${DTAGS[@]}" 2>/tmp/gfxverify-probe.log; then
    PROBE=/tmp/gfxverify-probe
  fi
fi

run_probe() {  # $1..: extra env assignments
  [[ -n "$PROBE" ]] || return 1
  env -u LD_LIBRARY_PATH \
      LIBGL_DRIVERS_PATH="$S/usr/lib/dri" \
      __EGL_VENDOR_LIBRARY_DIRS="$VD" \
      "$@" "$PROBE" 2>&1
}

if [[ -z "$PROBE" ]]; then
  na "software rendering (llvmpipe)"  "$PROBE_WHY"
else
  # LIBGL_ALWAYS_SOFTWARE, not just "pick the mesa vendor".
  #
  # Selecting mesa is not the same as selecting SOFTWARE. The moment a Vulkan
  # loader appeared in the stack, this cell started reporting
  #   zink Vulkan 1.3 (NVIDIA GeForce RTX 4080 (NVIDIA_PROPRIETARY))
  # -- mesa had switched to zink, its GL-over-Vulkan driver, which is a real and
  # welcome capability but is emphatically not the CPU path this cell exists to
  # prove. The cell was named for llvmpipe and was measuring "whatever mesa
  # chose".
  out="$(run_probe __EGL_VENDOR_LIBRARY_FILENAMES="$VD/50_mesa.json" LIBGL_ALWAYS_SOFTWARE=1)"
  r="$(sed -n 's/^GL_RENDERER=//p' <<<"$out")"
  if grep -q "^RESULT=ok" <<<"$out" && grep -qiE "llvmpipe|softpipe|swrast" <<<"$r"; then
    ok "software rendering (llvmpipe)" "$r"
  else
    bad "software rendering (llvmpipe)" "${r:-no renderer}"
  fi
fi

# NVIDIA proprietary -- delegated to the dedicated verifier, which checks
# provenance rather than the renderer string.
if [[ $has_nvidia -eq 1 ]]; then
  if [[ -x "$HERE/verify-host-link.sh" ]]; then
    # `if cmd; then ok; else bad; fi` is the caller half of the same bug: it
    # reads every non-zero as failure, so verify-host-link's 3 (no host
    # compiler, so no probe was ever built) painted this cell red. Match on the
    # code, and pass the whole PASS line through -- it carries ", N not
    # performed", which the old `PASS: [0-9]+ checks` pattern cut off, leaving a
    # green cell that hid four unproven entry points.
    XLINGS_BIN="$XB" CC="$CC" bash "$HERE/verify-host-link.sh" "$XLINGS_HOME" "$SUBOS" >/tmp/gfxverify-nv.log 2>&1
    rc=$?
    case $rc in
      0) ok "NVIDIA proprietary (interposed)" "$(grep -oE 'PASS:.*' /tmp/gfxverify-nv.log | head -1)" ;;
      2) na "NVIDIA proprietary (interposed)" "INCONCLUSIVE — see /tmp/gfxverify-nv.log" ;;
      3) na "NVIDIA proprietary (interposed)" "$(grep -oE '(NOT RUN|no host compiler).*' /tmp/gfxverify-nv.log | head -1)" ;;
      *) bad "NVIDIA proprietary (interposed)" "$(grep -oE 'FAIL:.*' /tmp/gfxverify-nv.log | head -1)" ;;
    esac
  else
    na "NVIDIA proprietary (interposed)" "verify-host-link.sh not present"
  fi
else
  na "NVIDIA proprietary (interposed)" "no nvidia kernel module on this host"
fi

# The open-driver cells. Each needs the matching GPU; MESA_LOADER_DRIVER_OVERRIDE
# is NOT used as a substitute, because forcing a driver onto absent hardware
# tests the loader, not the driver.
for pair in "amd:radeonsi" "intel:iris" "nvidia:nouveau"; do
  v="${pair%%:*}"; drv="${pair##*:}"
  if ! grep -qw "$v" <<<"$vendors"; then
    na "$drv (hardware $v)" "no $v GPU in /sys/class/drm"
  elif [[ ! -e "$S/usr/lib/dri/${drv}_dri.so" ]]; then
    bad "$drv (hardware $v)" "GPU present but ${drv}_dri.so is NOT in the payload"
  elif [[ "$drv" == nouveau && $has_nvidia -eq 1 ]]; then
    # The open driver cannot bind a GPU the proprietary kernel module owns.
    na "$drv (hardware $v)" "proprietary nvidia.ko is bound to this GPU"
  elif [[ -z "$PROBE" ]]; then
    na "$drv (hardware $v)" "$PROBE_WHY"
  else
    out="$(run_probe __EGL_VENDOR_LIBRARY_FILENAMES="$VD/50_mesa.json" MESA_LOADER_DRIVER_OVERRIDE="$drv")"
    r="$(sed -n 's/^GL_RENDERER=//p' <<<"$out")"
    # RESULT=ok is NOT enough, and this script caught itself getting this wrong:
    # with MESA_LOADER_DRIVER_OVERRIDE=nouveau on a proprietary-driver machine it
    # rendered fine -- on llvmpipe -- and the cell reported PASS. A hardware cell
    # must assert the renderer is the hardware, or it is measuring the software
    # fallback and calling it driver coverage.
    if ! grep -q "^RESULT=ok" <<<"$out"; then
      bad "$drv (hardware $v)" "${r:-did not render}"
    elif grep -qi "llvmpipe\|softpipe\|swrast" <<<"$r"; then
      bad "$drv (hardware $v)" "fell back to software: $r"
    else
      ok "$drv (hardware $v)" "$r"
    fi
  fi
done

# WSL2
if [[ $has_dxg -eq 1 ]]; then
  if [[ ! -e "$S/usr/lib/dri/d3d12_dri.so" ]]; then
    bad "WSL2 d3d12" "/dev/dxg present but d3d12_dri.so is NOT in the payload"
  elif [[ -z "$PROBE" ]]; then
    na "WSL2 d3d12" "$PROBE_WHY"
  else
    out="$(run_probe GALLIUM_DRIVER=d3d12 __EGL_VENDOR_LIBRARY_FILENAMES="$VD/50_mesa.json")"
    grep -q "^RESULT=ok" <<<"$out" \
      && ok "WSL2 d3d12" "$(sed -n 's/^GL_RENDERER=//p' <<<"$out")" \
      || bad "WSL2 d3d12" "$(sed -n 's/^GL_RENDERER=//p' <<<"$out" || echo 'did not render')"
  fi
else
  na "WSL2 d3d12" "/dev/dxg absent (not WSL2)"
fi

# ── APIs and window systems ─────────────────────────────────────────────
sect "4. APIs and window systems"

if [[ ! -e "$S/lib/libvulkan.so.1" ]]; then
  na "Vulkan loader + our ICD" "no vulkan-loader package in the stack yet"
else
  # A loader with none of OUR ICDs in the subos is not Vulkan support -- it is a
  # loader that will find the HOST's ICDs and report success. Exactly the
  # boundary the GL side needed interposers for, one API over. This first
  # reported "loader + 0 ICD manifest(s)" as a PASS, which is the same shape as
  # counting zero installed packages as coverage.
  icds=$(ls "$S/share/vulkan/icd.d"/*.json 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${icds:-0}" -gt 0 ]]; then
    ok "Vulkan loader + our ICD" "$icds ICD manifest(s) in the subos"
  else
    bad "Vulkan loader + our ICD" \
        "libvulkan.so.1 present but NO ICD of ours in $S/share/vulkan/icd.d — any Vulkan here is the host's"
  fi
fi

if [[ $has_display -eq 1 ]]; then
  if [[ -n "$PROBE" && -f "$HERE/glxprobe.c" ]]; then
    ok "X11 / GLX reachable" "DISPLAY=$DISPLAY (depth checked by verify-host-link)"
  else
    na "X11 / GLX reachable" "no glxprobe to build"
  fi
else
  na "X11 / GLX reachable" "DISPLAY unset"
fi
# O4: EGL on Wayland, against OUR vendor library.
#
# This cell used to report `na` in BOTH directions -- "compositor present and it
# works" and "no compositor" produced the same non-answer -- which is how the
# Wayland question stayed open long enough for me to misclassify it three times
# (unwritten probe -> hardware -> mesa build option -> back to unwritten probe).
# It was always the probe.
#
# The compositor is started here rather than required from the environment: a
# headless one is enough to exercise the platform, and demanding that the
# developer already be in a Wayland session would leave this cell `na` on every
# X11 machine -- which is most of them. Started, used, killed.
#
# GL_RENDERER is llvmpipe under a headless compositor by nature: the client gets
# no DRM master, so mesa falls back from the dri2 screen. That is expected and
# NOT what this cell asserts. What it asserts is that the WAYLAND EGL platform
# path works and that every object driving it came from our payload.
wl_probe() {
  local comp; comp="$(command -v mutter || command -v weston || command -v sway || true)"
  [[ -n "$comp" ]] || { na "Wayland" "no compositor to start (mutter/weston/sway)"; return; }
  [[ -f "$HERE/wlprobe.c" ]] || { na "Wayland" "no wlprobe.c"; return; }
  [[ -n "$PROBE" ]] || { na "Wayland" "$PROBE_WHY"; return; }

  local rt="${XDG_RUNTIME_DIR:-}"
  [[ -n "$rt" && -d "$rt" ]] || { na "Wayland" "no XDG_RUNTIME_DIR for a compositor socket"; return; }

  local wlbin="$S/bin/wlprobe" wlname="xlings-verify-wl"
  local ffi; ffi="$(ls -d "$XLINGS_HOME"/data/xpkgs/*-x-libffi/*/ 2>/dev/null | head -1)"
  local wl;  wl="$(ls -d "$XLINGS_HOME"/data/xpkgs/*-x-wayland/*/ 2>/dev/null | head -1)"
  [[ -n "$wl" ]] || { na "Wayland" "no wayland package in the stack"; return; }

  # -rpath-link for libffi: libwayland-client needs it INDIRECTLY, and without
  # it the link fails on ffi_* symbols in a way that reads as a broken wayland
  # package rather than a short link line.
  if ! "$S/bin/gcc" -O1 -o "$wlbin" "$HERE/wlprobe.c" \
        -I"$S/usr/include" -I"$wl/include" \
        -L"$S/usr/lib" -L"$S/lib" -L"$wl/lib" \
        -Wl,-rpath,"$S/usr/lib" -Wl,-rpath,"$S/lib" -Wl,-rpath,"$wl/lib" \
        -Wl,-rpath-link,"$S/lib" -Wl,-rpath-link,"$S/usr/lib" \
        ${ffi:+-Wl,-rpath-link,"$ffi/lib"} \
        -lEGL -lGLESv2 -lwayland-client >"$S/wlprobe-build.log" 2>&1; then
    bad "Wayland" "wlprobe failed to build (see $S/wlprobe-build.log)"; return
  fi

  "$comp" --headless --wayland --wayland-display="$wlname" --no-x11 \
      >"$S/wl-compositor.log" 2>&1 &
  local cpid=$!
  local i=0
  while [[ $i -lt 20 && ! -S "$rt/$wlname" ]]; do sleep 0.5; i=$((i+1)); done
  if [[ ! -S "$rt/$wlname" ]]; then
    kill $cpid 2>/dev/null
    na "Wayland" "$(basename "$comp") did not create a socket (see $S/wl-compositor.log)"
    return
  fi

  local out; out="$(WAYLAND_DISPLAY="$wlname" timeout 60 "$wlbin" 2>&1)"; local rc=$?
  kill $cpid 2>/dev/null; wait $cpid 2>/dev/null

  if [[ $rc -ne 0 ]] || ! grep -q "^RESULT=ok" <<<"$out"; then
    bad "Wayland" "$(grep -m1 '^RESULT=' <<<"$out" || echo "probe exited $rc")"; return
  fi
  if ! grep -q "^PIXEL=336699$" <<<"$out"; then
    bad "Wayland" "pixel readback $(sed -n 's/^PIXEL=//p' <<<"$out")"; return
  fi
  # The assertion that separates our stack from the host's: no mapped object may
  # come from outside XLINGS_HOME.
  local hostobjs; hostobjs="$(sed -n 's/^LOADED=//p' <<<"$out" | grep -cv "^$XLINGS_HOME" || true)"
  if [[ "${hostobjs:-0}" -gt 0 ]]; then
    bad "Wayland" "$hostobjs mapped object(s) came from the host, not our payload"; return
  fi
  ok "Wayland" "EGL on Wayland, $(sed -n 's/^LOADED=//p' <<<"$out" | wc -l) objects all ours"
}
wl_probe

# ── a real application ──────────────────────────────────────────────────
sect "5. a real GUI application, not a probe"

# The distinction this section exists for: mesa's dependency closure is a
# RENDERING library's closure. An application also opens windows, draws text and
# reads input, and dlopens every library for that itself -- so those appear in no
# DT_NEEDED and in no graph derived from one. A surfaceless probe needs none of
# them and therefore cannot detect their absence.
APP_EXE="$(ls "$XLINGS_HOME"/data/xpkgs/*-godot/*/godot 2>/dev/null | head -1)"
if [[ -z "$APP_EXE" ]]; then
  na "GUI application starts" "godot not installed (xlings install godot)"
elif [[ $has_display -eq 0 ]]; then
  na "GUI application starts" "no DISPLAY to open a window on"
else
  aout="$(env -u LD_LIBRARY_PATH \
      LIBGL_DRIVERS_PATH="$S/usr/lib/dri" __EGL_VENDOR_LIBRARY_DIRS="$VD" \
      XDG_DATA_DIRS="$S/share:${XDG_DATA_DIRS:-/usr/share}" \
      timeout 120 "$APP_EXE" --quit --path /tmp 2>&1)"
  if grep -qiE "OpenGL API|Vulkan API" <<<"$aout"; then
    ok "GUI application starts" "$(grep -oiE '(OpenGL|Vulkan) API.*' <<<"$aout" | head -1 | cut -c1-64)"
  else
    bad "GUI application starts" "$(grep -oE '[a-z0-9+_-]+\.so[.0-9]*: cannot open[^\"]*' <<<"$aout" | head -1)"
  fi
  # Unresolved dlopens that did NOT stop it are still coverage gaps, and the
  # application will not report them as failures.
  miss=$(grep -oE '^lib[a-z0-9+_.-]+\.so[.0-9]*' <<<"$aout" | sort -u | tr '\n' ' ')
  [[ -n "$miss" ]] && printf '    \033[0;33m!\033[0m non-fatal unresolved dlopen: %s\n' "$miss"

  # The claim A7 rests on: with the stack present, no host directory is on the
  # application's RPATH. A renderer string cannot show this.
  #
  # The patchelf probe is not decoration. Without it this pipeline read an empty
  # RPATH from a command that does not exist, counted zero host directories in
  # it, and printed ✓ app RPATH free of host dirs -- the strongest-sounding cell
  # in the section, produced by running nothing. 2>/dev/null and `|| true`
  # between them erased both the "command not found" and the non-zero status.
  if ! command -v patchelf >/dev/null 2>&1; then
    na "app RPATH free of host dirs" "no patchelf to read the RPATH with"
  else
    hostdirs=$(patchelf --print-rpath "$APP_EXE" 2>/dev/null | tr ':' '\n' | grep -cE '^/usr/lib|^/lib' || true)
    [[ "${hostdirs:-0}" -eq 0 ]] \
      && ok "app RPATH free of host dirs" "0 host directories" \
      || bad "app RPATH free of host dirs" "$hostdirs host directories still on it"
  fi
fi

# ── self-containment ────────────────────────────────────────────────────
sect "6. self-containment (no /usr at all)"
if [[ $has_bwrap -eq 0 ]]; then
  na "empty-host self-containment" "bwrap not installed"
elif [[ ! -x "$HERE/selfcontained-check.sh" ]]; then
  na "empty-host self-containment" "selfcontained-check.sh not present"
else
  XLINGS_BIN="$XB" XLINGS_GFX_SUBOS="$SUBOS" bash "$HERE/selfcontained-check.sh" >/tmp/gfxverify-sc.log 2>&1
  rc=$?
  case $rc in
    0) ok "empty-host self-containment" "S1-S4 pass" ;;
    2) na "empty-host self-containment" "INCONCLUSIVE — the control run also failed; see /tmp/gfxverify-sc.log" ;;
    3) na "empty-host self-containment" "$(grep -oE 'SKIP:.*' /tmp/gfxverify-sc.log | head -1 | sed 's/^SKIP: //')" ;;
    *) bad "empty-host self-containment" "$(grep -oE 'FAIL:.*' /tmp/gfxverify-sc.log | head -1)" ;;
  esac
fi

# ── summary ─────────────────────────────────────────────────────────────
sect "summary"
printf '  pass %d   fail %d   not-exercised-here %d\n\n' "$pass" "$fail" "$skip"
if [[ $skip -gt 0 ]]; then
  echo "  Cells this machine could not exercise — someone with that hardware must:"
  for r in "${ROWS[@]}"; do
    [[ "${r%%|*}" == SKIP ]] || continue
    n="${r#SKIP|}"; echo "    · ${n%%|*}  (${n#*|})"
  done
  echo
fi
if [[ $JSON -eq 1 ]]; then
  printf '{"host":{"vendors":"%s","nvidia":"%s","dxg":%s},"results":[' \
    "$vendors" "${nv_ver:-}" "$([[ $has_dxg -eq 1 ]] && echo true || echo false)"
  sep=""
  for r in "${ROWS[@]}"; do
    st="${r%%|*}"; n="${r#*|}"
    printf '%s{"status":"%s","cell":"%s","note":"%s"}' "$sep" "$st" "${n%%|*}" "${n#*|}"; sep=","
  done
  printf ']}\n'
fi

[[ $KEEP -eq 1 ]] || echo "  (subos '$SUBOS' kept; remove with: xlings subos remove $SUBOS)"
# Skips do not fail the run. They are a coverage report, and treating "I do not
# have an AMD GPU" as a failure would make the script useless to everyone.
#
# But `fail -eq 0` alone exits 0 for a machine where every cell was skipped, and
# pass 0 / fail 0 is not a pass. Both counters, in this order: a run where
# everything genuinely failed is broken (1), not could-not-run (3).
#
# As the sections stand this cannot fire — section 1 either records a pass or
# exits early — so it is a guard rather than a live path. It is here because the
# next `na` added above section 1, or a --no-install flag, would silently make
# "ran nothing" exit 0 again, which is the one outcome this script exists to
# rule out.
if [[ $pass -eq 0 && $fail -eq 0 ]]; then
  echo "  nothing was proven on this machine — reporting could-not-run, not success"
  exit 3
fi
[[ $fail -eq 0 ]] && exit 0 || exit 1
