#!/usr/bin/env bash
# Build `llvm-dev` — the BUILD-TIME compiler inputs mesa needs for iris.
#
# Design: xlings/.agents/docs/2026-08-08-mesa-rebuild-iris-d3d12-wayland-design.md §3
#
# THE THIRD PACKAGE ON THE SAME LINE, AND WHY
#
#   llvm        a self-contained clang/lld TOOLCHAIN. Its acceptance gate
#               explicitly forbids a shared libLLVM.
#   libllvm     LLVM as a SHARED LIBRARY, for mesa's runtime and nothing else.
#   llvm-dev    clang-as-a-library + the SPIR-V translator + libclc, used only
#               while BUILDING mesa. Never in a user's runtime closure.
#
# Same split the index already makes between `gcc` and `gcc-runtime`: different
# consumer, different axis, different package.
#
# WHY THIS EXISTS AT ALL
#
# mesa's meson wants three things when it builds the OpenCL-C-to-NIR compiler:
#
#   dependency('libclc')                      meson.build:850
#   dependency('LLVMSPIRVLib', required:true) meson.build:1882
#   cpp.find_library('clang-cpp')             meson.build:1900
#
# and iris pulls that path in via `with_clc` (meson.build:841). None of the
# three is in the index: `llvm` is tools-only and `libllvm` is the library
# without clang.
#
# The payoff is that they stay OUT of the shipped payload. With
# `-Dmesa-clc=system` and the mesa_clc/vtn_bindgen this package lets us build,
# mesa's `with_clc` drops iris entirely (meson.build:835) — so the mesa users
# download carries no libclc, no translator and no clang. libclc is a compiler
# input, not a runtime library; packaging it for users would charge every mesa
# install for something it never loads.
#
# WHY IT IS A PACKAGE AND NOT A LOOSE BUILD ARTIFACT
#
# G2 (build-in-subos.sh) fails a build that consumes host libraries, and it is
# right to. So the inputs to the mesa build have to come from our own tree —
# which means they have to be built reproducibly and named. `status = "dev"`
# keeps it out of a user's way without making it unreproducible.
#
# TARGETS
#
# X86 for the host tool, plus SPIRV because libclc compiles its bitcode with
# `clang -target spirv64-unknown-unknown`. AMDGPU is deliberately NOT here:
# that is libllvm's axis (radeonsi's runtime shader compiler), and building it
# twice would double an already long build for nothing.
#
# Exit codes follow .agents/tools/README.md:
#   0 built and packaged · 1 the build broke · 3 it never started
set -uo pipefail

VERSION="${1:-20.1.7}"
SPIRV_TAG="${SPIRV_TAG:-v20.1.0}"
SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxbuild}"
XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS="$XHOME/subos/$SUBOS_NAME"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"
JOBS="${JOBS:-$(nproc)}"

log()  { echo "[llvm-dev] $*"; }
fail() { echo "[llvm-dev] FAIL: $*" >&2; exit 1; }
skip() { echo "[llvm-dev] SKIP: $*" >&2; exit 3; }

# Disk, checked BEFORE anything long starts.
#
# An LLVM+clang build is 12-18 GB of objects and this has already been the
# difference between a useful afternoon and an ENOSPC at 90%. Refuse early and
# say the number, rather than discovering it two hours in.
need_gb="${NEED_GB:-25}"
avail_gb=$(( $(df -P "$WORK" 2>/dev/null | awk 'NR==2{print $4}' || df -P /tmp | awk 'NR==2{print $4}') / 1048576 ))
[[ $avail_gb -ge $need_gb ]] || skip "only ${avail_gb}GB free where the build would go; need ~${need_gb}GB"

[[ -d "$SUBOS" ]] || skip "subos '$SUBOS_NAME' not found — xlings subos new $SUBOS_NAME"
mkdir -p "$WORK/src" "$WORK/dist"

CMAKE="$SUBOS/bin/cmake"; [[ -x "$CMAKE" ]] || skip "no cmake in subos '$SUBOS_NAME'"
NINJA="$SUBOS/bin/ninja"; [[ -x "$NINJA" ]] || skip "no ninja in subos '$SUBOS_NAME'"

