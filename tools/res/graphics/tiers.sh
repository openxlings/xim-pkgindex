#!/usr/bin/env bash
# The graphics-stack build order, as data.
#
# Design: xlings/.agents/docs/2026-08-05-graphics-stack-ecosystem-closure.md §4
#
# Order is a dependency order, not a preference: libXau's headers come from
# xorgproto, libxcb's protocol descriptions from xcb-proto, libX11 from libxcb,
# and mesa from all of it. Building out of order fails at configure — which is
# the intended behaviour, since PKG_CONFIG_LIBDIR points only at the subos and
# a missing dependency cannot be silently satisfied by the host.
#
# Usage:  tiers.sh [T0|T1|T2|T3|T4|T5|all] [--to <name>] [--skip '<names>']
#
#   --to    stop once <name> is built: res-build builds a package with
#           everything before it, in one SubOS (tools/res/graphics/res.sh)
#   --skip  leave these out (what the package asked for does not need them)
#
# The architecture is the SubOS's (arch.sh). Where the two differ, this file
# says so: T0 and libllvm are built here only on aarch64, and mesa's drivers
# are not the same set (T5).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$HERE/build-in-subos.sh"
SUBOS="${XLINGS_HOME:-$HOME/.xlings}/subos/${XLINGS_GFX_SUBOS:-gfxbuild}"
# shellcheck source=arch.sh
. "$HERE/arch.sh"
ARCH="$(subos_arch "$SUBOS")" || exit 3

# T0 -- what x86_64 takes from the index (expat and libffi there are repacks
# of a distribution's builds) and aarch64 builds, from upstream's release.
# libffi 3.4.4 makes libffi.so.8 alone; x86_64's repack also carries the .so.7
# of libffi 3.3, which nothing in this stack links.
T0=(
  "expat|2.6.2|https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.xz|autotools|--without-docbook --without-examples --without-tests"
  "libffi|3.4.4|https://github.com/libffi/libffi/releases/download/v3.4.4/libffi-3.4.4.tar.gz|autotools|--disable-docs --disable-multi-os-directory"
)

# name|version|url|system|extra-args
T1=(
  "xorgproto|2024.1|https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2024.1.tar.xz|meson|"
  "xcb-proto|1.17.0|https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-1.17.0.tar.xz|autotools|"
  # xtrans is macros and headers only — no library is produced. libX11's
  # configure demands it by pkg-config name, so it is build-time but not
  # optional, and it is easy to leave out of a tier list derived from a
  # runtime closure: nothing loads it, so `strace` never sees it.
  "xtrans|1.5.2|https://xorg.freedesktop.org/archive/individual/lib/xtrans-1.5.2.tar.xz|autotools|"
  "libpciaccess|0.18.1|https://xorg.freedesktop.org/archive/individual/lib/libpciaccess-0.18.1.tar.xz|meson|"
  "libdrm|2.4.123|https://dri.freedesktop.org/libdrm/libdrm-2.4.123.tar.xz|meson|-Dintel=enabled -Dradeon=enabled -Damdgpu=enabled -Dnouveau=enabled -Dvalgrind=disabled -Dman-pages=disabled -Dtests=false"
  "libxshmfence|1.3.2|https://xorg.freedesktop.org/archive/individual/lib/libxshmfence-1.3.2.tar.xz|autotools|"
)

