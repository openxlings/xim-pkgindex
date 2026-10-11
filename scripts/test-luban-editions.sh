#!/usr/bin/env bash
# Luban editions from this checkout, used for real (xlings: Luban OS design
# part 2 §2): nano, tiny and tiny-musl are made and entered; tiny is
# exported as a live ISO by its boot profile -- virt: the 6.12 LTS virt
# kernel and limine from xlings-res -- and boots under qemu to its init.
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

for e in nano tiny luban-tiny-musl; do
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

log "luban export e-tiny tiny.iso --boot virt"
L export e-tiny "$home/tiny.iso" --boot virt || fail "export --boot virt"
grep -aq "console=ttyS0" "$home/tiny.iso" || fail "the virt profile's command line is not in the image"
ls "$home"/subos/e-tiny/root/usr/lib/modules/6.12.112-virt/vmlinuz >/dev/null || fail "the virt kernel is not in the root"

log "boot it (qemu)"
accel=(); [[ -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)
console="$home/boot.log"
setsid qemu-system-x86_64 "${accel[@]}" -m 2048 -smp 2 -nographic -no-reboot -nic none \
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
echo "PASS: nano, tiny, tiny-musl made and entered; tiny's ISO boots the virt kernel to its init"