# Through the subos's shim, not the payload's bin/ directly. Only the shim
# carries the elfpatch'd interpreter and RPATH; an absolute path into the
# payload makes cmake's compiler probe fail to link. Select the compiler first
# with `xlings use gcc 16.1.0` — see the version note below for why 16 and not 15.
BUILD_CC="$SUBOS/bin/gcc"
BUILD_CXX="$SUBOS/bin/g++"
[[ -x "$BUILD_CC" && -x "$BUILD_CXX" ]] || skip "no gcc/g++ in subos '$SUBOS_NAME'"

# gcc 16.x here, NOT the 15.1.0 that build-libllvm.sh insists on. Both halves of
# that constraint were checked rather than inherited.
#
# Why 15.1.0 is required THERE: 16.1.0 ICEs with a segfault on
# AMDGPUAsmParser.cpp (2212/2218), and libllvm cannot drop AMDGPU because that
# is radeonsi's runtime shader compiler. **This build has no AMDGPU** — it is
# X86;SPIRV, because the only consumer is a host tool that turns OpenCL C into
# SPIR-V. So the ICE cannot be reached from here.
#
# Why 15.1.0 is actively WRONG here, measured 2026-08-08: the gcc 15.1.0 payload
# ships `lib/gcc/x86_64-linux-gnu/15.1.0/include-fixed/pthread.h`, a fixincludes
# copy baked against the glibc of whatever machine built gcc. include-fixed
# precedes the sysroot in the search order, so it SHADOWS our
# `usr/include/bits/pthreadtypes.h` and `__gthread_cond_t` resolves to
# `unsigned int`. libstdc++'s own `ext/concurrence.h` then fails to compile:
#
#   ext/concurrence.h:257: cannot convert '<brace-enclosed initializer list>'
#                          to 'unsigned int' in initialization
#
# which stops the LLVM build at 13/4049 with an error that names neither gcc nor
# the header that shadowed. 16.1.0 compiles the same translation unit clean.
#
# The C++ ABI argument that binds libllvm does NOT bind this package: with
# `-Dmesa-clc=system` mesa consumes a mesa_clc BINARY and never links clang, so
# llvm-dev only has to be self-consistent. clang is still wrong as the build
# compiler, for the reason build-libllvm.sh gives: the xlings `llvm` package's
# clang defaults to libc++ while everything else here is libstdc++.
cc_ver="$("$BUILD_CC" -dumpfullversion 2>/dev/null || echo unknown)"
case "$cc_ver" in
  16.*) log "compiler gcc $cc_ver" ;;
  15.*) skip "subos gcc is $cc_ver, whose include-fixed/pthread.h shadows the sysroot and breaks libstdc++ threading headers; run \`xlings use gcc 16.1.0\`" ;;
  *)    skip "subos gcc is $cc_ver; this build wants 16.x (see the note above)" ;;
esac

PREFIX="$WORK/dist/llvm-dev-$VERSION"
rm -rf "$PREFIX"; mkdir -p "$PREFIX"

# ── 1. LLVM + clang, shared ─────────────────────────────────────────────
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

BUILD="$WORK/src/llvm-dev-$VERSION-build"
rm -rf "$BUILD"; mkdir -p "$BUILD"

log "configuring llvm+clang (X86;SPIRV, shared, no tests/docs)"
"$CMAKE" -S "$SRC/llvm" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$BUILD_CC" \
  -DCMAKE_CXX_COMPILER="$BUILD_CXX" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="SPIRV" \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DCLANG_LINK_CLANG_DYLIB=ON \
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
  -DCLANG_INCLUDE_TESTS=OFF \
  >"$BUILD/configure.log" 2>&1 || { tail -25 "$BUILD/configure.log"; fail "llvm configure"; }

log "building llvm+clang with $JOBS jobs (this is the long part)"
"$NINJA" -C "$BUILD" -j"$JOBS" >"$BUILD/build.log" 2>&1 \
  || { tail -30 "$BUILD/build.log"; fail "llvm build"; }
"$NINJA" -C "$BUILD" install >>"$BUILD/build.log" 2>&1 || fail "llvm install"

[[ -f "$PREFIX/lib/libclang-cpp.so" ]] \
  || fail "no libclang-cpp.so — mesa's cpp.find_library('clang-cpp') would fail"
log "libclang-cpp.so present"

# Reclaim before the next stage: the object tree is the bulk of the footprint
# and nothing downstream reads it.
rm -rf "$BUILD"

