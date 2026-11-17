#!/usr/bin/env bash
# newlib-arm-none-eabi: newlib and newlib-nano for every multilib of
# xim:arm-none-eabi-gcc, as a sysroot that compiler selects with
# `--sysroot=<this package>/arm-none-eabi`:
#
#   arm-none-eabi/include/               newlib's headers
#   arm-none-eabi/include/newlib-nano/   nano's newlib.h (nano.specs puts it first)
#   arm-none-eabi/lib/{nano,nosys,rdimon,...}.specs
#   arm-none-eabi/lib/<multilib>/        libc.a libm.a libg.a libnosys.a librdimon.a crt0.o ...
#                                        libc_nano.a libg_nano.a librdimon_nano.a
#
# The names are Arm GNU Toolchain's, so a project generated for it (STM32CubeMX:
# `--specs=nano.specs --specs=nosys.specs`) links unchanged.
#
#   newlib.sh <newlib-version> <sources> <arm-none-eabi-gcc prefix> <out> <work>
#
# <sources> holds newlib-<v>.tar.gz, already checked. The multilibs are the
# compiler's own (`-print-multi-lib`): newlib's configure builds one per row,
# and every row is asserted below. The configure flags are Arm's
# (build-toolchain.sh of the Arm GNU Toolchain) for both variants.
#
# The checks link as CubeMX does, for three rows, and look at which archive
# each one took: a library in the wrong multilib directory links cleanly and
# is only wrong at run time. With qemu-system-arm on PATH (the factory
# installs it; REQUIRE_QEMU=1 makes it mandatory) a semihosting program runs
# on mps2-an385 (Cortex-M3) and mps2-an386 (Cortex-M4, hard float).
set -euo pipefail

nv="$1"; src="$(cd "$2" && pwd)"; gcc="$(cd "$3" && pwd)"; out="$4"; w="$5"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target=arm-none-eabi
j="$(nproc)"
mkdir -p "$w" "$out"; out="$(cd "$out" && pwd)"; cd "$w"
export PATH="$gcc/bin:$PATH"
die() { printf '[newlib] %s\n' "$*" >&2; exit 1; }

tar -xzf "$src/newlib-$nv.tar.gz"

common=(--target=$target --disable-nls --disable-newlib-supplied-syscalls
        --enable-newlib-retargetable-locking --enable-newlib-reent-check-verify MAKEINFO=true)

build() {   # name, CFLAGS_FOR_TARGET, configure flags...
    local name="$1" cflags="$2"; shift 2
    mkdir -p "b-$name" && cd "b-$name"
    CFLAGS_FOR_TARGET="$cflags" "../newlib-$nv/configure" "${common[@]}" --prefix="$w/inst-$name" "$@" \
        >"$w/$name-configure.log" 2>&1
    make -j"$j" MAKEINFO=true >"$w/$name-make.log" 2>&1
    make install MAKEINFO=true >"$w/$name-install.log" 2>&1
    cd "$w"
}

build newlib "-O2 -ffunction-sections -fdata-sections" \
    --enable-newlib-io-long-long --enable-newlib-io-c99-formats --enable-newlib-register-fini
build nano "-Os -ffunction-sections -fdata-sections" \
    --enable-newlib-reent-small --disable-newlib-fvwrite-in-streamio \
    --disable-newlib-fseek-optimization --disable-newlib-wide-orient \
    --enable-newlib-nano-malloc --disable-newlib-unbuf-stream-opt --enable-lite-exit \
    --enable-newlib-global-atexit --enable-newlib-nano-formatted-io

# The sysroot: newlib whole, then nano's libraries beside it under Arm's names.
root="$out/$target"
rm -rf "$root"; cp -a "$w/inst-newlib/$target" "$root"
mkdir -p "$root/include/newlib-nano"
cp "$w/inst-nano/$target/include/newlib.h" "$root/include/newlib-nano/newlib.h"
multilibs="$(arm-none-eabi-gcc -print-multi-lib | sed 's/;.*//')"
for m in $multilibs; do
    for l in libc libg librdimon; do
        cp "$w/inst-nano/$target/lib/$m/$l.a" "$root/lib/$m/${l}_nano.a"
    done
    for f in libc.a libm.a libg.a libnosys.a librdimon.a crt0.o rdimon-crt0.o \
             libc_nano.a libg_nano.a librdimon_nano.a; do
        [[ -f "$root/lib/$m/$f" ]] || die "missing lib/$m/$f"
    done
