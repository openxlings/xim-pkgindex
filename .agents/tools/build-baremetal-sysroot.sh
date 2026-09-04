#!/usr/bin/env bash
#
# build-baremetal-sysroot.sh — build a freestanding sysroot for the xlings
# package index: picolibc + the compiler-rt builtins needed to link it.
#
# One script, three target families (`--family riscv|aarch64|x86`). It was
# riscv-only until 2026-08-21; the second and third families were added by
# turning what the riscv path hardcoded into per-family table fields, rather
# than by copying the script — a second copy is how a template's build program
# came to disagree with its own README elsewhere in this ecosystem.
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
#   picolibc-<family>-<ver>/
#     include/<march>/<mabi>/     per-profile headers (picolibc.h is generated
#                                 per build and encodes the profile)
#     lib/<march>/<mabi>/         libc.a libm.a libsemihost.a crt0*.o *.ld
#                                 libclang_rt.builtins-<arch>.a
#     LICENSE.picolibc  LICENSE.compiler-rt  BUILDINFO
#
# Usage:
#   build-baremetal-sysroot.sh --llvm <llvm-payload-dir> \
#       [--family riscv|aarch64|x86] \
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

FAMILY=riscv

# Per family: triple, march, mabi, mcmodel, meson cpu_family, extra cflags.
#
# The riscv pair is two profiles on purpose: rv64gc/lp64d is qemu `virt` and
# what the mcpp bare-metal route targets, rv32imac/ilp32 is what most real
# RISC-V MCUs are, and BOTH are needed to prove the layout generalises -- a
# single-profile tree would bake the profile into the paths by accident.
#
# The other two families have one profile each because mcpp's own freestanding
# target table has one row each. Their values are copied from that table rather
# than chosen here, so the sysroot is built for the same machine mcpp will
# compile against.
#
# ⚠️ `-mno-red-zone` on x86_64 is a property of the TARGET, not a preference:
# an interrupt on a bare machine may write below rsp, and the red zone assumes
# nothing does.
PROFILES_riscv=(
    "riscv64-none-elf rv64gc   lp64d medany riscv64 -"
    "riscv32-none-elf rv32imac ilp32 medany riscv32 -"
)
PROFILES_aarch64=(
    "aarch64-none-elf armv8-a  aapcs small  aarch64 -"
)
PROFILES_x86=(
    "x86_64-none-elf  x86-64   sysv  small  x86_64  -mno-red-zone"
)
# ⚠️ SEVEN PROFILES, AND THAT IS THE FAMILY RATHER THAN A CHOICE. "Cortex-M" is
# not an instruction set: an object built for `thumbv7em` uses instructions a
# Cortex-M0 does not have, so mcpp's target table carries seven rows and a
# sysroot serving them has to carry seven multilibs. The values are copied from
# that table rather than chosen here.
#
# ⚠️ `-mfpu=none` ON EVERY SOFT-FLOAT ROW, AND IT IS NOT REDUNDANT WITH THE ABI.
# clang reads the float ABI from the `eabi`/`eabihf` suffix, and the ABI governs
# how floats cross a call boundary — not whether the compiler may USE the FPU
# inside one. `thumbv7em` implies FPv4-SP, so without this a soft-float build
# emits FPU instructions that fault at run time on a part with no FPU, with a
# clean compile and a clean link.
#
# ⚠️ `mcmodel` IS `-` ON EVERY ROW: 32-bit ARM has no such axis, and passing
# `-mcmodel=` with an empty value is an error rather than a no-op.
PROFILES_arm=(
    "thumbv6m-none-eabi        armv6-m      aapcs - arm -mfpu=none"
    "thumbv7m-none-eabi        armv7-m      aapcs - arm -mfpu=none"
    "thumbv7em-none-eabi       armv7e-m     aapcs - arm -mfpu=none"
    "thumbv7em-none-eabihf     armv7e-m     aapcs - arm -"
    "thumbv8m.base-none-eabi   armv8-m.base aapcs - arm -mfpu=none"
    "thumbv8m.main-none-eabi   armv8-m.main aapcs - arm -mfpu=none"
    "thumbv8m.main-none-eabihf armv8-m.main aapcs - arm -"
)

