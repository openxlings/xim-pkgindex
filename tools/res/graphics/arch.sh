# shellcheck shell=bash
# The architecture a graphics build is for: the SubOS's, read from the C
# library it carries -- not this machine's name for itself, and not a constant.
# A payload is named <name>-<version>-linux-<arch>.tar.gz after it, and the
# multiarch directory and LLVM's native target follow it.
#
#   . arch.sh; ARCH="$(subos_arch "$SUBOS")" || exit 3
subos_arch() {   # <subos dir> -> x86_64 | aarch64
    local libc m
    libc="$(readlink -f "$1/lib/libc.so.6" 2>/dev/null)"
    [[ -f "$libc" ]] || { echo "no lib/libc.so.6 in $1" >&2; return 1; }
    m="$(od -An -t u2 -j 18 -N 2 "$libc" | tr -d ' ')"
    case "$m" in
        62)  echo x86_64 ;;
        183) echo aarch64 ;;
        *)   echo "$libc is for ELF machine $m, which this tree does not build for" >&2; return 1 ;;
    esac
}
