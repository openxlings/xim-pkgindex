#!/usr/bin/env bash
# Build `directx-headers` — the BUILD-TIME input mesa's d3d12 gallium driver needs.
#
# Design: xlings/.agents/docs/2026-08-08-mesa-rebuild-iris-d3d12-wayland-design.md §4
#
# WHY THIS IS A PACKAGE AND NOT A SUBPROJECT
#
# mesa asks for it by pkg-config, twice, and falls back to a wrap:
#
#   meson.build:604  dependency('directx-headers', required : false)
#   meson.build:606  dependency('DirectX-Headers', version : '>= 1.614.1',
#                               fallback : ['DirectX-Headers', 'dep_dxheaders'],
#                               required : with_gallium_d3d12 or with_microsoft_vk)
#
# Letting the wrap fire would have mesa download it mid-build, which is exactly
# the host-input class G2 exists to refuse: an input nobody named, nobody
# versioned, and nobody can reproduce. 1.614.1 is chosen because it is the
# lowest version that satisfies mesa's own floor -- there is no reason to be
# ahead of what the consumer asks for.
#
# WHY NOT meson
#
# There is no `meson` package in this index at all (`xlings install meson` ->
# "package 'meson' not found"), and adding a Python build system to the
# ecosystem to compile TWO translation units would be the tail wagging the dog.
# Upstream's meson.build does exactly three things on Linux:
#
#   static_library('d3dx12-format-properties', 'src/d3dx12_property_format_table.cpp')
#   static_library('DirectX-Guids',            'src/dxguids.cpp')
#   pkg.generate(...)  +  install_subdir('include')
#
# so this script does those three things directly with g++ and ar. That is not a
# shortcut around the build system, it is the whole build system.
#
# WHY gcc 15.1.0 AND NOT 16
#
# These are STATIC archives; they get linked INTO libgallium. So their libstdc++
# ABI becomes mesa's, and mesa's runtime dep is `gcc-runtime@>=15` (15.1.0).
# Building these with 16 would raise libgallium's GLIBCXX floor above what that
# dep can satisfy -- a load-time failure, not a build one. Measured: the shipped
# libgallium-25.0.7.so needs at most GLIBCXX_3.4.29.
#
# This requires the #560 fix (frozen include-fixed/pthread.h pruned in
# pkgs/g/gcc.lua) to be in the installed gcc payload; without it no C++ TU that
# reaches <ext/concurrence.h> compiles under 15.1.0. Asserted below rather than
# assumed, because the failure names libstdc++ and not gcc.
#
# Exit codes follow .agents/tools/README.md:
#   0 built and packaged · 1 the build broke · 3 it never started
set -uo pipefail

VERSION="${1:-1.614.1}"
SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxbuild}"
XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS="$XHOME/subos/$SUBOS_NAME"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"

log()  { echo "[directx-headers] $*"; }
fail() { echo "[directx-headers] FAIL: $*" >&2; exit 1; }
skip() { echo "[directx-headers] SKIP: $*" >&2; exit 3; }

[[ -d "$SUBOS" ]] || skip "subos '$SUBOS_NAME' not found — xlings subos new $SUBOS_NAME"
mkdir -p "$WORK/src" "$WORK/dist"

# Through the shim, not the payload's bin/: only the shim carries the elfpatch'd
# interpreter and the sysroot flags. Same rule as build-llvm-dev.sh.
CXX="$SUBOS/bin/g++"
[[ -x "$CXX" ]] || skip "no g++ in subos '$SUBOS_NAME'"
AR="$SUBOS/bin/ar"; [[ -x "$AR" ]] || AR="$(command -v ar)"
[[ -x "$AR" ]] || skip "no ar available"

cc_ver="$("$CXX" -dumpfullversion 2>/dev/null || echo unknown)"
case "$cc_ver" in
  15.*) log "compiler g++ $cc_ver" ;;
  *)    skip "subos g++ is $cc_ver; these archives link into libgallium and must match its gcc-runtime@>=15 floor — run \`xlings use gcc 15.1.0\`" ;;
esac

# The #560 precondition, checked on the compiler rather than on the filesystem.
#
# Asserting "include-fixed/pthread.h is absent" would be checking the fix's
# mechanism; this checks its EFFECT, so it stays true if the fix ever moves.
probe="$WORK/src/.dxh-cxx-probe.cpp"
printf '#include <ext/concurrence.h>\nint main(){return 0;}\n' > "$probe"
"$CXX" -std=c++14 -c "$probe" -o /dev/null 2>"$WORK/src/.dxh-cxx-probe.log" || {
    echo "---- compiler probe output ----" >&2; cat "$WORK/src/.dxh-cxx-probe.log" >&2
    fail "g++ $cc_ver cannot compile <ext/concurrence.h>: the gcc payload still ships a frozen fixincludes header (openxlings/xim-pkgindex#560). Reinstall gcc with the pkgs/g/gcc.lua fix, or prune lib/gcc/*/*/include-fixed/pthread.h."
}
rm -f "$probe" "$WORK/src/.dxh-cxx-probe.log"