while [ $# -gt 0 ]; do
    case "$1" in
        --family)            FAMILY="$2"; shift 2 ;;
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

case "$FAMILY" in
    riscv)   PROFILES=("${PROFILES_riscv[@]}")   ;;
    aarch64) PROFILES=("${PROFILES_aarch64[@]}") ;;
    x86)     PROFILES=("${PROFILES_x86[@]}")     ;;
    arm)     PROFILES=("${PROFILES_arm[@]}")     ;;
    *) echo "unknown --family '$FAMILY' (riscv|aarch64|x86|arm)" >&2; exit 2 ;;
esac

WORK="${WORK:-$(mktemp -d)}"
mkdir -p "$WORK" "$OUT"
STAGE="$WORK/picolibc-$FAMILY-$PICOLIBC_VERSION"
rm -rf "$STAGE"; mkdir -p "$STAGE"

# The link wrapper for families where clang cannot drive the link lives in its
# own file — see .agents/tools/bare-link-wrapper.sh for why one is needed at
# all. It is configured through the environment because a meson cross file
# gives a fixed argv.
LINK_WRAPPER="$(cd "$(dirname "$0")" && pwd)/bare-link-wrapper.sh"

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
    # ⚠️ `third-party` IS NOT OPTIONAL, AND ONLY THE SECOND FAMILY SHOWED IT.
    # aarch64's builtins include `emupac.cpp`, which includes
    # `siphash/SipHash.h` from the monorepo's third-party tree. riscv builds
    # without it, so the sparse set was correct for two years of one family and
    # wrong the moment a second was added.
    git -C "$WORK/llvm-src" sparse-checkout set compiler-rt cmake llvm/cmake third-party
fi

