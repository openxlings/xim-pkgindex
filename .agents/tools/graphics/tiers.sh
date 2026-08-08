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
# Usage:  tiers.sh [T1|T2|T3|T4|all] [--from <name>]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$HERE/build-in-subos.sh"

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

T2=(
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
)

T3=(
  "wayland|1.23.1|https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.1/downloads/wayland-1.23.1.tar.xz|meson|-Ddocumentation=false -Dtests=false|libxml2 expat"
  "wayland-protocols|1.38|https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.38/downloads/wayland-protocols-1.38.tar.xz|meson|-Dtests=false"
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
#   directx-headers    build-directx-headers.sh    no meson in this index (#562),
#                                                  and its whole Linux install is
#                                                  two static_library() calls
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
T5=(
  "mesa|25.0.7|https://archive.mesa3d.org/mesa-25.0.7.tar.xz|meson|-Dgallium-drivers=llvmpipe,softpipe,radeonsi,nouveau,zink,iris,d3d12 -Dvulkan-drivers=amd -Dglvnd=enabled -Dplatforms=x11,wayland -Dllvm=enabled -Dshared-llvm=enabled -Dmesa-clc=enabled -Dgallium-d3d12-video=disabled -Dlmsensors=disabled -Dvalgrind=disabled -Dbuild-tests=false -Dgallium-extra-hud=false|glslang libglvnd libdrm libX11 libxcb libXext libXfixes libXxf86vm libxshmfence wayland zlib expat elfutils xorgproto libpciaccess libXrandr libXau libXdmcp libXrender"
)

# The three build-only inputs mesa needs that are NOT --deps, because a
# `status = "dev"` package deliberately stages nothing into the sysroot:
#
#   XLINGS_GFX_PKGCONFIG_EXTRA=<llvm-dev>/lib/pkgconfig:<llvm-dev>/share/pkgconfig:<dxh>/share/pkgconfig:<wl-protocols>/share/pkgconfig
#
# BOTH llvm-dev directories, and that is not redundancy: libclc.pc is in
# share/pkgconfig and LLVMSPIRVLib.pc is in lib/pkgconfig. Naming only the first
# gets `libclc found: YES` followed by `Dependency "LLVMSPIRVLib" not found`,
# which reads like a broken package rather than a missing path.

run_tier() {  # <tier-name> <entries...>
    local tier="$1"; shift
    local entry name version url system extra deps
    for entry in "$@"; do
        # The sixth field is optional: xlings packages whose payload is a build
        # dependency but which do not stage themselves into the subos sysroot.
        # See build-in-subos.sh --deps.
        IFS='|' read -r name version url system extra deps <<<"$entry"
        echo "── $tier :: $name $version ──────────────────────────────"
        local args=(--name "$name" --version "$version" --url "$url"
                    --system "$system")
        [[ -n "${deps:-}" ]] && args+=(--deps "$deps")
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
    done
}

WHICH="${1:-all}"
case "$WHICH" in
  T1)  run_tier T1 "${T1[@]}" ;;
  T2)  run_tier T2 "${T2[@]}" ;;
  T3)  run_tier T3 "${T3[@]}" ;;
  T4)  run_tier T4 "${T4[@]}" ;;
  T5)  run_tier T5 "${T5[@]}" ;;
  all) run_tier T1 "${T1[@]}" && run_tier T2 "${T2[@]}" \
         && run_tier T4 "${T4[@]}" && run_tier T5 "${T5[@]}" ;;
  *)   echo "usage: $0 [T1|T2|T3|all]" >&2; exit 2 ;;
esac