# libXtst and alsa-lib are here for the JDK, not for graphics: `libawt_xawt.so`
# has a hard DT_NEEDED on libXtst.so.6 and `libjsound.so` on libasound.so.2, and a
# PT_INTERP switch to our loader removes all host fallback -- so the JDK cannot be
# switched until its whole closure is ours (openxlings/xim-pkgindex#568).
#
# libXtst needs libXfixes AT BUILD TIME ONLY: `xi.pc` carries `Requires: xfixes`,
# and leaving it out of --deps fails configure with `Package 'xfixes', required by
# 'xi', not found` -- an error naming neither libXtst nor libXi. The payload does
# not link it, so the recipe does not declare it.
T2=(
  "alsa-lib|1.2.11|https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.11.tar.bz2|autotools|--disable-python --disable-topology --disable-ucm"
  "libXau|1.0.11|https://xorg.freedesktop.org/archive/individual/lib/libXau-1.0.11.tar.xz|autotools|"
  "libXdmcp|1.1.5|https://xorg.freedesktop.org/archive/individual/lib/libXdmcp-1.1.5.tar.xz|autotools|"
  "libxcb|1.17.0|https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz|autotools|"
  "libX11|1.8.10|https://xorg.freedesktop.org/archive/individual/lib/libX11-1.8.10.tar.xz|autotools|"
  "libXext|1.3.6|https://xorg.freedesktop.org/archive/individual/lib/libXext-1.3.6.tar.xz|autotools|"
  "libXrender|0.9.11|https://xorg.freedesktop.org/archive/individual/lib/libXrender-0.9.11.tar.xz|autotools|"
  "libXfixes|6.0.1|https://xorg.freedesktop.org/archive/individual/lib/libXfixes-6.0.1.tar.xz|autotools|"
  "libXrandr|1.5.4|https://xorg.freedesktop.org/archive/individual/lib/libXrandr-1.5.4.tar.xz|autotools|"
  "libXxf86vm|1.1.6|https://xorg.freedesktop.org/archive/individual/lib/libXxf86vm-1.1.6.tar.xz|autotools|"
  "libXi|1.8.2|https://xorg.freedesktop.org/archive/individual/lib/libXi-1.8.2.tar.xz|autotools|"
  "libXcursor|1.2.3|https://xorg.freedesktop.org/archive/individual/lib/libXcursor-1.2.3.tar.xz|autotools|"
  # Last: what it needs is above it, so a run that builds T2 whole has it.
  "libXtst|1.2.5|https://xorg.freedesktop.org/archive/individual/lib/libXtst-1.2.5.tar.xz|autotools||xorgproto libX11 libXext libXi libXfixes libXau libXdmcp libxcb libXrender"
)

T3=(
  "wayland|1.23.1|https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.1/downloads/wayland-1.23.1.tar.xz|meson|-Ddocumentation=false -Dtests=false|libxml2 expat"
  # 1.45: what mesa 25.0.7.2 and .3 were built against (build-wayland-protocols.sh).
  "wayland-protocols|1.45|https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.45/downloads/wayland-protocols-1.45.tar.xz|meson|-Dtests=false"
  "libxkbcommon|1.7.0|https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz|meson|-Denable-docs=false -Denable-wayland=false -Denable-xkbregistry=false"
)

# T4 — the graphics core. libglvnd first: it is the vendor-neutral dispatch
# layer, so it must exist before mesa is built as a *vendor* rather than as a
# libGL replacement. That is what lets the mesa and NVIDIA paths coexist later.
T4=(
  # elfutils, for its libelf alone: radeonsi links it to read the ELF that
  # LLVM's AMDGPU backend emits for a shader. `--disable-debuginfod` and
  # `--without-*` keep the rest of elfutils — the debuginfo tooling — out of a
  # payload that exists to satisfy one dependency.
  "elfutils|0.191|https://sourceware.org/elfutils/ftp/0.191/elfutils-0.191.tar.bz2|autotools|--disable-debuginfod --disable-libdebuginfod --without-bzlib --without-lzma --without-zstd --disable-nls --program-prefix=eu- CFLAGS=-Wno-error"
  # glslang: mesa's Vulkan drivers compile built-in shaders at build time and
  # meson looks for `glslangValidator` by name. ENABLE_OPT=OFF keeps
  # SPIRV-Tools out of the picture — that optimiser is for glslang's own
  # command line, and mesa does not ask for it.
  "glslang|15.1.0|https://github.com/KhronosGroup/glslang/archive/refs/tags/15.1.0.tar.gz|cmake|-DENABLE_OPT=OFF -DGLSLANG_TESTS=OFF -DENABLE_CTEST=OFF"
  "libglvnd|1.7.0|https://gitlab.freedesktop.org/glvnd/libglvnd/-/archive/v1.7.0/libglvnd-v1.7.0.tar.gz|meson|-Dgles1=false -Dasm=enabled"
)