done
for s in nano nosys rdimon; do
    [[ -f "$root/lib/$s.specs" ]] || die "missing lib/$s.specs"
done
cp "newlib-$nv/COPYING.NEWLIB" "newlib-$nv/COPYING.LIBGLOSS" "$out/"

# --- checks ---------------------------------------------------------------
mkdir -p "$w/t" && cd "$w/t"
cc=(arm-none-eabi-gcc --sysroot="$root")
printf '#include <stdio.h>\nint main(void){ printf("%%d\\n", 42); return 0; }\n' > t.c

took() {    # expected archive (relative to the sysroot), flags... -> it is the libc linked
    local want="$1"; shift
    "${cc[@]}" "$@" t.c -o t.elf -Wl,-t > trace 2>&1 || { cat trace >&2; die "link failed: $*"; }
    grep -q "$root/lib/$want" trace || { grep -E 'libc(_nano)?\.a' trace >&2; die "$* did not link lib/$want"; }
}
took thumb/v7e-m+fp/hard/libc_nano.a -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard --specs=nano.specs --specs=nosys.specs
took thumb/v6-m/nofp/libc_nano.a     -mcpu=cortex-m0 -mthumb --specs=nano.specs --specs=nosys.specs
took thumb/v7-m/nofp/libc.a          -mcpu=cortex-m3 -mthumb --specs=nosys.specs
# The hard-float row really is hard float (Tag_ABI_VFP_args), not a soft-float
# library in a hard-float directory.
"${cc[@]}" -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard --specs=nano.specs --specs=nosys.specs t.c -o t.elf
arm-none-eabi-readelf -A t.elf | grep -q 'Tag_ABI_VFP_args: VFP registers' || die "cortex-m4 hard float: not VFP-register ABI"
# nano.specs puts nano's newlib.h first; without it the full one is seen.
echo '#include <stdio.h>' | "${cc[@]}" -mcpu=cortex-m4 -mthumb --specs=nano.specs -E -dM - | grep -q _NANO_FORMATTED_IO \
    || die "nano.specs does not select include/newlib-nano"
! echo '#include <stdio.h>' | "${cc[@]}" -mcpu=cortex-m4 -mthumb -E -dM - | grep -q _NANO_FORMATTED_IO \
    || die "the full newlib.h is not the default"

if command -v qemu-system-arm >/dev/null; then
    cat > run.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern void _start(void);
__attribute__((section(".vectors"), used))
static void (*const vectors[])(void) = { (void (*)(void))0x00400000, _start };
int main(void) {
    char *p = malloc(32);
    strcpy(p, "heap");
    volatile float x = 3.25f;
    printf("newlib: %s %d.%02d\n", p, (int)(x * 4), (int)(x * 400) % 100);
    return 0;
}
EOF
    run() {   # machine, cpu flags...
        local machine="$1"; shift
        "${cc[@]}" "$@" --specs=nano.specs --specs=rdimon.specs -T "$here/mps2.ld" run.c -o run.elf
        timeout 30 qemu-system-arm -M "$machine" -nographic -monitor none -serial none \
            -semihosting-config enable=on,target=native -kernel run.elf > run.out
        grep -q '^newlib: heap 13.00' run.out || { cat run.out >&2; die "$machine: wrong output"; }
    }
    run mps2-an385 -mcpu=cortex-m3 -mthumb
    run mps2-an386 -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard
    echo "qemu: ran on mps2-an385 and mps2-an386" > "$w/qemu.ok"
elif [[ "${REQUIRE_QEMU:-}" == 1 ]]; then
    die "qemu-system-arm is required (REQUIRE_QEMU=1) and is not on PATH"
fi
