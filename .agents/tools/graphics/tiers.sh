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
  "wayland|1.23.1|https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.1/downloads/wayland-1.23.1.tar.xz|meson|-Ddocumentation=false -Dtests=false"
  "wayland-protocols|1.38|https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.38/downloads/wayland-protocols-1.38.tar.xz|meson|-Dtests=false"
  "libxkbcommon|1.7.0|https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz|meson|-Denable-docs=false -Denable-wayland=false -Denable-xkbregistry=false"
)

# T4 — the graphics core. libglvnd first: it is the vendor-neutral dispatch
# layer, so it must exist before mesa is built as a *vendor* rather than as a
# libGL replacement. That is what lets the mesa and NVIDIA paths coexist later.
T4=(
  "libglvnd|1.7.0|https://gitlab.freedesktop.org/glvnd/libglvnd/-/archive/v1.7.0/libglvnd-v1.7.0.tar.gz|meson|-Dgles1=false -Dasm=enabled"
)

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
# gallium-drivers is llvmpipe ONLY for this first pass. iris pulls in libclc
# (meson.build: with_gallium_iris => with_clc), which is another package, and
# the acceptance criterion exercises llvmpipe. Prove the whole chain — libglvnd
# vendor loading, libllvm's JIT, the X11 client stack, the empty-host container
# — with one driver, then widen. A driver added to a pipeline that already
# renders is a small change; a pipeline debugged with five drivers at once is
# not.
#
# vulkan-drivers is EMPTY for now, and that is a staging decision rather than
# a scope cut. Building them needs glslangValidator (glslang), which is one
# more build-tool package; the acceptance criterion (S1-S4) exercises the GL
# path through llvmpipe, so GL is proven first and Vulkan is re-enabled once
# glslang is packaged. Leaving it empty is visible in the payload — no
# libvulkan_*.so — rather than silently producing drivers that do not load.
T5=(
  "mesa|25.0.7|https://archive.mesa3d.org/mesa-25.0.7.tar.xz|meson|-Dgallium-drivers=llvmpipe -Dvulkan-drivers= -Dglvnd=enabled -Dplatforms=x11 -Dllvm=enabled -Dshared-llvm=enabled -Dlmsensors=disabled -Dvalgrind=disabled -Dbuild-tests=false -Dgallium-extra-hud=false"
)

run_tier() {  # <tier-name> <entries...>
    local tier="$1"; shift
    local entry name version url system extra
    for entry in "$@"; do
        IFS='|' read -r name version url system extra <<<"$entry"
        echo "── $tier :: $name $version ──────────────────────────────"
        # shellcheck disable=SC2086
        if [[ -n "$extra" ]]; then
            bash "$BUILD" --name "$name" --version "$version" --url "$url" \
                 --system "$system" -- $extra || return 1
        else
            bash "$BUILD" --name "$name" --version "$version" --url "$url" \
                 --system "$system" || return 1
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