for profile in "${PROFILES[@]}"; do
    set -- $profile
    triple="$1"; march="$2"; mabi="$3"; mcmodel="$4"; cpu_family="$5"; extra="$6"
    [ "$extra" = "-" ] && extra=""
    # ⚠️ AN ABSENT AXIS IS AN ABSENT FLAG, NOT AN EMPTY ONE. 32-bit ARM has no
    # `-mcmodel`, and `-mcmodel=` with nothing after it is an error rather than
    # a no-op — so the flag is built here and interpolated as a whole.
    mcmodel_flag=""
    [ "$mcmodel" != "-" ] && mcmodel_flag="-mcmodel=$mcmodel"

    # ⚠️⚠️ COMPILER-RT AND PICOLIBC WANT DIFFERENT TRIPLES FOR THE SAME MACHINE,
    # AND THE DISAGREEMENT IS SILENT.
    #
    # picolibc is built for `thumbv6m-none-eabi`, which is what mcpp's target
    # table spells and what a consumer writes. compiler-rt's architecture
    # detection does not recognise a `thumb*` triple: measured, configuring with
    # `thumbv6m-none-eabi` produces a build tree with NO builtins target at all
    # — cmake succeeds, ninja reports "no work to do", and the failure surfaces
    # as a missing file at the copy below. With `armv6m-none-eabi` the same
    # configuration prints
    #
    #     For armv6m builtins preferring arm/addsf3.S to addsf3.c
    #
    # and emits `libclang_rt.builtins-armv6m.a`.
    #
    # ⚠️ AND THE ARCHIVE IS NAMED AFTER THAT TRIPLE, NOT THE OTHER ONE. mcpp
    # asks for `clang_rt.builtins-<arch of the target triple>`, which is
    # `thumbv6m` — so the file is RENAMED into the payload under the name the
    # consumer will ask for. Leaving it as compiler-rt spelled it would ship a
    # sysroot whose builtins exist and cannot be found.
    arch="${triple%%-*}"
    crt_triple="$triple"
    crt_arch="$arch"
    case "$FAMILY" in
        arm) crt_triple="${triple/thumb/armv}"
             crt_triple="${crt_triple/armvv/armv}"
             crt_arch="${crt_triple%%-*}" ;;
    esac
    echo "==> $march/$mabi ($triple)"

    prefix="$STAGE/staging/$march/$mabi"
    cross="$WORK/cross-$march-$mabi.txt"

    # Semihosting is how a bare image reaches the host through the debugger
    # channel. picolibc implements it for arm/aarch64 and riscv; there is no
    # x86 semihosting protocol, so that family gets `stdout` from whatever the
    # board supplies instead.
    semihost=true
    lld_emul=""
    # ⚠️ THE DEFAULT LOAD ADDRESSES ARE A FAMILY FACT, AND LEAVING THEM AT
    # RISCV'S SHIPPED A SYSROOT THAT LINKED AND THEN HUNG.
    #
    # picolibc.ld carries these as defaults; a board package normally supplies
    # its own script and overrides them. But an aarch64 image linked with
    # riscv's 0x80000000 lands outside qemu `virt`'s default 128 MB of RAM
    # (which starts at 0x40000000), so `-kernel` loads nothing and the machine
    # sits there. Measured: the same image runs when qemu is given 4 GB.
    #
    #   riscv   virt RAM base   0x80000000
    #   aarch64 virt RAM base   0x40000000
    #   x86_64  multiboot load  0x00100000  (1 MiB, above the legacy hole)
    #   arm     Cortex-M reset vector   0x00000000  (RAM at 0x20000000)
    flash_addr=0x80000000; ram_addr=0x80400000
    case "$FAMILY" in
        aarch64) flash_addr=0x40000000; ram_addr=0x40400000 ;;
        x86)     flash_addr=0x00100000; ram_addr=0x00500000
                 semihost=false; lld_emul=elf_x86_64 ;;
        # ⚠️ M-profile's map is ARCHITECTURAL, not a board's choice: the vector
        # table is fetched from address 0 and SRAM begins at 0x20000000. A board
        # normally supplies its own script; these defaults exist so an image
        # linked without one still lands where the hardware looks.
        arm)     flash_addr=0x00000000; ram_addr=0x20000000 ;;
    esac

    if [ -n "$lld_emul" ]; then
        [ -x "$LINK_WRAPPER" ] || { echo "missing $LINK_WRAPPER" >&2; exit 2; }
        export BARE_LLVM="$LLVM_DIR" BARE_TRIPLE="$triple" BARE_MARCH="$march" \
               BARE_MCMODEL="$mcmodel_flag" BARE_EXTRA="$extra" BARE_EMUL="$lld_emul"
        CC_BIN="$LINK_WRAPPER"
    else
        CC_BIN="$LLVM_DIR/bin/clang"
    fi

    # ⚠️ `--no-default-config` is mandatory, not hygiene. The llvm payload ships
    # bin/clang.cfg with an unconditional `-isystem <glibc>/include`, a hardcoded
    # `-Wl,--dynamic-linker=.../ld-linux-x86-64.so.2` and `-L .../lib64` -- none
    # of it guarded by target. Without this flag the host glibc <limits.h> wins
    # over the freestanding one and compiler-rt dies on `gnu/stubs-32.h`.
    # meson wants each extra flag as its own array element; an empty string
    # would reach clang as an argument and be reported as a missing file.
    extra_meson=""
    [ -n "$extra" ] && extra_meson=", '$extra'"
    mcmodel_meson=""
    [ -n "$mcmodel_flag" ] && mcmodel_meson=", '$mcmodel_flag'"
    # ⚠️ NOT DECLARED FOR x86: the wrapper above IS the linker, and naming
    # ld.lld here would make meson probe it through a driver that cannot link.
    if [ -n "$lld_emul" ]; then
        ld_lines=""
    else
        ld_lines="c_ld   = '$LLVM_DIR/bin/ld.lld'
