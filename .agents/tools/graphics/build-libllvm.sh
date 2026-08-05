#!/usr/bin/env bash
# Build `libllvm` — LLVM as a shared library, for mesa and nothing else.
#
# Design: xlings/.agents/docs/2026-08-05-graphics-stack-ecosystem-closure.md §3
#
# This is NOT the `llvm` package. That one is a self-contained clang/lld
# toolchain whose acceptance gate explicitly forbids a shared libLLVM
# (.agents/skills/llvm-subpackaging: "Linux: ldd 只能是系统库(不应出现
# libLLVM.so)"). Different consumer, different axis, different package — the
# same split the index already makes between `gcc` and `gcc-runtime`.
#
# Two build choices, both measured rather than assumed:
#
#   LLVM_TARGETS_TO_BUILD=X86;AMDGPU
#       Undefined-symbol analysis of libgallium finds LLVMInitializeX86* (the
#       llvmpipe/lavapipe JIT) and 27 AMDGPU symbols (radeonsi's shader
#       compiler). Intel and NVIDIA-open go through NIR backends and never
#       reach LLVM, so the other dozen-plus targets are dead weight — the
#       distro build ships them and costs 137 MB.
#
#   LLVM_LINK_LLVM_DYLIB=ON
#       Produces the single libLLVM.so mesa links against. Without it LLVM
#       builds a hundred static archives and there is nothing to package.
#
# The result is ABI-locked to its major.minor: libgallium references 97 C++
# mangled llvm:: symbols carrying an @LLVM_<ver> version tag, so consumers pin
# exactly and a mismatch fails at load rather than misbehaving.
set -uo pipefail

VERSION="${1:-20.1.7}"
SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxbuild}"
XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS="$XHOME/subos/$SUBOS_NAME"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"

log()  { echo "[libllvm] $*"; }
fail() { echo "[libllvm] FAIL: $*" >&2; exit 1; }

[[ -d "$SUBOS" ]] || fail "subos '$SUBOS_NAME' not found"
mkdir -p "$WORK/src" "$WORK/dist"

SRC="$WORK/src/llvm-$VERSION"
TARBALL="$WORK/src/llvm-project-$VERSION.src.tar.xz"
if [[ ! -d "$SRC" ]]; then
    [[ -f "$TARBALL" ]] || {
        log "fetching llvm-project $VERSION (~130 MB)"
        curl -fsSL --retry 3 -o "$TARBALL" \
          "https://github.com/llvm/llvm-project/releases/download/llvmorg-$VERSION/llvm-project-$VERSION.src.tar.xz" \
          || fail "download failed"
    }
    log "extracting"
    mkdir -p "$SRC"
    tar xf "$TARBALL" -C "$SRC" --strip-components=1 || fail "extract failed"
fi

BUILD="$WORK/src/llvm-$VERSION-build"
rm -rf "$BUILD"; mkdir -p "$BUILD"

CMAKE="$SUBOS/bin/cmake"; [[ -x "$CMAKE" ]] || CMAKE="$(command -v cmake)" || fail "no cmake"
NINJA="$SUBOS/bin/ninja";  [[ -x "$NINJA" ]] || NINJA="$(command -v ninja)"  || fail "no ninja"

# gcc 15.1.0, explicitly — not the subos default and not clang.
#
# The subos default is gcc 16.1.0, which ICEs with a segfault on
# AMDGPUAsmParser.cpp at 2212/2218. AMDGPU is not droppable: it is half of why
# libllvm exists, since radeonsi's shader compiler needs it.
#
# clang was the obvious alternative and is wrong for a subtler reason. The
# xlings `llvm` package's clang defaults to libc++, and libgallium references
# 97 mangled llvm:: symbols while mesa is built against libstdc++. Two C++
# runtimes in one process produce symbol names that match and object layouts
# that do not. Forcing -stdlib=libstdc++ then fails to link.
#
# So: build with the compiler whose runtime the ecosystem actually ships.
# `gcc-runtime` is 15.1.0, so gcc 15.1.0 makes the C++ ABI consistent by
# construction rather than by a flag.
# Through the subos's shim, not the payload's bin/ directly. The shim is what
# carries the elfpatch'd interpreter and RPATH; invoking the payload binary by
# absolute path bypasses that and cmake's compiler probe fails to link.
# Select the version with `xlings use gcc 15.1.0` first.
BUILD_CC="$SUBOS/bin/gcc"
BUILD_CXX="$SUBOS/bin/g++"
[[ -x "$BUILD_CC" ]] || fail "no gcc shim in the subos"
log "compiler: $("$BUILD_CC" --version | head -1)"