# ── T4b — the four packages that are NOT built by this file ─────────────
#
# Each has its own script because each needs something run_tier() cannot express.
# They are listed here so the build order is readable in one place.
#
#   llvm-dev           build-llvm-dev.sh           three cmake projects in
#                                                  sequence (llvm+clang, the
#                                                  SPIR-V translator, libclc),
#                                                  each consuming the last
#   spirv-tools        build-spirv-tools.sh        SPIRV-Headers at the revision
#                                                  SPIRV-Tools' own DEPS pins,
#                                                  then SPIRV-Tools; static only
#   directx-headers    build-directx-headers.sh    its whole Linux install is two
#                                                  static_library() calls, so meson
#                                                  buys nothing here
#   meson              build-meson.sh              pure Python; a repack, not a
#                                                  build (#562)
#   wayland-protocols  build-wayland-protocols.sh  data only; no compiler runs
#
# llvm-dev, spirv-tools and directx-headers are `status = "dev"`; wayland-protocols
# was already `stable` and stays that way.
#
# Both directx-headers and wayland-protocols were HOST INPUTS to the shipped mesa
# 25.0.7.1 -- but for two different reasons, and the second is the instructive one:
#
#   directx-headers    genuinely absent. Built once into /tmp and never packaged;
#                      that ad-hoc build's log shows
#                      `Found pkg-config: /usr/bin/pkg-config`.
#
#   wayland-protocols  ALREADY PACKAGED at 1.38 and published in both regions
#                      since 2026-08-05 -- and still unused. It was never
#                      installed in the home mesa was built in, and the T5 line
#                      below named it in neither `--deps` nor the extra pkgconfig
#                      path, so the host's copy answered instead.
#
# The second is the harder failure to see, because nothing is missing: the recipe
# is right, the payload is right, the runtime probe passes 7/7. Only the WIRING
# was absent, and an unwired build-time input is indistinguishable from a
# satisfied one unless somebody looks at what the build consumed.