cpp_ld = '$LLVM_DIR/bin/ld.lld'"
    fi
    cat > "$cross" <<EOF
[binaries]
c   = ['$CC_BIN', '--no-default-config', '-target', '$triple', '-march=$march', '-mabi=$mabi'$mcmodel_meson, '-nostdlib'$extra_meson]
cpp = ['$CC_BIN', '--no-default-config', '-target', '$triple', '-march=$march', '-mabi=$mabi'$mcmodel_meson, '-nostdlib'$extra_meson]
ar     = '$LLVM_DIR/bin/llvm-ar'
nm     = '$LLVM_DIR/bin/llvm-nm'
strip  = '$LLVM_DIR/bin/llvm-strip'
$ld_lines

[host_machine]
system = 'none'
cpu_family = '$cpu_family'
cpu = '$cpu_family'
endian = 'little'

[properties]
c_args = ['-Werror=double-promotion', '-fshort-enums']
skip_sanity_check = true
has_link_defsym = true
default_flash_addr = '$flash_addr'
default_flash_size = '0x00400000'
default_ram_addr   = '$ram_addr'
default_ram_size   = '0x00200000'
EOF

    rm -rf "$WORK/pb-$march-$mabi"
    meson setup "$WORK/pb-$march-$mabi" "$WORK/picolibc-$PICOLIBC_VERSION" \
        --cross-file "$cross" -Dtests=false -Dmultilib=false \
        -Dpicocrt=true -Dsemihost=$semihost --prefix="$prefix" >/dev/null
    ninja -C "$WORK/pb-$march-$mabi" >/dev/null
    ninja -C "$WORK/pb-$march-$mabi" install >/dev/null

    # ⚠️ THE C++ COMPILER MUST BE TARGETED TOO, AND ONLY THE SECOND FAMILY
    # SHOWED IT. aarch64's builtins include `emupac.cpp`; without
    # CMAKE_CXX_COMPILER_TARGET that one file is compiled for the HOST and dies
    # on `unknown register name 'x30' in asm`. riscv's builtins are all C and
    # assembly, so a C-and-ASM-only configuration was correct for one family and
    # silently wrong for the next.
    rm -rf "$WORK/crtb-$march-$mabi"
    cmake -S "$WORK/llvm-src/compiler-rt/lib/builtins" \
          -B "$WORK/crtb-$march-$mabi" -G Ninja \
          -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
          -DCMAKE_SYSTEM_NAME=Generic \
          -DCMAKE_C_COMPILER="$LLVM_DIR/bin/clang" \
          -DCMAKE_ASM_COMPILER="$LLVM_DIR/bin/clang" \
          -DCMAKE_CXX_COMPILER="$LLVM_DIR/bin/clang++" \
          -DCMAKE_AR="$LLVM_DIR/bin/llvm-ar" \
          -DCMAKE_NM="$LLVM_DIR/bin/llvm-nm" \
          -DCMAKE_RANLIB="$LLVM_DIR/bin/llvm-ranlib" \
          -DCMAKE_C_COMPILER_TARGET="$crt_triple" \
          -DCMAKE_ASM_COMPILER_TARGET="$crt_triple" \
          -DCMAKE_CXX_COMPILER_TARGET="$crt_triple" \
          -DCMAKE_C_FLAGS="--no-default-config -march=$march -mabi=$mabi $mcmodel_flag $extra -ffreestanding" \
          -DCMAKE_ASM_FLAGS="--no-default-config -march=$march -mabi=$mabi $mcmodel_flag $extra" \
          -DCMAKE_CXX_FLAGS="--no-default-config -march=$march -mabi=$mabi $mcmodel_flag $extra -ffreestanding" \
          -DCOMPILER_RT_BAREMETAL_BUILD=ON \
          -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
          -DCOMPILER_RT_OS_DIR=baremetal \
          -DLLVM_CMAKE_DIR="$WORK/llvm-src/llvm/cmake" \
          -DCMAKE_INSTALL_PREFIX="$prefix" >/dev/null
    ninja -C "$WORK/crtb-$march-$mabi" >/dev/null

    mkdir -p "$STAGE/include/$march/$mabi" "$STAGE/lib/$march/$mabi"
    cp -a "$prefix/include/." "$STAGE/include/$march/$mabi/"
    cp -a "$prefix/lib/." "$STAGE/lib/$march/$mabi/"
    cp "$WORK/crtb-$march-$mabi/lib/baremetal/libclang_rt.builtins-$crt_arch.a" \
       "$STAGE/lib/$march/$mabi/libclang_rt.builtins-$arch.a"

    # Fail closed on the exact gap this artifact exists to close. Reaching here
    # with the builtins missing would ship a sysroot whose printf cannot link.
    #
    # ⚠️ Counted, not `grep -q`. Under `pipefail` a matching `grep -q` closes
    # the pipe the moment it matches, llvm-nm takes SIGPIPE, and the pipeline
    # reports 141 -- so the check fails EXACTLY when it should pass. This guard
    # did that on its first run against a library that was perfectly fine.
    # ⚠️ THE 128-BIT SHIFT CHECK IS A RISCV FACT, NOT A UNIVERSAL ONE. rv64 has
    # no instruction for them, so picolibc's ryu float formatting leaves
    # `__ashlti3`/`__lshrti3` undefined and the first bare-metal printf fails at
    # LINK time. aarch64 and x86_64 have the instructions, and their builtins
    # legitimately do not export those symbols — asserting it there would fail a
    # library that is correct.
    #
    # What IS universal: the builtins archive must exist and be non-empty, and
    # the assertion must not accept an EMPTY symbol listing as a pass.
    blt="$STAGE/lib/$march/$mabi/libclang_rt.builtins-$arch.a"
    [ -s "$blt" ] || { echo "builtins archive missing or empty: $blt" >&2; exit 1; }
    total=$("$LLVM_DIR/bin/llvm-nm" "$blt" | grep -cE ' T ' || true)
    [ "$total" -ge 20 ] \
        || { echo "builtins for $march/$mabi export only $total text symbols — llvm-nm likely failed rather than the library being small" >&2; exit 1; }
    if [ "$FAMILY" = riscv ]; then
        # Counted, not `grep -q`. Under `pipefail` a matching `grep -q` closes
        # the pipe the moment it matches, llvm-nm takes SIGPIPE, and the
        # pipeline reports 141 -- so the check fails EXACTLY when it should
        # pass. This guard did that on its first run against a library that was
        # perfectly fine.
        shifts=$("$LLVM_DIR/bin/llvm-nm" "$blt" | grep -cE ' T (__ashlti3|__lshrti3)$')
        [ "$shifts" -ge 2 ] \
            || { echo "builtins for $march/$mabi lack the 128-bit shifts picolibc printf needs (found $shifts/2)" >&2; exit 1; }
    fi
    required="libc.a libm.a picolibc.ld picolibcpp.ld"
    # Semihosting is a family fact; see the cross-file note above.
    [ "$semihost" = true ] && required="$required libsemihost.a crt0-semihost.o"
    for f in $required; do
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
    echo "family  $FAMILY"
    echo "profiles"
    for profile in "${PROFILES[@]}"; do set -- $profile; echo "  $2/$3  ($1)"; done
} > "$STAGE/BUILDINFO"

asset="$OUT/picolibc-$FAMILY-$PICOLIBC_VERSION.tar.gz"
# Reproducible tar: fixed owner/mtime and a sorted member order, so two runs of
# this script on the same inputs produce the same bytes and the same sha256.
tar --sort=name --owner=0 --group=0 --numeric-owner \
    --mtime="@0" --format=gnu \
    -czf "$asset" -C "$(dirname "$STAGE")" "$(basename "$STAGE")"
sha256sum "$asset" | sed "s| .*/| |" > "$asset.sha256"

echo "==> $asset"
cat "$asset.sha256"
du -sh "$asset"