log "configuring (X86;AMDGPU, shared libLLVM)"
"$CMAKE" -S "$SRC/llvm" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$SUBOS/usr" \
  -DCMAKE_C_COMPILER="$BUILD_CC" \
  -DCMAKE_CXX_COMPILER="$BUILD_CXX" \
  -DCMAKE_MAKE_PROGRAM="$NINJA" \
  -DLLVM_TARGETS_TO_BUILD="X86;AMDGPU" \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_INCLUDE_UTILS=OFF \
  > "$WORK/libllvm-configure.log" 2>&1 \
  || { tail -25 "$WORK/libllvm-configure.log"; fail "cmake configure"; }

# terminfo/libedit/xml2/zlib/zstd are all switched OFF above on purpose. The
# distro build links them and they are pure closure cost here: mesa uses LLVM
# for code generation, and none of that path touches a terminal, an XML parser
# or a decompressor. Turning them off removes six libraries from the payload
# that would otherwise have to be packaged and shipped for nobody.

log "building (this is the long one)"
# llvm-config alongside the library: mesa's meson resolves LLVM through
# `dependency('llvm')`, which shells out to llvm-config for the include path,
# the library name and the component list. Without it meson falls through to
# looking for an llvm.wrap subproject and stops.
"$NINJA" -C "$BUILD" LLVM llvm-config > "$WORK/libllvm-build.log" 2>&1 \
  || { tail -25 "$WORK/libllvm-build.log"; fail "ninja"; }

SO="$(find "$BUILD/lib" -maxdepth 1 -name 'libLLVM.so.*' ! -type l | head -1)"
[[ -n "$SO" ]] || fail "no libLLVM.so was produced"

PAYLOAD="$WORK/payload/libllvm-$VERSION"
rm -rf "$PAYLOAD"; mkdir -p "$PAYLOAD/lib"
cp "$SO" "$PAYLOAD/lib/"
ln -sf "$(basename "$SO")" "$PAYLOAD/lib/libLLVM.so"
patchelf --set-rpath '$ORIGIN' "$PAYLOAD/lib/$(basename "$SO")" 2>/dev/null || true

log "closure:"
readelf -d "$PAYLOAD/lib/$(basename "$SO")" | sed -n 's/.*\[\(lib[^]]*\)\].*/    \1/p'

OUT="$WORK/dist/libllvm-$VERSION-linux-x86_64.tar.gz"
tar czf "$OUT" -C "$WORK/payload" "libllvm-$VERSION"
log "→ $OUT  ($(du -h "$OUT" | cut -f1), unpacked $(du -sh "$PAYLOAD" | cut -f1))"
sha256sum "$OUT" | sed 's/^/[libllvm] sha256: /'

if [[ "${XLINGS_GFX_STAGE:-1}" == "1" ]]; then
    mkdir -p "$SUBOS/usr/lib" "$SUBOS/usr/bin"
    cp -a "$PAYLOAD/lib/." "$SUBOS/usr/lib/"

    # A full LLVM install is staged for the BUILD, separately from the payload.
    #
    # Copying llvm-config and the headers by hand is not enough: llvm-config
    # answers `--shared-mode` by checking that the component archives it knows
    # about are present, so against a lib/ holding only libLLVM.so it errors
    # out per component and mesa's `dependency('llvm', method: 'config-tool')`
    # reports LLVM missing. A runtime-only tree cannot serve as a build
    # dependency; the tool needs a coherent installation to describe.
    #
    # So the subos gets the whole install and the tarball keeps only lib/ —
    # the line distributions draw between libllvm20 and llvm-dev.
    log "staging a full LLVM install for the build (payload stays lib-only)"
    "$NINJA" -C "$BUILD" install >> "$WORK/libllvm-build.log" 2>&1 \
      || { tail -15 "$WORK/libllvm-build.log"; fail "llvm install"; }
    ln -sf ../usr/bin/llvm-config "$SUBOS/bin/llvm-config" 2>/dev/null || true
fi
