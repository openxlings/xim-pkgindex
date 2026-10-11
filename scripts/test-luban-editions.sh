#!/usr/bin/env bash
# Luban editions from this checkout, used for real (xlings: Luban OS design
# part 2 §2; the aarch64 design §5): nano, tiny, tiny-musl and core are made
# and entered on this machine's architecture -- core builds and runs a C++23
# program with its own gcc -- and on x86_64 tiny is exported as a live ISO by
# its boot profile (virt: the 6.12 LTS virt kernel and limine from xlings-res)
# and boots under qemu (xim:qemu-x86, from the index) to its init. The
# aarch64 image paths are xlings' own CI (they need its newest client).
#
#   scripts/test-luban-editions.sh <home>     # xlings / luban on PATH (the build under test)
set -euo pipefail

home="$1"; mkdir -p "$home"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export XLINGS_HOME="$home"
log() { printf '\n== %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p "$home/bin"
cp "$(command -v xlings)" "$home/bin/xlings"
cp "$(dirname "$(readlink -f "$(command -v xlings)")")/luban" "$home/bin/luban"
[[ -f "$home/.xlings.json" ]] || printf '{"mirror":"GLOBAL","index_repos":[{"name":"xim","url":"%s"}]}\n' "$repo" > "$home/.xlings.json"
X() { "$home/bin/xlings" "$@"; }
L() { "$home/bin/luban" "$@"; }
X self init >/dev/null
X install -y xim:bwrap >/dev/null

arch="$(uname -m)"
for e in nano tiny luban-tiny-musl core; do
    log "luban new e-$e $e"
    L new "e-$e" "$e" || fail "luban new $e"
    rec="$(cat "$home/config/subos/e-$e/instance.json")"
    grep -q '"edition"' <<<"$rec" || fail "$e: no edition record"
done
X subos exec e-nano -- /usr/bin/xlings --version >/dev/null || fail "nano: its xlings"
L run e-tiny -- /bin/sh -c 'grep -q ID=luban /usr/share/factory/etc/os-release && grep -q luban-init /etc/inittab' \
    || fail "tiny: os-release / luban-init"
L run e-luban-tiny-musl -- /bin/sh -c 'ls /usr/lib/ld-musl-* /lib/ld-musl-* 2>/dev/null | grep -q musl' \
    || fail "tiny-musl: no musl loader"
L upgrade e-tiny --dry-run | grep -q "up to date" || fail "a fresh tiny is the newest"
L run e-luban-tiny-musl -- /bin/sh -c 'ls /usr/lib/ld-musl-'"$arch"'.so.1 /lib/ld-musl-'"$arch"'.so.1 2>/dev/null | grep -q .' \
    || fail "tiny-musl: not this machine's musl loader"

log "core: its own gcc builds C++23 ($arch)"
L run e-core -- /bin/sh -c 'cd /tmp && printf "import std;\nint main(){ std::println(\"core {}\", __cplusplus >= 202302L); }\n" > t.cpp \
    && g++ -std=c++23 -fmodules -fsearch-include-path -c bits/std.cc -o std.o && g++ -std=c++23 -fmodules t.cpp std.o -o t && ./t' \
    | tee "$home/core.out" | grep -q "core true" || fail "core: C++23 with import std"
L run e-core -- /bin/sh -c 'git --version && vim --version | head -1 && fish --version && make --version | head -1' \
    || fail "core: its tools"

if [[ "$arch" != x86_64 ]]; then
    echo "PASS ($arch): nano, tiny, tiny-musl, core made and entered; core builds C++23"
    exit 0
fi

log "luban export e-tiny tiny.iso --boot virt"
L export e-tiny "$home/tiny.iso" --boot virt || fail "export --boot virt"
grep -aq "console=ttyS0" "$home/tiny.iso" || fail "the virt profile's command line is not in the image"
ls "$home"/subos/e-tiny/root/usr/lib/modules/6.12.112-virt/vmlinuz >/dev/null || fail "the virt kernel is not in the root"

log "boot it (qemu, xim:qemu-x86)"
X install -y xim:qemu-x86 >/dev/null || fail "xim:qemu-x86"
qemu="$(ls "$home"/data/xpkgs/xim-x-qemu-x86/*/bin/qemu-system-x86_64 | head -1)"
accel=(); [[ -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)
console="$home/boot.log"
setsid "$qemu" "${accel[@]}" -m 2048 -smp 2 -nographic -no-reboot -nic none \
    -cdrom "$home/tiny.iso" -boot d > "$console" 2>&1 < /dev/null &
pid=$!
for _ in $(seq 150); do
    tr -d '\r' < "$console" | grep -aq "Please press Enter to activate this console" && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 2
done
kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
tr -d '\r' < "$console" | grep -aq "Linux version 6.12.112-virt" || { tail -30 "$console"; fail "not the virt kernel"; }
tr -d '\r' < "$console" | grep -aq "Please press Enter to activate this console" || { tail -30 "$console"; fail "did not reach its init"; }
echo "PASS: nano, tiny, tiny-musl, core made and entered; core builds C++23; tiny's ISO boots the virt kernel to its init"
