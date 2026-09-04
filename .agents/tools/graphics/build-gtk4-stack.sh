#!/usr/bin/env bash
# Build the GTK 4 stack and the libraries the index was missing under it.
#
# Every payload this produces is built by build-in-subos.sh, in a subos, and
# is therefore checked on both sides before it is allowed to exist: what the
# build was CONFIGURED against, and what the payload REFERENCES. Neither check
# is this script's; it only fixes the order and the options.
#
# WHY THE ORDER IS NOT ALPHABETICAL
#
# build-in-subos.sh stages each finished payload into the build subos, so tier
# N+1 configures against tier N. libthai will not build before libdatrie, and
# gtk4 will not build before nine of the ten below it. Run it top to bottom or
# pass a single --only NAME once its dependencies are already staged.
#
# WHY THESE VERSIONS
#
# Upstream's newest stable, EXCEPT gtk4. GTK 4.18 raised its floors to pango
# >= 1.56, cairo >= 1.18.2 and harfbuzz >= 8.4, and this index publishes pango
# 1.52.1 and harfbuzz 8.3.0. 4.16.13 is the newest release that builds against
# what the index actually ships; moving past it means republishing the base
# stack, which is a bigger change than adding gtk4 and belongs in its own PR.
#
# WHY cairo IS REBUILT
#
# GTK 4 hard-requires `cairo-gobject` (gtk/meson.build, no `required: false`)
# and the published cairo payload contains libcairo.so alone -- no
# libcairo-gobject.so, no cairo-gobject.pc. There is no way to configure gtk4
# against it. The rebuild also drops the `prefix=/tmp/cairo-prefix` its .pc
# has carried since it was published.
#
# Usage:
#   build-gtk4-stack.sh                 # everything, in order
#   build-gtk4-stack.sh --only gtk4     # one package (deps must be staged)
#   build-gtk4-stack.sh --from cairo    # resume at a package and continue
#
# --deps MUST CARRY THE TRANSITIVE RUNTIME CLOSURE, NOT JUST THE DIRECT ONES
#
# `--deps` does two jobs: it puts a payload's pkgconfig on the search path
# (compile time) and its lib dir on LD_LIBRARY_PATH/-rpath (run time). The
# second matters because these builds RUN tools they just linked --
# gdk-pixbuf executes its own gdk-pixbuf-query-loaders, gtk4 runs
# glib-compile-resources. Those binaries link glib, and glib links pcre2, so
# a --deps of `glib` alone gets:
#
#     gdk-pixbuf-query-loaders: error while loading shared libraries:
#     libpcre2-8.so.0: cannot open shared object file
#
# which reads as a missing package rather than a missing transitive entry.
# Hence `glib pcre2 libffi zlib util-linux libselinux` wherever glib appears.
#
# GNOME SOURCES COME FROM download.gnome.org, NOT THE GITLAB ARCHIVE
#
# A `/-/archive/<tag>/` tarball is a git export: it has no submodules in it.
# glib 2.88 vendors gvdb that way, so the archive stops at
#     meson.build:2297: ERROR: Subproject exists but has no meson.build file
# The release tarball is also the artifact upstream actually signs and
# announces, which is the one to be building from anyway.
#
# Exit codes follow .agents/tools/README.md: 0 proven, 1 broken, 3 could-not-run.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$HERE/build-in-subos.sh"
[[ -x "$BUILD" || -f "$BUILD" ]] || { echo "missing $BUILD" >&2; exit 3; }

SUBOS="${XLINGS_GFX_SUBOS:-gtk4build}"
# The gcc shim resolves through xvm and needs to know which subos is active.
# Without this it hands back a toolchain whose specs were never patched: the
# binaries get the HOST interpreter while linking the xim glibc, and every
# autotools conftest dies with
#     libc.so.6: undefined symbol: __pointer_chk_guard, version GLIBC_PRIVATE
# which reads as a broken compiler rather than a missing variable.
export XLINGS_ACTIVE_SUBOS="$SUBOS"
export XLINGS_BIN="$HOME/.xlings/subos/$SUBOS/bin"
export XLINGS_GFX_SUBOS="$SUBOS"
export PATH="$XLINGS_BIN:$HOME/.xlings/bin:$PATH"

ONLY= FROM=
while [[ $# -gt 0 ]]; do
    case "$1" in
        --only) ONLY="$2"; shift 2 ;;
        --from) FROM="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

