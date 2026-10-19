#!/bin/sh
# In the Alpine container (tools/res/build.sh): every ELF under the given
# directories names no library search path of its own -- Alpine's builds say
# where they were built (libLLVM: /usr/lib/llvm22), which a Luban system
# refuses (a search path outside its checked closure). A bundle's programs
# find their libraries through its loader, or the path its recipe writes.
#
#   sh strip-rpath.sh <dir>...        (needs patchelf)
set -eu
for dir in "$@"; do
    [ -d "$dir" ] || continue
    find "$dir" -type f | while read -r f; do
        [ "$(head -c 4 "$f" | od -An -c | tr -d ' \n')" = '177ELF' ] || continue
        [ -n "$(patchelf --print-rpath "$f" 2>/dev/null)" ] || continue
        patchelf --remove-rpath "$f"
    done
done
