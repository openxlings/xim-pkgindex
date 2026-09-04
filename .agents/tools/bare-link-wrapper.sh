#!/usr/bin/env bash
#
# bare-link-wrapper.sh — stand in for clang on a target where clang cannot link.
#
# ⚠️ WHY THIS EXISTS, AND WHY IT IS A TOOLCHAIN FACT RATHER THAN A PICOLIBC ONE.
#
# clang ships a BareMetal toolchain for arm, aarch64 and riscv but NOT for
# x86_64. On `x86_64-none-elf` it falls back to the generic GCC toolchain and
# hands the link to the host `gcc`/`collect2`, which cannot link a bare ELF.
# meson probes the linker THROUGH the compiler, so picolibc cannot even be
# configured for that target with clang as the driver.
#
# ⚠️ `-fuse-ld=lld` APPEARS TO FIX IT AND DOES NOT. Measured 2026-08-21: with an
# `lld` on PATH the probe succeeds; with PATH reduced to coreutils, BOTH the
# bare name and `-B<llvm>/bin` fall through to `collect2 ... [cannot find ld]`.
# The pass was ambient state, not the flag — and reading it as a fix is how a
# broken configuration ships.
#
# So the link is taken away from the driver entirely, which is exactly what
# mcpp's own engine does for this triple (`ld.lld -m elf_x86_64` directly).
#
# ⚠️ BUILD-TIME ONLY. Nothing in the produced sysroot depends on this file;
# mcpp links against the sysroot with its own direct `ld.lld` invocation.
#
# Configured entirely through the environment, because meson's cross file gives
# a fixed argv and cannot pass per-invocation options:
#
#   BARE_LLVM      llvm payload root  (required)
#   BARE_TRIPLE    e.g. x86_64-none-elf
#   BARE_MARCH     e.g. x86-64
#   BARE_MCMODEL   e.g. small
#   BARE_EXTRA     extra compile flags, may be empty (e.g. -mno-red-zone)
#   BARE_EMUL      ld.lld -m value    (e.g. elf_x86_64)
set -u

: "${BARE_LLVM:?BARE_LLVM is required}"
: "${BARE_EMUL:?BARE_EMUL is required}"
BARE_TRIPLE="${BARE_TRIPLE:-}"
BARE_MARCH="${BARE_MARCH:-}"
BARE_MCMODEL="${BARE_MCMODEL:-}"
BARE_EXTRA="${BARE_EXTRA:-}"

# ⚠️ A BARE `--version` IS A COMPILER PROBE, NOT A LINK. meson identifies the
# compiler by its banner; routing that to ld.lld makes meson report
# "Unknown compiler(s)" and stop before anything is built.
mode=link
for a in "$@"; do
    case "$a" in
        -c|-E|-S|-M|-MM|--version|-dumpmachine|-dumpversion|-print-*|-###) mode=compile ;;
    esac
done
[ "$mode" = compile ] && exec "$BARE_LLVM/bin/clang" "$@"

out=""; keep=(); srcs=(); reloc=0
args=("$@")
i=0
n=${#args[@]}
while [ "$i" -lt "$n" ]; do
    a="${args[$i]}"
    case "$a" in
        -o)
            out="${args[$((i + 1))]}"; i=$((i + 2)); continue ;;
        # ⚠️ TWO-TOKEN FLAGS MUST CONSUME THEIR VALUE. Dropping `-target` while
        # letting `x86_64-none-elf` fall through as a positional made ld.lld try
        # to open a file by that name — measured at 1111/1126 objects built.
        -target|-x|-include|-isystem|-idirafter)
            i=$((i + 2)); continue ;;
        # ⚠️ A PARTIAL LINK IS STILL A LINK. picolibc builds its crt0 objects
        # with `-r`; treating that as a full link resolves symbols the linker
        # script has not supplied yet ("undefined symbol: __stack").
        -r|--relocatable)
            reloc=1 ;;
        -Wl,*)
            IFS=, read -ra parts <<< "${a#-Wl,}"; keep+=("${parts[@]}") ;;
        -L*|-l*|-T*)
            keep+=("$a") ;;
        *.o|*.a|*.lo)
            keep+=("$a") ;;
        *.c|*.cc|*.cpp|*.S)
            srcs+=("$a") ;;
        # Everything else beginning with `-` is compile-only. Passing those
        # through is how the first attempt failed: `unknown argument '-D_LIBC'`.
        -*) ;;
        *)  keep+=("$a") ;;
    esac
    i=$((i + 1))
done

for src in "${srcs[@]:-}"; do
    [ -z "$src" ] && continue
    obj="$(mktemp).o"
    # shellcheck disable=SC2086
    "$BARE_LLVM/bin/clang" --no-default-config \
        ${BARE_TRIPLE:+-target "$BARE_TRIPLE"} \
        ${BARE_MARCH:+-march="$BARE_MARCH"} \
        ${BARE_MCMODEL:+"$BARE_MCMODEL"} \
        $BARE_EXTRA -nostdlib -ffreestanding \
        -c "$src" -o "$obj" || exit 1
    keep+=("$obj")
done

if [ "$reloc" = 1 ]; then
    exec "$BARE_LLVM/bin/ld.lld" -m "$BARE_EMUL" -r ${out:+-o "$out"} "${keep[@]}"
fi
exec "$BARE_LLVM/bin/ld.lld" -m "$BARE_EMUL" -Bstatic --no-dynamic-linker \
    ${out:+-o "$out"} "${keep[@]}"