SRC="$WORK/src/DirectX-Headers-$VERSION"
TARBALL="$WORK/src/directx-headers-$VERSION.tar.gz"
if [[ ! -d "$SRC" ]]; then
    [[ -f "$TARBALL" ]] || {
        log "fetching DirectX-Headers $VERSION"
        curl -fsSL --retry 3 -o "$TARBALL" \
          "https://github.com/microsoft/DirectX-Headers/archive/refs/tags/v$VERSION.tar.gz" \
          || fail "download failed"
    }
    log "extracting"
    tar -C "$WORK/src" -xzf "$TARBALL" || fail "extract failed"
fi
[[ -f "$SRC/src/dxguids.cpp" ]] || fail "source tree at $SRC has no src/dxguids.cpp"

PREFIX="$WORK/dist/directx-headers-$VERSION"
rm -rf "$PREFIX"; mkdir -p "$PREFIX/lib" "$PREFIX/share/pkgconfig"

# Include flags transcribed from upstream meson.build, not guessed.
#
#   inc_dirs = include_directories('include', is_system : true)
#   non-windows: += include_directories('include/wsl/stubs', is_system : true)
#   format_properties_lib also gets 'include/directx'
#
# is_system is -isystem, which matters: these headers are not warning-clean and
# the archives are built into a project that uses -Werror in places.
INC=(-isystem "$SRC/include" -isystem "$SRC/include/wsl/stubs")

log "compiling 2 translation units (c++14)"
# -H so the header trail can be audited for host leakage below. This IS the G2
# input check for this package -- there is no build system to hook it into.
"$CXX" -std=c++14 -fPIC -O2 "${INC[@]}" -I"$SRC/include/directx" \
    -H -c "$SRC/src/d3dx12_property_format_table.cpp" \
    -o "$WORK/src/d3dx12_property_format_table.o" 2>"$WORK/src/dxh-fmt.hdrs" \
    || { tail -20 "$WORK/src/dxh-fmt.hdrs" >&2; fail "compiling d3dx12_property_format_table.cpp"; }

"$CXX" -std=c++14 -fPIC -O2 "${INC[@]}" \
    -H -c "$SRC/src/dxguids.cpp" -o "$WORK/src/dxguids.o" 2>"$WORK/src/dxh-guids.hdrs" \
    || { tail -20 "$WORK/src/dxh-guids.hdrs" >&2; fail "compiling dxguids.cpp"; }

# G2: every header consumed must come from our own tree or the source tarball.
#
# `-H` prints one line per header as `.... /path`. A header from /usr/include
# means the sysroot did not cover something and the host silently filled in --
# which is how a payload ends up depending on the build machine.
leaked=$(sed -n 's/^\.*[[:space:]]*\(\/.*\)$/\1/p' "$WORK/src/dxh-fmt.hdrs" "$WORK/src/dxh-guids.hdrs" \
         | sort -u | grep -v -e "^$XHOME/" -e "^$SRC/" || true)
if [[ -n "$leaked" ]]; then
    echo "$leaked" | sed 's/^/  /' >&2
    fail "$(echo "$leaked" | wc -l) header(s) came from outside XLINGS_HOME and the source tree"
fi
log "header audit: all includes from XLINGS_HOME or the source tree"

# Archive names must be exactly what the .pc advertises, and the .pc must
# advertise what upstream's pkg.generate() would have: meson derives -l flags
# from the static_library() TARGET names, so `d3dx12-format-properties` and
# `DirectX-Guids`, not the file names.
"$AR" rcs "$PREFIX/lib/libd3dx12-format-properties.a" "$WORK/src/d3dx12_property_format_table.o" \
    || fail "ar libd3dx12-format-properties.a"
"$AR" rcs "$PREFIX/lib/libDirectX-Guids.a" "$WORK/src/dxguids.o" || fail "ar libDirectX-Guids.a"

log "installing headers"
cp -r "$SRC/include" "$PREFIX/include" || fail "copying include tree"
cp "$SRC/LICENSE" "$PREFIX/LICENSE" 2>/dev/null || true

