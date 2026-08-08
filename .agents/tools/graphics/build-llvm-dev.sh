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
# TARGETS — X86;AMDGPU;SPIRV
#
# X86 for the host tool. SPIRV because libclc compiles its bitcode with
# `clang -target spirv64-unknown-unknown`.
#
# AMDGPU was excluded in 20.1.7 with this reasoning: "that is libllvm's axis
# (radeonsi's runtime shader compiler), and building it twice would double an
# already long build for nothing." **That was wrong**, and measuring the mesa
# build is what showed it:
#
#   $ ls <libllvm payload>/            ->  lib
#
# The libllvm payload is a lib/ directory and nothing else -- no headers, no
# lib/cmake/llvm/LLVMConfig.cmake, no bin/llvm-config. meson has exactly two ways
# to find LLVM (a config tool, or cmake package files) and libllvm offers
# neither, so libllvm can never be a BUILD input. It is a pure runtime artifact.
#
# Which means the two axes are not "runtime" and "build-time tools" -- they are
# "the shared library a user loads" and "everything a build needs", and the
# second one has to include every target the first one does. Otherwise mesa
# configures against an LLVM without AMDGPU and radeonsi silently loses its
# shader compiler.
#
# The visible consequence of getting this wrong: with X86;SPIRV only, mesa's
# meson skipped past our llvm-config entirely and reported
#
#   llvm-config found: YES (/usr/bin/llvm-config) 18.1.3
#
# picking up the HOST's LLVM 18 -- while the index's libllvm is 20.1.7. A
# libgallium linked that way needs libLLVM.so.18.1, which this index does not
# ship, so the payload could not have loaded at all.
#
# This is also why gcc 15.1.0 is now REQUIRED rather than merely allowed: AMDGPU
# is the translation unit that ICEs gcc 16 (see the compiler note below).
#
# Exit codes follow .agents/tools/README.md:
#   0 built and packaged · 1 the build broke · 3 it never started
set -uo pipefail

# Default is 20.1.7.1, not 20.1.7. The published 20.1.7 payload has no AMDGPU;
# this script no longer produces it, so defaulting to that version would hand you
# a tarball whose name claims to be something already released with different
# contents.
VERSION="${1:-20.1.7.1}"

# The package version and the upstream tag are two different things.
#
# This index's convention is that a fourth component is OURS: when a payload's
# contents change but upstream did not, the asset has to get a new version,
# because a GitCode release asset is written once and cannot be deleted. So
# `20.1.7.1` is llvm-project 20.1.7 rebuilt by us (here: with AMDGPU added).
#
# Conflating them was a real failure, not a hypothetical: passing `20.1.7.1`
# built a URL for `llvmorg-20.1.7.1` and died on a 404 before compiling anything.
# UPSTREAM is derived rather than passed so the two cannot drift apart.
UPSTREAM="${UPSTREAM:-$(echo "$VERSION" | cut -d. -f1-3)}"

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
# with `xlings use gcc 15.1.0` — see the version note below for why 15 and not 16.
BUILD_CC="$SUBOS/bin/gcc"
BUILD_CXX="$SUBOS/bin/g++"
[[ -x "$BUILD_CC" && -x "$BUILD_CXX" ]] || skip "no gcc/g++ in subos '$SUBOS_NAME'"

