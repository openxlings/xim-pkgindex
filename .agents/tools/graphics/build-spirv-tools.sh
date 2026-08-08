#!/usr/bin/env bash
# Build `spirv-tools` — SPIRV-Headers + SPIRV-Tools, the last build-time input iris needs.
#
# Design: xlings/.agents/docs/2026-08-08-mesa-rebuild-iris-d3d12-wayland-design.md §4
#
# WHY
#
#   meson.build:1887  dependency('SPIRV-Tools', required : with_clc, version : '>= 2022.1')
#
# `required : with_clc`, and iris sets with_clc (meson.build:841). So iris cannot
# be built without it, and it was not in the index -- no recipe, and no
# xlings-res/spirv-tools repo.
#
# `glslang` does not provide it. That package is built with `-DENABLE_OPT=OFF`
# specifically to keep SPIRV-Tools out (see tiers.sh T4), which was right at the
# time: glslang's optimiser is for its own command line and mesa did not ask for
# it. mesa asks now, through a different door.
#
# TWO PROJECTS, ONE PAYLOAD
#
# SPIRV-Tools does not vendor its headers; it pins a SPIRV-Headers revision in
# DEPS (v2025.1 -> 09913f08…) and expects the source tree beside it. Rather than
# ship two packages where one is useless alone, both install into one prefix, so
# the payload satisfies `SPIRV-Tools.pc` including whatever it declares in
# `Requires:`.
#
# The revision is read FROM the DEPS file rather than chosen: SPIRV-Tools tracks
# in-flight SPIR-V grammar changes, and a mismatched header set fails deep in code
# generation with an error about an unknown opcode.
#
# STATIC, DELIBERATELY
#
# mesa uses SPIRV-Tools only inside `mesa_clc`, a host tool it runs during the
# build. Linking it statically means it cannot appear in the shipped payload's
# runtime closure at all -- there is no .so for anything to DT_NEEDED. That is why
# this has its own script instead of using build-in-subos.sh's cmake path, which
# forces -DBUILD_SHARED_LIBS=ON.
#
# Exit codes follow .agents/tools/README.md:
#   0 built and packaged · 1 the build broke · 3 it never started
set -uo pipefail

VERSION="${1:-2025.1}"
SUBOS_NAME="${XLINGS_GFX_SUBOS:-gfxbuild}"
XHOME="${XLINGS_HOME:-$HOME/.xlings}"
SUBOS="$XHOME/subos/$SUBOS_NAME"
WORK="${XLINGS_GFX_WORK:-${TMPDIR:-/tmp}/xlings-gfx}"
JOBS="${JOBS:-$(nproc)}"

log()  { echo "[spirv-tools] $*"; }
fail() { echo "[spirv-tools] FAIL: $*" >&2; exit 1; }
skip() { echo "[spirv-tools] SKIP: $*" >&2; exit 3; }

[[ -d "$SUBOS" ]] || skip "subos '$SUBOS_NAME' not found — xlings subos new $SUBOS_NAME"
mkdir -p "$WORK/src" "$WORK/dist"

CMAKE="$SUBOS/bin/cmake"; [[ -x "$CMAKE" ]] || skip "no cmake in subos '$SUBOS_NAME'"
NINJA="$SUBOS/bin/ninja"; [[ -x "$NINJA" ]] || skip "no ninja in subos '$SUBOS_NAME'"
CC="$SUBOS/bin/gcc";  CXX="$SUBOS/bin/g++"
[[ -x "$CC" && -x "$CXX" ]] || skip "no gcc/g++ in subos '$SUBOS_NAME'"

# gcc 15.1.0, for the same reason directx-headers uses it: these archives are
# linked into a host tool that also links our LLVM, and mixing libstdc++ ABIs
# across that boundary is how RTTI and exceptions break.
cc_ver="$("$CXX" -dumpfullversion 2>/dev/null || echo unknown)"
case "$cc_ver" in
  15.*) log "compiler g++ $cc_ver" ;;
  *)    skip "subos g++ is $cc_ver; this stack is built with 15.x — run \`xlings use gcc 15.1.0\`" ;;
esac

# The #560 precondition, checked on behaviour rather than on the filesystem.
probe="$WORK/src/.spv-cxx-probe.cpp"
printf '#include <ext/concurrence.h>\nint main(){return 0;}\n' > "$probe"
"$CXX" -std=c++17 -c "$probe" -o /dev/null 2>"$probe.log" || {
    cat "$probe.log" >&2
    fail "g++ $cc_ver cannot compile <ext/concurrence.h> -- the gcc payload still ships a frozen fixincludes header (openxlings/xim-pkgindex#560)"
}
rm -f "$probe" "$probe.log"