# T5 — mesa. Everything above exists to make this line possible.
#
# gallium-drivers is the four hardware targets the design commits to:
# llvmpipe (CPU), iris (Intel), radeonsi (AMD), nouveau (NVIDIA-open), plus
# zink for Vulkan-on-GL. vulkan-drivers mirrors it.
#
# -Dglvnd=enabled is the load-bearing one: it makes mesa build as a libglvnd
# *vendor* (libGLX_mesa/libEGL_mesa) rather than as a libGL replacement, which
# is what lets the NVIDIA proprietary vendor sit alongside it in one subos.
#
# lmsensors is off — it only feeds a GPU temperature query, and enabling it
# would add another package to the tier list for a HUD readout.
#
# The staged-driver notes that used to sit here are gone because both stages
# happened: llvmpipe-only widened to five drivers, and vulkan-drivers went from
# empty to `amd` once glslang was packaged. iris and d3d12 are the last two, and
# each needed a package that did not exist:
#
#   iris   -> with_gallium_iris implies with_clc (meson.build:841), so
#             dependency('libclc') + LLVMSPIRVLib + clang-cpp  ->  llvm-dev
#   d3d12  -> dependency('DirectX-Headers') (meson.build:606)  ->  directx-headers
#
# ── THE DEPS FIELD, AND WHY IT WAS WRONG ────────────────────────────────
#
# This entry used to read `libxml2 expat`. That cannot be what built mesa:
# `--deps` is the ONLY mechanism that puts a package's .pc where pkg-config can
# see it, and measured 2026-08-08 no subos sysroot farm in this home -- including
# the one mesa was built in -- contains libglvnd.pc, libdrm.pc, x11.pc or any of
# the other twenty. Re-running this line as recorded stops at
#
#   meson.build:583:12: ERROR: Dependency "libglvnd" not found
#
# So the recorded command was not the command. The full list is spelled out now,
# because a build recipe that does not reproduce the build is worse than no
# recipe: it costs the next person the same afternoon and looks authoritative.
#
# libxml2 IS in the list, and my first version of this comment said it "was not
# needed" -- wrong, and wrong in the same way as the list it was correcting.
#
# mesa's own codegen does not use it (that is python now). `wayland-scanner` does:
# the wayland payload's bin/wayland-scanner has DT_NEEDED on libxml2.so.2 and
# libexpat.so.1, and pkgs/w/wayland.lua declared neither until this branch. So the
# dependency is real but it belongs to a BUILD TOOL from another package, which is
# why reading mesa's build files could not find it -- it surfaced 1957 targets in,
# with an error naming neither wayland nor mesa.
T5_x86_64=(
  "mesa|25.0.7|https://archive.mesa3d.org/mesa-25.0.7.tar.xz|meson|-Dgallium-drivers=llvmpipe,softpipe,radeonsi,nouveau,zink,iris,d3d12,virgl -Dvulkan-drivers=amd -Dglvnd=enabled -Dplatforms=x11,wayland -Dllvm=enabled -Dshared-llvm=enabled -Dmesa-clc=enabled -Dgallium-d3d12-video=disabled -Dlmsensors=disabled -Dvalgrind=disabled -Dbuild-tests=false -Dgallium-extra-hud=false|llvm-dev spirv-tools directx-headers wayland-protocols glslang libglvnd libdrm libX11 libxcb libXext libXfixes libXxf86vm libxshmfence wayland zlib expat elfutils xorgproto libpciaccess libXrandr libXau libXdmcp libXrender"
)

# 25.0.7.3 (virgl added) was built with the four build-only inputs in --deps as
# well: their bin/ goes on PATH, and mesa takes `llvm-config` from PATH -- the
# host's (LLVM 18) answered otherwise. Not with xim:libllvm installed in the
# subos: its libLLVM.so.20.1 (no SPIR-V target) is ahead of llvm-dev's on the
# build tools' RPATH, and mesa_clc fails on LLVMInitializeSPIRVTarget.
#
# The three build-only inputs mesa needs that are NOT --deps, because a
# `status = "dev"` package deliberately stages nothing into the sysroot:
#
#   XLINGS_GFX_PKGCONFIG_EXTRA=<llvm-dev>/lib/pkgconfig:<llvm-dev>/share/pkgconfig:<dxh>/share/pkgconfig:<wl-protocols>/share/pkgconfig
#
# BOTH llvm-dev directories, and that is not redundancy: libclc.pc is in
# share/pkgconfig and LLVMSPIRVLib.pc is in lib/pkgconfig. Naming only the first
# gets `libclc found: YES` followed by `Dependency "LLVMSPIRVLib" not found`,
# which reads like a broken package rather than a missing path.

# aarch64 (xlings design 2026-11-27 §5.8): the drivers a CPU and the GPUs an
# aarch64 machine takes through PCIe or virtio need. No iris (Intel's GPUs are
# on x86 alone) and no d3d12, so no clc chain: llvm-dev, spirv-tools and
# directx-headers are not inputs, mesa_clc is not built, and LLVM is libllvm
# itself (the L step below), staged whole into the SubOS for the build. The ARM
# SoC drivers (freedreno, panfrost, v3d, etnaviv, lima, asahi) wait for
# hardware to verify them on.
T5_aarch64=(
  "mesa|25.0.7|https://archive.mesa3d.org/mesa-25.0.7.tar.xz|meson|-Dgallium-drivers=llvmpipe,softpipe,virgl,zink,radeonsi,nouveau -Dvulkan-drivers=amd -Dglvnd=enabled -Dplatforms=x11,wayland -Dllvm=enabled -Dshared-llvm=enabled -Dlmsensors=disabled -Dvalgrind=disabled -Dbuild-tests=false -Dgallium-extra-hud=false|zlib"
)

