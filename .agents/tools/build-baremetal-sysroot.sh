#!/usr/bin/env bash
#
# build-baremetal-sysroot.sh — build a freestanding RISC-V sysroot for the
# xlings package index: picolibc + the compiler-rt builtins needed to link it.
#
# ⭐ The output is TARGET code, so it is host-independent: one archive serves
# every host platform/arch this index supports. That is why the recipe repeats
# a single sha256 across all of them rather than carrying a build matrix.
#
# Why both components in one artifact. picolibc's own `printf` cannot link
# without compiler-rt: its ryu float formatting does 128-bit shifts, and rv64
# has no instruction for them, so `__ashlti3` / `__lshrti3` come out undefined.
# Measured 2026-08-19 on rv64gc/lp64d -- and note the usual "64-bit division"
# smoke test does NOT expose this, because rv64gc has a hardware `divu`.
# Shipping the two apart would guarantee that every user's first bare-metal
# printf fails at link time.
#
# Layout (picolibc's own multilib convention, so adding a profile later moves
# no existing file):
#
#   picolibc-riscv-<ver>/
#     include/<march>/<mabi>/     per-profile headers (picolibc.h is generated
#                                 per build and encodes the profile)
#     lib/<march>/<mabi>/         libc.a libm.a libsemihost.a crt0*.o *.ld
#                                 libclang_rt.builtins-<arch>.a
#     LICENSE.picolibc  LICENSE.compiler-rt  BUILDINFO
#
# Usage:
#   build-baremetal-sysroot.sh --llvm <llvm-payload-dir> \
#       [--picolibc-version 1.8.12] [--llvm-version 22.1.8] [--out <dir>]
#
# Requires: meson, ninja, cmake, git, curl, tar (host tools only -- the
# compiler is entirely the llvm payload).
#
set -euo pipefail

PICOLIBC_VERSION=1.8.12
LLVM_VERSION=22.1.8
LLVM_DIR=""
OUT="$PWD/out"
WORK=""

# march/mabi pairs to build. rv64gc/lp64d is qemu `virt` and the profile the
# mcpp bare-metal route targets; rv32imac/ilp32 is what most real RISC-V MCUs
# are. Both are needed to prove the layout generalises -- a single-profile
# tree would bake the profile into the paths by accident.
PROFILES=(
    "riscv64-none-elf rv64gc   lp64d"
    "riscv32-none-elf rv32imac ilp32"
)

while [ $# -gt 0 ]; do
    case "$1" in
        --llvm)              LLVM_DIR="$2"; shift 2 ;;
        --picolibc-version)  PICOLIBC_VERSION="$2"; shift 2 ;;
        --llvm-version)      LLVM_VERSION="$2"; shift 2 ;;
        --out)               OUT="$2"; shift 2 ;;
        --work)              WORK="$2"; shift 2 ;;
        -h|--help)           sed -n '2,40p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -n "$LLVM_DIR" ] || { echo "--llvm <llvm-payload-dir> is required" >&2; exit 2; }
for tool in clang clang++ llvm-ar llvm-nm llvm-ranlib ld.lld; do
    [ -x "$LLVM_DIR/bin/$tool" ] || { echo "missing $LLVM_DIR/bin/$tool" >&2; exit 2; }
done
for tool in meson ninja cmake git curl tar; do
    command -v "$tool" >/dev/null || { echo "missing host tool: $tool" >&2; exit 2; }
done

WORK="${WORK:-$(mktemp -d)}"
mkdir -p "$WORK" "$OUT"
STAGE="$WORK/picolibc-riscv-$PICOLIBC_VERSION"
rm -rf "$STAGE"; mkdir -p "$STAGE"

echo "==> sources"
PICO_TAR="picolibc-$PICOLIBC_VERSION.tar.xz"
PICO_URL="https://github.com/picolibc/picolibc/releases/download/$PICOLIBC_VERSION"
if [ ! -f "$WORK/$PICO_TAR" ]; then
    curl -fsSL --retry 3 --retry-all-errors -o "$WORK/$PICO_TAR" "$PICO_URL/$PICO_TAR"