# ── sources ─────────────────────────────────────────────────────────────
SRC="$WORK/src/SPIRV-Tools-$VERSION"
TB="$WORK/src/spirv-tools-v$VERSION.tar.gz"
if [[ ! -d "$SRC" ]]; then
    [[ -f "$TB" ]] || {
        log "fetching SPIRV-Tools v$VERSION"
        curl -fsSL --retry 3 -o "$TB" \
          "https://github.com/KhronosGroup/SPIRV-Tools/archive/refs/tags/v$VERSION.tar.gz" \
          || fail "download failed"
    }
    tar -C "$WORK/src" -xzf "$TB" || fail "extract failed"
fi
[[ -f "$SRC/DEPS" ]] || fail "no DEPS in $SRC -- cannot determine the SPIRV-Headers revision"

# Read the pin, do not choose it.
HDR_REV="$(sed -n "s/.*'spirv_headers_revision'[[:space:]]*:[[:space:]]*'\([0-9a-f]\{40\}\)'.*/\1/p" "$SRC/DEPS" | head -1)"
[[ -n "$HDR_REV" ]] || fail "could not parse spirv_headers_revision out of $SRC/DEPS"
log "SPIRV-Headers pinned by DEPS to ${HDR_REV:0:12}"

HDR="$WORK/src/SPIRV-Headers-$HDR_REV"
if [[ ! -d "$HDR" ]]; then
    htb="$WORK/src/spirv-headers-$HDR_REV.tar.gz"
    [[ -f "$htb" ]] || {
        log "fetching SPIRV-Headers ${HDR_REV:0:12}"
        curl -fsSL --retry 3 -o "$htb" \
          "https://github.com/KhronosGroup/SPIRV-Headers/archive/$HDR_REV.tar.gz" \
          || fail "SPIRV-Headers download failed"
    }
    mkdir -p "$HDR"
    tar -C "$HDR" -xzf "$htb" --strip-components=1 || fail "SPIRV-Headers extract failed"
fi
[[ -d "$HDR/include/spirv" ]] || fail "$HDR has no include/spirv -- wrong tarball layout"

PREFIX="$WORK/dist/spirv-tools-$VERSION"
rm -rf "$PREFIX"; mkdir -p "$PREFIX"

# ── 1. SPIRV-Headers ────────────────────────────────────────────────────
# Headers plus a .pc, no compilation. Installed first because SPIRV-Tools'
# generated pkg-config may name it in Requires:, and pkg-config resolves that at
# QUERY time -- so a missing SPIRV-Headers.pc makes `dependency('SPIRV-Tools')`
# report SPIRV-Tools itself as not found.
log "installing SPIRV-Headers"
HB="$WORK/src/spirv-headers-build"
rm -rf "$HB"
"$CMAKE" -S "$HDR" -B "$HB" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  > "$WORK/spirv-headers-configure.log" 2>&1 \
  || { tail -20 "$WORK/spirv-headers-configure.log"; fail "SPIRV-Headers configure"; }
"$CMAKE" --install "$HB" > "$WORK/spirv-headers-install.log" 2>&1 \
  || { tail -20 "$WORK/spirv-headers-install.log"; fail "SPIRV-Headers install"; }
rm -rf "$HB"

# ── 2. SPIRV-Tools ──────────────────────────────────────────────────────
#
# SPIRV_SKIP_TESTS: the test suite needs googletest, which is another source
# dependency this package has no reason to acquire.
#
# SPIRV_SKIP_EXECUTABLES=OFF: spirv-as / spirv-val / spirv-opt are small and
# mesa_clc shells out to none of them -- but leaving them in is what makes the
# payload independently checkable, and the acceptance step below runs spirv-val.
log "configuring SPIRV-Tools (static, no tests)"
B="$WORK/src/spirv-tools-build"
rm -rf "$B"
"$CMAKE" -S "$SRC" -B "$B" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=OFF \
  -DSPIRV_SKIP_TESTS=ON \
  -DSPIRV_SKIP_EXECUTABLES=OFF \
  -DSPIRV_WERROR=OFF \
  -DSPIRV-Headers_SOURCE_DIR="$HDR" \
  > "$WORK/spirv-tools-configure.log" 2>&1 \
  || { tail -30 "$WORK/spirv-tools-configure.log"; fail "SPIRV-Tools configure"; }

log "building with $JOBS jobs"
"$NINJA" -C "$B" -j"$JOBS" > "$WORK/spirv-tools-build.log" 2>&1 \
  || { tail -30 "$WORK/spirv-tools-build.log"; fail "SPIRV-Tools build"; }