# gcc 15.1.0 — the same version build-libllvm.sh insists on, and this gate was
# INVERTED in 20.1.7. The history matters because both halves moved.
#
# 20.1.7 required 16.x and refused 15.x, for a measured reason: the gcc 15.1.0
# payload shipped `lib/gcc/x86_64-linux-gnu/15.1.0/include-fixed/pthread.h`, a
# fixincludes snapshot that precedes the sysroot in the search order and so
# SHADOWED the live `pthread.h`. libstdc++'s own `ext/concurrence.h:257` then
# failed with "cannot convert '<brace-enclosed initializer list>' to 'unsigned
# int'", stopping the build at 13/4049 with an error naming neither gcc nor the
# header that shadowed.
#
# That is now fixed at the source (openxlings/xim-pkgindex#560): the snapshot was
# frozen against glibc 2.39 while the sysroot moved to 2.44, and pkgs/g/gcc.lua
# prunes any fixincludes-bannered header at install. Re-measured with 15.1.0
# actually selected -- the first attempt at this measurement used the subos shim
# while it still pointed at 16, and proved nothing:
#
#   frozen header present -> 1 error, -H shows include-fixed/pthread.h winning
#   frozen header pruned  -> 0 errors, -H shows the sysroot's pthread.h winning
#
# And 15.x is now REQUIRED rather than merely permitted, because this build
# gained AMDGPU: 16.1.0 ICEs with a segfault on AMDGPUAsmParser.cpp (2212/2218),
# which is the exact translation unit that forced 15.1.0 on build-libllvm.sh. The
# two scripts now agree, which is the right end state -- they produce the
# build-time and runtime halves of ONE LLVM and had no business disagreeing about
# the compiler.
#
# clang is still wrong as the build compiler, for the reason build-libllvm.sh
# gives: the xlings `llvm` package's clang defaults to libc++ while everything
# else here is libstdc++.
cc_ver="$("$BUILD_CC" -dumpfullversion 2>/dev/null || echo unknown)"
case "$cc_ver" in
  15.*) log "compiler gcc $cc_ver" ;;
  16.*) skip "subos gcc is $cc_ver, which ICEs on AMDGPUAsmParser.cpp; run \`xlings use gcc 15.1.0\`" ;;
  *)    skip "subos gcc is $cc_ver; this build wants 15.x (see the note above)" ;;
esac

# The #560 precondition, checked on the compiler's BEHAVIOUR not on the file.
#
# Asserting "include-fixed/pthread.h is absent" would test the fix's mechanism;
# this tests its effect, so it stays correct if the fix ever moves. Without it
# the build dies 13 targets in, blaming libstdc++.
__probe="$WORK/src/.llvmdev-cxx-probe.cpp"
mkdir -p "$WORK/src"
printf '#include <ext/concurrence.h>\nint main(){return 0;}\n' > "$__probe"
"$BUILD_CXX" -std=c++17 -fno-exceptions -c "$__probe" -o /dev/null 2>"$__probe.log" || {
    echo "---- compiler probe ----" >&2; cat "$__probe.log" >&2
    fail "g++ $cc_ver cannot compile <ext/concurrence.h> -- the gcc payload still ships a frozen fixincludes header (openxlings/xim-pkgindex#560). Reinstall gcc with the pkgs/g/gcc.lua fix."
}
rm -f "$__probe" "$__probe.log"

PREFIX="$WORK/dist/llvm-dev-$VERSION"
rm -rf "$PREFIX"; mkdir -p "$PREFIX"

# ── 1. LLVM + clang, shared ─────────────────────────────────────────────
SRC="$WORK/src/llvm-$UPSTREAM"
TARBALL="$WORK/src/llvm-project-$UPSTREAM.src.tar.xz"
if [[ ! -d "$SRC" ]]; then
    [[ -f "$TARBALL" ]] || {
        log "fetching llvm-project $UPSTREAM (~130 MB)"
        curl -fsSL --retry 3 -o "$TARBALL" \
          "https://github.com/llvm/llvm-project/releases/download/llvmorg-$UPSTREAM/llvm-project-$UPSTREAM.src.tar.xz" \
          || fail "download failed"
    }
    log "extracting"
    mkdir -p "$SRC"
    tar xf "$TARBALL" -C "$SRC" --strip-components=1 || fail "extract failed"
fi

BUILD="$WORK/src/llvm-dev-$VERSION-build"
rm -rf "$BUILD"; mkdir -p "$BUILD"

log "configuring llvm+clang (X86;AMDGPU;SPIRV, shared, no tests/docs)"
"$CMAKE" -S "$SRC/llvm" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$BUILD_CC" \
  -DCMAKE_CXX_COMPILER="$BUILD_CXX" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="X86;AMDGPU" \
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