TO="" SKIP="" BUILT=" " DONE=0

run_tier() {  # <tier-name> <entries...>
    local tier="$1"; shift
    local entry name version url system extra deps d
    for entry in "$@"; do
        [[ $DONE -eq 1 ]] && return 0
        # The sixth field is optional: xlings packages whose payload is a build
        # dependency but which do not stage themselves into the subos sysroot.
        # See build-in-subos.sh --deps.
        IFS='|' read -r name version url system extra deps <<<"$entry"
        [[ " $SKIP " == *" $name "* ]] && continue
        echo "── $tier :: $name $version ──────────────────────────────"
        local args=(--name "$name" --version "$version" --url "$url"
                    --system "$system")
        # A dependency this run built is staged into the subos already;
        # --deps names what xlings installed.
        local kept=""
        for d in ${deps:-}; do [[ "$BUILT" == *" $d "* ]] || kept="$kept $d"; done
        [[ -n "$kept" ]] && args+=(--deps "${kept# }")
        # `|| return $?`, not `|| return 1`: this is a pass-through, and
        # rewriting the child's status to 1 erases the difference between "the
        # build broke" and "this machine could not start it" (exit 3, see
        # .agents/tools/README.md). The tier still stops either way.
        # shellcheck disable=SC2086
        if [[ -n "$extra" ]]; then
            bash "$BUILD" "${args[@]}" -- $extra || return $?
        else
            bash "$BUILD" "${args[@]}" || return $?
        fi
        BUILT="$BUILT$name "
        [[ "$name" == "$TO" ]] && DONE=1
    done
    return 0
}

# L -- libllvm, built and staged whole (headers, llvm-config) for mesa.
run_llvm() {
    [[ $DONE -eq 1 || " $SKIP " == *" libllvm "* ]] && return 0
    echo "── L :: libllvm 20.1.7 ──────────────────────────────"
    bash "$HERE/build-libllvm.sh" 20.1.7 || return $?
    BUILT="${BUILT}libllvm "
    [[ "$TO" == libllvm ]] && DONE=1
    return 0
}

WHICH="${1:-all}"; shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to)   TO="$2"; shift 2 ;;
    --skip) SKIP="$2"; shift 2 ;;
    *)      echo "usage: $0 [T0|T1|T2|T3|T4|T5|all] [--to <name>] [--skip '<names>']" >&2; exit 2 ;;
  esac
done
T5_name="T5_$ARCH[@]"; T5=("${!T5_name}")
case "$WHICH" in
  T0)  run_tier T0 "${T0[@]}" ;;
  T1)  run_tier T1 "${T1[@]}" ;;
  T2)  run_tier T2 "${T2[@]}" ;;
  T3)  run_tier T3 "${T3[@]}" ;;
  T4)  run_tier T4 "${T4[@]}" ;;
  T5)  run_tier T5 "${T5[@]}" ;;
  # T3 too: mesa's wayland platform is built against it.
  all) { [[ "$ARCH" == x86_64 ]] || run_tier T0 "${T0[@]}"; } \
         && run_tier T1 "${T1[@]}" && run_tier T2 "${T2[@]}" \
         && run_tier T3 "${T3[@]}" && run_tier T4 "${T4[@]}" \
         && { [[ "$ARCH" == x86_64 ]] || run_llvm; } \
         && run_tier T5 "${T5[@]}" ;;
  *)   echo "usage: $0 [T0|T1|T2|T3|T4|T5|all] [--to <name>] [--skip '<names>']" >&2; exit 2 ;;
esac
status=$?
[[ $status -ne 0 || -z "$TO" || $DONE -eq 1 ]] || { echo "tiers.sh: $TO is in no tier run for $ARCH" >&2; exit 2; }
exit $status