"$CMAKE" --install "$B" >> "$WORK/spirv-tools-build.log" 2>&1 \
  || { tail -20 "$WORK/spirv-tools-build.log"; fail "SPIRV-Tools install"; }
rm -rf "$B"

# ── drop the shared variant ─────────────────────────────────────────────
#
# `SPIRV-Tools-shared` is its OWN cmake target, not a mode of the static one, so
# -DBUILD_SHARED_LIBS=OFF does not suppress it -- it installs
# lib/libSPIRV-Tools-shared.so alongside the archives. The assertion below caught
# that on the first run.
#
# It has to go, and not merely for tidiness. mesa asks for `SPIRV-Tools`, which
# resolves to the static archives; but a .so sitting in a payload directory that
# ends up on a link line is one `-lSPIRV-Tools-shared` away from becoming a
# DT_NEEDED in libgallium -- and this package is `status = "dev"`, so it is not in
# mesa's runtime deps and would never be installed on a user's machine. The
# failure would be a dlopen error naming a library nobody declared.
#
# Removed rather than left-and-tolerated so the static-only assertion stays an
# assertion. `Requires:`/`Libs:` in SPIRV-Tools.pc reference the static targets,
# so nothing here needs the shared build.
shopt -s nullglob
for f in "$PREFIX"/lib/libSPIRV-Tools-shared.so* "$PREFIX"/lib/pkgconfig/SPIRV-Tools-shared.pc; do
    log "dropping shared variant: ${f#"$PREFIX"/}"
    rm -f "$f"
done
shopt -u nullglob

# ── assertions ──────────────────────────────────────────────────────────
for f in lib/pkgconfig/SPIRV-Tools.pc lib/libSPIRV-Tools.a include/spirv-tools/libspirv.h; do
    [[ -e "$PREFIX/$f" ]] || fail "payload is missing $f"
done
[[ -f "$PREFIX/include/spirv/unified1/spirv.h" ]] \
  || fail "payload has no include/spirv/unified1/spirv.h -- SPIRV-Headers did not install"

# No shared objects. If one appears, mesa could DT_NEEDED it and this build-only
# package would silently become a runtime dependency of the graphics stack.
sos=$(find "$PREFIX" -name '*.so*' -type f 2>/dev/null)
[[ -z "$sos" ]] || { echo "$sos" >&2; fail "payload contains shared objects; this is meant to be static-only"; }

if command -v pkg-config >/dev/null 2>&1; then
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
    v=$(pkg-config --modversion SPIRV-Tools 2>&1) \
      || fail "pkg-config cannot resolve SPIRV-Tools: $v (mesa meson.build:1887)"
    log "pkg-config: SPIRV-Tools $v"
    pkg-config --atleast-version=2022.1 SPIRV-Tools \
      || fail "SPIRV-Tools $v does not satisfy mesa's version : '>= 2022.1'"
fi

# Prove the library actually works, not just that the files exist.
if [[ -x "$PREFIX/bin/spirv-as" && -x "$PREFIX/bin/spirv-val" ]]; then
    t="$WORK/src/.spv-acceptance"
    rm -rf "$t"; mkdir -p "$t"
    cat > "$t/a.spvasm" <<'ASM'
               OpCapability Shader
               OpMemoryModel Logical GLSL450
               OpEntryPoint GLCompute %main "main"
               OpExecutionMode %main LocalSize 1 1 1
       %void = OpTypeVoid
         %fn = OpTypeFunction %void
       %main = OpFunction %void None %fn
      %entry = OpLabel
               OpReturn
               OpFunctionEnd
ASM
    "$PREFIX/bin/spirv-as" "$t/a.spvasm" -o "$t/a.spv" 2>"$t/err" \
      || { cat "$t/err" >&2; fail "spirv-as could not assemble a minimal module"; }
    "$PREFIX/bin/spirv-val" "$t/a.spv" 2>>"$t/err" \
      || { cat "$t/err" >&2; fail "spirv-val rejected a module spirv-as produced"; }
    log "acceptance: assembled and validated a minimal SPIR-V module ($(stat -c%s "$t/a.spv") bytes)"
    rm -rf "$t"
fi

TAR="$WORK/dist/spirv-tools-$VERSION-linux-x86_64.tar.gz"
rm -f "$TAR"
tar -C "$WORK/dist" -czf "$TAR" "spirv-tools-$VERSION" || fail "packaging"
log "packaged $TAR"
log "sha256 $(sha256sum "$TAR" | awk '{print $1}')"
log "size   $(du -h "$TAR" | awk '{print $1}')"
log "SPIRV-Headers revision baked in: $HDR_REV"