fi
# Upstream publishes a .sha256sum sidecar; check against it rather than a hash
# pasted into this script, so a version bump cannot silently skip the check.
curl -fsSL --retry 3 --retry-all-errors "$PICO_URL/$PICO_TAR.sha256sum" \
    > "$WORK/$PICO_TAR.sha256sum"
( cd "$WORK" && sha256sum -c --status "$PICO_TAR.sha256sum" ) \
    || { echo "picolibc tarball failed its upstream sha256" >&2; exit 1; }
rm -rf "$WORK/picolibc-$PICOLIBC_VERSION"
tar -xf "$WORK/$PICO_TAR" -C "$WORK"

if [ ! -d "$WORK/llvm-src/compiler-rt" ]; then
    # Sparse + blobless: compiler-rt/lib/builtins plus the cmake modules it
    # includes is ~85MB, against ~2GB for the whole monorepo.
    rm -rf "$WORK/llvm-src"
    git clone --filter=blob:none --sparse --depth 1 \
        --branch "llvmorg-$LLVM_VERSION" \
        https://github.com/llvm/llvm-project.git "$WORK/llvm-src"
    git -C "$WORK/llvm-src" sparse-checkout set compiler-rt cmake llvm/cmake
fi

for profile in "${PROFILES[@]}"; do
    set -- $profile
    triple="$1"; march="$2"; mabi="$3"
    arch="${triple%%-*}"
    echo "==> $march/$mabi ($triple)"

    prefix="$STAGE/staging/$march/$mabi"
    cross="$WORK/cross-$march-$mabi.txt"
    cpu_family=$([ "$arch" = "riscv32" ] && echo riscv32 || echo riscv64)

    # ⚠️ `--no-default-config` is mandatory, not hygiene. The llvm payload ships
    # bin/clang.cfg with an unconditional `-isystem <glibc>/include`, a hardcoded
    # `-Wl,--dynamic-linker=.../ld-linux-x86-64.so.2` and `-L .../lib64` -- none
    # of it guarded by target. Without this flag the host glibc <limits.h> wins
    # over the freestanding one and compiler-rt dies on `gnu/stubs-32.h`.
    cat > "$cross" <<EOF
[binaries]
c   = ['$LLVM_DIR/bin/clang', '--no-default-config', '-target', '$triple', '-march=$march', '-mabi=$mabi', '-mcmodel=medany', '-nostdlib']
cpp = ['$LLVM_DIR/bin/clang++', '--no-default-config', '-target', '$triple', '-march=$march', '-mabi=$mabi', '-mcmodel=medany', '-nostdlib']
ar     = '$LLVM_DIR/bin/llvm-ar'
nm     = '$LLVM_DIR/bin/llvm-nm'
strip  = '$LLVM_DIR/bin/llvm-strip'
c_ld   = '$LLVM_DIR/bin/ld.lld'
cpp_ld = '$LLVM_DIR/bin/ld.lld'

[host_machine]
system = 'none'
cpu_family = '$cpu_family'
cpu = 'riscv'
endian = 'little'