# name|version|url|system|deps|extra meson/configure args
#
# `deps` names packages installed in this XLINGS_HOME whose payload pkgconfig
# build-in-subos.sh should add. Packages built EARLIER IN THIS RUN are already
# staged into the subos sysroot and must NOT be listed.
#
# Two different things go wrong if they are, and only the first is loud:
#
#   * a NEW package is not installed at all, so --deps fails closed --
#     `SKIP: --deps libtiff: not installed`, exit 3.
#   * a package being REPUBLISHED at a new version is installed, at the OLD
#     version, so --deps quietly puts the old payload's pkgconfig on the
#     search path ahead of the staged new one. `--deps cairo` while building
#     gtk4 resolves cairo 1.18.0 -- the payload with no cairo-gobject in it,
#     which is the entire reason 1.18.4 is being built.
#
# So: nothing this script builds may appear in any deps field. What belongs
# there is the rest of the index -- pcre2, libffi, util-linux, the X client
# libraries -- which is installed and is not being rebuilt here.
STACK=(
  # ── tier -1: glib itself ─────────────────────────────────────────────
  #
  # The published glib payload is a PARTIAL extraction of a Debian build: an
  # include/ and a lib/, and nothing else. Three separate things are missing
  # and all three stop this stack:
  #
  #   1. gmodule-no-export-2.0.pc, which its own gmodule-2.0.pc names in
  #      Requires -- so `pkg-config --cflags gio-2.0` fails, and with it
  #      gdk-pixbuf, libsoup and gtk4.
  #   2. bin/ -- so glib-2.0.pc's glib_genmarshal/glib_mkenums variables point
  #      at files that do not exist. meson does not shrug at that: with the
  #      variable present it raises "contains erroneous value", and with the
  #      variable deleted it raises "Could not get pkg-config variable and no
  #      default provided". Both are hard stops (meson 1.8.2,
  #      mesonbuild/modules/__init__.py:find_tool).
  #   3. include/gio-unix-2.0 -- optional for gtk4 and libsoup, but the .so
  #      exports the symbols, so only the headers were ever missing.
  #
  # glib.lua carries recipe-side repairs for 1 and 2 so the PUBLISHED 2.80.0
  # keeps working. This entry is the actual fix: a complete glib, built here,
  # with its own bin/, its full set of .pc files and the gio-unix headers.
  #
  # Added as a NEW version rather than replacing 2.80.0's bytes -- a
  # same-version swap breaks every home that already resolved the old sha256.
  "glib|2.88.3|https://download.gnome.org/sources/glib/2.88/glib-2.88.3.tar.xz|meson|libffi pcre2 zlib util-linux libselinux|-Dtests=false -Dintrospection=disabled -Dman-pages=disabled -Ddocumentation=false -Dnls=disabled -Dsysprof=disabled -Dlibmount=enabled -Dselinux=enabled"

  # ── tier 0: no index dependency beyond glibc ─────────────────────────
  "libdatrie|0.2.14|https://github.com/tlwg/libdatrie/releases/download/v0.2.14/libdatrie-0.2.14.tar.xz|autotools||--disable-static"
  # libthai is not decoration: the PUBLISHED pango payload's
  # libpango-1.0.so.0 has libthai.so.0 in its DT_NEEDED and nothing in this
  # index provides it, so pango has been resolving it from the host. It is
  # the only unresolved soname in the whole installed stack, measured.
  "libthai|0.1.30|https://github.com/tlwg/libthai/releases/download/v0.1.30/libthai-0.1.30.tar.xz|autotools||--disable-static"
  "graphene|1.10.8|https://github.com/ebassi/graphene/archive/refs/tags/1.10.8.tar.gz|meson||-Dtests=false -Dinstalled_tests=false -Dgtk_doc=false -Dintrospection=disabled"
  "libepoxy|1.5.10|https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz|meson|libglvnd libX11 xorgproto|-Dtests=false -Ddocs=false -Dglx=yes -Degl=yes -Dx11=true"
  # pango's published .pc names `xft >= 2.0.0` in Requires.private and nothing
  # in this index provides it, so `pkg-config --cflags pango` fails and gtk4
  # cannot configure. Packaging the library upstream asks for beats editing
  # upstream's metadata to say it does not.
  "libXft|2.3.9|https://www.x.org/releases/individual/lib/libXft-2.3.9.tar.xz|autotools|xorgproto libX11 libXrender freetype fontconfig libxcb libXau libXdmcp expat|--disable-static"
  "libXdamage|1.1.7|https://www.x.org/releases/individual/lib/libXdamage-1.1.7.tar.xz|autotools|xorgproto libX11 libXfixes libxcb libXau libXdmcp|--disable-static"
  # lib-only: the h2load suite drags in libev/openssl/jansson for zero
  # consumers in this index. autotools rather than cmake only because the
  # build subos has no cmake and does not need one for this.
  "nghttp2|1.70.0|https://github.com/nghttp2/nghttp2/releases/download/v1.70.0/nghttp2-1.70.0.tar.xz|autotools||--enable-lib-only --disable-static"
  # runtime=no drops the libidn2/libunistring chain. IDNA conversion goes with
  # it; the built-in PSL data and every ASCII-domain query libsoup makes do not.
  "libpsl|0.23.3|https://github.com/rockdaboot/libpsl/releases/download/0.23.3/libpsl-0.23.3.tar.gz|meson||-Druntime=no -Dbuiltin=true -Dtests=false"
  # Upstream ships sqlite-tools-linux-x64 for this version, and it contains
  # four CLI executables and no libsqlite3.so -- which is the half libsoup
  # links. Hence a build rather than a repack.
  "sqlite|3.53.4|https://sqlite.org/2026/sqlite-autoconf-3530400.tar.gz|autotools||--disable-static --disable-readline"

  # ── tier 1: needs the glib/X stack ───────────────────────────────────
  #
  # WHY HARFBUZZ IS REBUILT
  #
  # GTK 4 takes harfbuzz-subset as a HARD dependency -- gtk meson.build:403,
  # `dependency('harfbuzz-subset', version: harfbuzz_req)`, no `required:
  # false` -- and the published 8.3.0 payload contains exactly one library,
  # libharfbuzz.so. No libharfbuzz-subset, no libharfbuzz-gobject, and one
  # .pc file where upstream installs four.
  #
  # The gobject half is load-bearing too, one step further out: pango's
  # pangoft2.pc names `harfbuzz-gobject` in Requires.private, so without it
  # `pkg-config --cflags pangoft2` fails, and gtk4 requires pangoft2 whenever
  # the x11 or wayland backend is on (meson.build:406).
  #
  # 14.4.0 rather than another 8.3.0: republishing a version in place changes
  # the sha256 under every home that already resolved the old one. GTK 4.16
  # asks for >= 2.6.0, and libharfbuzz.so.0 is ABI-stable across this range,
  # so the published pango and cairo payloads keep working against it.
  "harfbuzz|14.4.0|https://github.com/harfbuzz/harfbuzz/releases/download/14.4.0/harfbuzz-14.4.0.tar.xz|meson|pcre2 libffi zlib util-linux libselinux freetype|-Dglib=enabled -Dgobject=enabled -Dfreetype=enabled -Dcairo=disabled -Dicu=disabled -Dtests=disabled -Ddocs=disabled -Dintrospection=disabled -Dutilities=disabled"
  "cairo|1.18.4|https://gitlab.freedesktop.org/cairo/cairo/-/archive/1.18.4/cairo-1.18.4.tar.gz|meson|libpng zlib pixman freetype fontconfig expat libX11 libXext libXrender libxcb libXau libXdmcp xorgproto|-Dtests=disabled -Dgtk_doc=false -Dglib=enabled -Dxlib=enabled -Dxcb=enabled -Dfreetype=enabled -Dfontconfig=enabled -Dpng=enabled -Dzlib=enabled"
  # GTK 4 loads TIFF textures itself, not through gdk-pixbuf:
  # `tiff_dep = dependency('libtiff-4', 'tiff')` at meson.build:418, with no
  # `required: false`. So this is not optional for gtk4, and with it in the
  # index there is no longer a reason for gdk-pixbuf's own tiff loader to be
  # off either.
  #
  # The optional codecs are all disabled: webp, lzma, zstd, jbig, lerc and
  # libdeflate would each add a package to the closure for a format nothing
  # here asks for. zlib and libjpeg are the two that stay, and both are
  # already index packages.
  "libtiff|4.7.2|https://download.osgeo.org/libtiff/tiff-4.7.2.tar.gz|autotools|zlib|--disable-static --disable-webp --disable-lzma --disable-zstd --disable-jbig --disable-lerc --disable-libdeflate"

  # builtin_loaders=all links every loader INTO libgdk_pixbuf: no loader
  # modules, no loaders.cache with build-host paths baked into it -- which is
  # what a sealed subos wants. tiff is on now that libtiff is packaged above.
  #
  # glycin=disabled is not optional here despite the option defaulting to
  # `auto`: 2.44 wraps it in `enable_auto_if(host_machine.system() == 'linux')`,
  # so on Linux `auto` means REQUIRED, and meson stops at
  #   meson.build:263: ERROR: Dependency "glycin-2" not found
  # glycin is a Rust image stack that is not in this index. Turning it off also
  # keeps the png/jpeg loaders enabled -- `png_opt` is disable_auto_if(glycin
  # found), so a glycin build would have dropped the two loaders gdk-pixbuf is
  # in this index to provide.
  "gdk-pixbuf|2.44.8|https://download.gnome.org/sources/gdk-pixbuf/2.44/gdk-pixbuf-2.44.8.tar.xz|meson|pcre2 libffi zlib util-linux libselinux libpng|-Dglycin=disabled -Dbuiltin_loaders=all -Dtiff=enabled -Dintrospection=disabled -Dman=false -Dtests=false -Dinstalled_tests=false -Ddocumentation=false -Dgio_sniffing=false"
  # tls_check=false is the build-time face of the HTTPS limitation recorded in
  # libsoup.lua. libsoup asserts at configure time that glib-networking is
  # installed --
  #     meson.build:201: ERROR: Assert failed: libsoup requires glib-networking
  #     for TLS support
  # -- and glib-networking pulls gnutls, nettle, gmp, libtasn1, libidn2 and
  # libunistring, none of which this index has. The flag turns the assert off,
  # not TLS: TLS in libsoup is a RUNTIME GIO module either way, so HTTP works
  # and HTTPS reports "TLS support is not available" until that chain lands.
  "libsoup|3.6.6|https://download.gnome.org/sources/libsoup/3.6/libsoup-3.6.6.tar.xz|meson|pcre2 libffi zlib util-linux libselinux|-Dtls_check=false -Dgssapi=disabled -Dntlm=disabled -Dbrotli=disabled -Dintrospection=disabled -Dvapi=disabled -Ddocs=disabled -Dtests=false -Dsysprof=disabled -Dpkcs11_tests=disabled -Dautobahn=disabled"

  # ── tier 2 ───────────────────────────────────────────────────────────
  # x11 and wayland backends both on; vulkan and the media/print backends off
  # (no gstreamer, no cups in the index). build-tests/demos off: they add
  # nothing to a payload and pull extra dependencies.
  "gtk4|4.16.13|https://download.gnome.org/sources/gtk/4.16/gtk-4.16.13.tar.xz|meson|pcre2 libffi zlib util-linux libselinux pango freetype fontconfig fribidi libpng libdrm libX11 libXext libXi libXcursor libXfixes libXrandr libXinerama libXrender libxcb libXau libXdmcp xorgproto libxkbcommon wayland wayland-protocols libglvnd|-Dx11-backend=true -Dwayland-backend=true -Dbroadway-backend=false -Dvulkan=disabled -Dmedia-gstreamer=disabled -Dprint-cups=disabled -Dbuild-tests=false -Dbuild-demos=false -Dbuild-examples=false -Dbuild-testsuite=false -Dintrospection=disabled -Ddocumentation=false -Dman-pages=false -Dcloudproviders=disabled -Dsysprof=disabled -Dtracker=disabled -Dcolord=disabled"
)