# Relocatable by construction, via ${pcfiledir}.
#
# pkg-config expands ${pcfiledir} to the directory the .pc was FOUND in, so a
# prefix expressed relative to it needs no install-time rewriting at all. This
# is why this package has no __relocate_pc() the way llvm-dev does -- libclc.pc
# comes from someone else's build and hardcodes absolute paths; this one is ours
# to write, so the right fix is to never write an absolute path.
#
# subdirs on non-windows is ['', '', 'wsl/stubs', 'directx'] upstream, i.e. three
# distinct -I roots. wsl/stubs supplies the Windows types (GUID, HRESULT) that
# d3d12.h needs on Linux; omitting it makes d3d12.h fail deep inside mesa.
cat > "$PREFIX/share/pkgconfig/DirectX-Headers.pc" <<'PC'
prefix=${pcfiledir}/../..
libdir=${prefix}/lib
includedir=${prefix}/include

Name: DirectX-Headers
Description: Headers for using D3D12
URL: https://github.com/microsoft/DirectX-Headers
Version: @VERSION@
Cflags: -I${includedir} -I${includedir}/wsl/stubs -I${includedir}/directx
Libs: -L${libdir} -ld3dx12-format-properties -lDirectX-Guids
PC
sed -i "s/@VERSION@/$VERSION/" "$PREFIX/share/pkgconfig/DirectX-Headers.pc"

# Both spellings mesa tries. mesa asks for `directx-headers` first and
# `DirectX-Headers` second; upstream only ever generates the second, so the
# first lookup always misses and the fallback carries it. Shipping a symlink for
# the lowercase name makes the FIRST lookup succeed, which is what keeps mesa
# from evaluating the `fallback:` wrap at all -- and the wrap is the thing that
# would reach the network mid-build.
ln -sf DirectX-Headers.pc "$PREFIX/share/pkgconfig/directx-headers.pc"

# Assertions, each naming the mesa line it protects.
for f in lib/libd3dx12-format-properties.a lib/libDirectX-Guids.a \
         share/pkgconfig/DirectX-Headers.pc include/directx/d3d12.h \
         include/wsl/winadapter.h include/wsl/stubs/unknwn.h; do
    [[ -e "$PREFIX/$f" ]] || fail "payload is missing $f"
done
for a in libd3dx12-format-properties libDirectX-Guids; do
    "$AR" t "$PREFIX/lib/$a.a" | grep -q . || fail "$a.a is an empty archive"
done

# Prove it resolves the way mesa will ask, if pkg-config is around to ask with.
if command -v pkg-config >/dev/null 2>&1; then
    for name in DirectX-Headers directx-headers; do
        v=$(PKG_CONFIG_PATH="$PREFIX/share/pkgconfig" pkg-config --modversion "$name" 2>/dev/null || true)
        [[ "$v" == "$VERSION" ]] || fail "pkg-config --modversion $name gave '$v', expected $VERSION (mesa:604/606)"
    done
    PKG_CONFIG_PATH="$PREFIX/share/pkgconfig" pkg-config --atleast-version=1.614.1 DirectX-Headers \
        || fail "does not satisfy mesa's version : '>= 1.614.1' (meson.build:607)"
    # Resolved, not string-matched. ${pcfiledir} expands to the .pc's own
    # directory, so the include path comes out as
    # `<root>/share/pkgconfig/../../include` -- correct, and not literally equal
    # to `<root>/include`. Comparing the strings fails on a working payload,
    # which it did on the first run of this script. The invariant that actually
    # matters is where the path LANDS.
    first_inc=$(PKG_CONFIG_PATH="$PREFIX/share/pkgconfig" pkg-config --cflags-only-I DirectX-Headers \
                | tr ' ' '\n' | sed -n 's/^-I//p' | head -1)
    [[ -n "$first_inc" && -d "$first_inc" ]] \
        || fail "\${pcfiledir} did not expand to a real directory: '$first_inc'"
    [[ "$(cd "$first_inc" && pwd -P)" == "$(cd "$PREFIX/include" && pwd -P)" ]] \
        || fail "\${pcfiledir} resolved to $(cd "$first_inc" && pwd -P), not $PREFIX/include"
    log "pkg-config: --cflags resolves into the payload, --modversion $VERSION, both spellings"
else
    log "note: no pkg-config here, so the resolution check was skipped (exit stays 0; the recipe asserts the files)"
fi

TAR="$WORK/dist/directx-headers-$VERSION-linux-x86_64.tar.gz"
rm -f "$TAR"
tar -C "$WORK/dist" -czf "$TAR" "directx-headers-$VERSION" || fail "packaging"
log "packaged $TAR"
log "sha256 $(sha256sum "$TAR" | awk '{print $1}')"
log "size   $(du -h "$TAR" | awk '{print $1}')"