[properties]
c_args = ['-Werror=double-promotion', '-fshort-enums']
skip_sanity_check = true
has_link_defsym = true
default_flash_addr = '0x80000000'
default_flash_size = '0x00400000'
default_ram_addr   = '0x80400000'
default_ram_size   = '0x00200000'
EOF

    rm -rf "$WORK/pb-$march-$mabi"
    meson setup "$WORK/pb-$march-$mabi" "$WORK/picolibc-$PICOLIBC_VERSION" \
        --cross-file "$cross" -Dtests=false -Dmultilib=false \
        -Dpicocrt=true -Dsemihost=true --prefix="$prefix" >/dev/null
    ninja -C "$WORK/pb-$march-$mabi" >/dev/null
    ninja -C "$WORK/pb-$march-$mabi" install >/dev/null

    rm -rf "$WORK/crtb-$march-$mabi"
    cmake -S "$WORK/llvm-src/compiler-rt/lib/builtins" \
          -B "$WORK/crtb-$march-$mabi" -G Ninja \
          -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
          -DCMAKE_SYSTEM_NAME=Generic \
          -DCMAKE_C_COMPILER="$LLVM_DIR/bin/clang" \
          -DCMAKE_ASM_COMPILER="$LLVM_DIR/bin/clang" \
          -DCMAKE_AR="$LLVM_DIR/bin/llvm-ar" \
          -DCMAKE_NM="$LLVM_DIR/bin/llvm-nm" \
          -DCMAKE_RANLIB="$LLVM_DIR/bin/llvm-ranlib" \
          -DCMAKE_C_COMPILER_TARGET="$triple" \
          -DCMAKE_ASM_COMPILER_TARGET="$triple" \
          -DCMAKE_C_FLAGS="--no-default-config -march=$march -mabi=$mabi -mcmodel=medany -ffreestanding" \
          -DCMAKE_ASM_FLAGS="--no-default-config -march=$march -mabi=$mabi -mcmodel=medany" \
          -DCOMPILER_RT_BAREMETAL_BUILD=ON \
          -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
          -DCOMPILER_RT_OS_DIR=baremetal \
          -DLLVM_CMAKE_DIR="$WORK/llvm-src/llvm/cmake" \
          -DCMAKE_INSTALL_PREFIX="$prefix" >/dev/null
    ninja -C "$WORK/crtb-$march-$mabi" >/dev/null

    mkdir -p "$STAGE/include/$march/$mabi" "$STAGE/lib/$march/$mabi"
    cp -a "$prefix/include/." "$STAGE/include/$march/$mabi/"
    cp -a "$prefix/lib/." "$STAGE/lib/$march/$mabi/"
    cp "$WORK/crtb-$march-$mabi/lib/baremetal/libclang_rt.builtins-$arch.a" \
       "$STAGE/lib/$march/$mabi/"

    # Fail closed on the exact gap this artifact exists to close. Reaching here
    # with the builtins missing would ship a sysroot whose printf cannot link.
    #
    # ⚠️ Counted, not `grep -q`. Under `pipefail` a matching `grep -q` closes
    # the pipe the moment it matches, llvm-nm takes SIGPIPE, and the pipeline
    # reports 141 -- so the check fails EXACTLY when it should pass. This guard
    # did that on its first run against a library that was perfectly fine.
    shifts=$("$LLVM_DIR/bin/llvm-nm" \
        "$STAGE/lib/$march/$mabi/libclang_rt.builtins-$arch.a" \
        | grep -cE ' T (__ashlti3|__lshrti3)$')
    [ "$shifts" -ge 2 ] \
        || { echo "builtins for $march/$mabi lack the 128-bit shifts picolibc printf needs (found $shifts/2)" >&2; exit 1; }
    for f in libc.a libm.a libsemihost.a crt0-semihost.o picolibc.ld picolibcpp.ld; do
        [ -e "$STAGE/lib/$march/$mabi/$f" ] \
            || { echo "missing $march/$mabi/$f" >&2; exit 1; }
    done
done
rm -rf "$STAGE/staging"

cp "$WORK/picolibc-$PICOLIBC_VERSION/COPYING.picolibc" "$STAGE/LICENSE.picolibc"
cp "$WORK/llvm-src/compiler-rt/LICENSE.TXT" "$STAGE/LICENSE.compiler-rt"
{
    echo "picolibc  $PICOLIBC_VERSION"
    echo "compiler-rt builtins  llvm $LLVM_VERSION"
    echo "built with  $("$LLVM_DIR/bin/clang" --version | head -1)"
    echo "profiles"
    for profile in "${PROFILES[@]}"; do set -- $profile; echo "  $2/$3  ($1)"; done
} > "$STAGE/BUILDINFO"

asset="$OUT/picolibc-riscv-$PICOLIBC_VERSION.tar.gz"
# Reproducible tar: fixed owner/mtime and a sorted member order, so two runs of
# this script on the same inputs produce the same bytes and the same sha256.
tar --sort=name --owner=0 --group=0 --numeric-owner \
    --mtime="@0" --format=gnu \
    -czf "$asset" -C "$(dirname "$STAGE")" "$(basename "$STAGE")"
sha256sum "$asset" | sed "s| .*/| |" > "$asset.sha256"

echo "==> $asset"
cat "$asset.sha256"
du -sh "$asset"