# ── 2. SPIRV-LLVM-Translator ────────────────────────────────────────────
TSRC="$WORK/src/spirv-translator-$SPIRV_TAG"
if [[ ! -d "$TSRC" ]]; then
    log "fetching SPIRV-LLVM-Translator $SPIRV_TAG"
    curl -fsSL --retry 3 -o "$WORK/src/spirv.tar.gz" \
      "https://github.com/KhronosGroup/SPIRV-LLVM-Translator/archive/refs/tags/$SPIRV_TAG.tar.gz" \
      || fail "translator download failed"
    mkdir -p "$TSRC"
    tar xf "$WORK/src/spirv.tar.gz" -C "$TSRC" --strip-components=1 || fail "translator extract"
fi

TBUILD="$WORK/src/spirv-build"; rm -rf "$TBUILD"; mkdir -p "$TBUILD"
# $ORIGIN/../lib, not an absolute path and not LD_LIBRARY_PATH.
#
# Without an RPATH, the installed `llvm-spirv` cannot find the
# libLLVMSPIRVLib.so.20.1 sitting next to it, and libclc dies at 218/222 with
# "error while loading shared libraries" -- a runtime failure inside a build,
# three stages after the cause. An ABSOLUTE rpath to $PREFIX would fix this run
# and ship a package that only works from the build machine's path; $ORIGIN is
# relocatable, which is also what elfpatch expects to find. LD_LIBRARY_PATH is
# not an option here: check-no-direct-ld-libpath.sh exists precisely to keep it
# out of this index.
log "building SPIRV-LLVM-Translator"
"$CMAKE" -S "$TSRC" -B "$TBUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$BUILD_CC" -DCMAKE_CXX_COMPILER="$BUILD_CXX" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DLLVM_DIR="$PREFIX/lib/cmake/llvm" \
  -DBUILD_SHARED_LIBS=ON \
  -DLLVM_SPIRV_BUILD_EXTERNAL=YES \
  >"$TBUILD/configure.log" 2>&1 || { tail -25 "$TBUILD/configure.log"; fail "translator configure"; }
"$NINJA" -C "$TBUILD" -j"$JOBS" >"$TBUILD/build.log" 2>&1 \
  || { tail -30 "$TBUILD/build.log"; fail "translator build"; }
"$NINJA" -C "$TBUILD" install >>"$TBUILD/build.log" 2>&1 || fail "translator install"
rm -rf "$TBUILD"

# mesa asks for it by this exact name (meson.build:1882, required : true).
ls "$PREFIX"/lib/libLLVMSPIRVLib.so* >/dev/null 2>&1 \
  || fail "no libLLVMSPIRVLib.so — mesa's dependency('LLVMSPIRVLib') would fail"
log "libLLVMSPIRVLib.so present"

# ── 3. libclc ───────────────────────────────────────────────────────────
# In the llvm-project tree, built against the clang we just installed.
CBUILD="$WORK/src/libclc-build"; rm -rf "$CBUILD"; mkdir -p "$CBUILD"
log "building libclc (spirv targets)"
"$CMAKE" -S "$SRC/libclc" -B "$CBUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DLLVM_DIR="$PREFIX/lib/cmake/llvm" \
  -DLIBCLC_TARGETS_TO_BUILD="spirv-mesa3d-;spirv64-mesa3d-" \
  >"$CBUILD/configure.log" 2>&1 || { tail -25 "$CBUILD/configure.log"; fail "libclc configure"; }
"$NINJA" -C "$CBUILD" -j"$JOBS" >"$CBUILD/build.log" 2>&1 \
  || { tail -30 "$CBUILD/build.log"; fail "libclc build"; }
"$NINJA" -C "$CBUILD" install >>"$CBUILD/build.log" 2>&1 || fail "libclc install"
rm -rf "$CBUILD"

# mesa resolves libclc through pkg-config, so the .pc is the deliverable, not
# just the bitcode.
find "$PREFIX" -name 'libclc.pc' | head -1 | grep -q . \
  || fail "no libclc.pc — mesa's dependency('libclc') resolves through pkg-config"
log "libclc.pc present"

# ── 4. package ──────────────────────────────────────────────────────────
OUT="$WORK/dist/llvm-dev-$VERSION-linux-x86_64.tar.gz"
log "packaging"
tar czf "$OUT" -C "$(dirname "$PREFIX")" "$(basename "$PREFIX")" || fail "tar failed"
sha256sum "$OUT" | awk '{print $1}' > "$OUT.sha256"

log "done"
log "  $OUT"
log "  sha256 $(cat "$OUT.sha256")"
log "  size   $(du -h "$OUT" | cut -f1)"