started=0; [[ -z "$FROM" ]] && started=1
rc_any=0

# libjpeg-turbo is not in STACK because it is not built: upstream ships an
# official signed .deb with the same sonames, so it is repacked rather than
# recompiled (see repack-upstream-deb.sh for why, and for the byte-for-byte
# check that keeps that claim honest). It still has to be STAGED here, before
# libtiff and gdk-pixbuf configure against it.
if [[ -z "$ONLY" || "$ONLY" == "libjpeg-turbo" ]]; then
    echo "════════════════════════════════════════════════════════════════"
    echo "  libjpeg-turbo 3.2.0  (repacked from upstream, not built)"
    echo "════════════════════════════════════════════════════════════════"
    bash "$HERE/repack-upstream-deb.sh" --name libjpeg-turbo --version 3.2.0 \
        --url https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-official_3.2.0_amd64.deb \
        --strip-prefix opt/libjpeg-turbo || { echo "[stack] libjpeg-turbo FAILED" >&2; exit 1; }
    [[ "$ONLY" == "libjpeg-turbo" ]] && exit 0
fi

for entry in "${STACK[@]}"; do
    IFS='|' read -r name version url system deps extra <<< "$entry"
    [[ -n "$ONLY" && "$ONLY" != "$name" ]] && continue
    [[ -n "$FROM" && "$started" == "0" ]] && { [[ "$FROM" == "$name" ]] && started=1 || continue; }

    echo "════════════════════════════════════════════════════════════════"
    echo "  $name $version"
    echo "════════════════════════════════════════════════════════════════"
    args=(--name "$name" --version "$version" --url "$url" --system "$system")
    [[ -n "$deps" ]] && args+=(--deps "$deps")
    # shellcheck disable=SC2086
    bash "$BUILD" "${args[@]}" -- $extra
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "[stack] $name FAILED (rc=$rc)" >&2
        rc_any=$rc
        break
    fi
done

exit $rc_any
