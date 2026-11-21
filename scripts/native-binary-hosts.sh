#!/bin/sh
# Recipes that carry prebuilt native programs, installed on the hosts that
# catch what a Linux desktop does not (xlings#724):
#
#   native-binary-hosts.sh host <release.tar.gz> <index checkout> <packages...>
#       on THIS machine (a container: Alpine, with no glibc loader; the oldest
#       glibc the index supports) -- catches "the host has a glibc loader"
#       and "the host's glibc is new enough"
#   native-binary-hosts.sh root <release.tar.gz> <index checkout> <packages...>
#       in a root made like the Luban host machine (a static xlings, busybox
#       and bwrap, nothing of this machine) entered with bwrap -- catches
#       "the host has a distribution's tools", which is what Windows and
#       macOS users' installs go through
#
# Each package is installed from the checkout's index and must succeed; bun
# is run after (its payload is the platform binary the recipe chose). POSIX
# sh: a bare Alpine has no bash. The evidence goes to $EVIDENCE (default
# ./native-hosts-evidence).
set -eu
mode="$1"; tarball="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; index="$(cd "$3" && pwd)"; shift 3
evidence="${EVIDENCE:-$PWD/native-hosts-evidence}"
mkdir -p "$evidence"
export XLINGS_NON_INTERACTIVE=1 NO_COLOR=1
work="$(mktemp -d)"
mkdir -p "$work/rel" && tar -xzf "$tarball" -C "$work/rel"
rel="$(find "$work/rel" -path '*/bin/xlings' -type f | head -1)"
[ -x "$rel" ] || { echo "no bin/xlings in $tarball" >&2; exit 2; }
failed=""

if [ "$mode" = host ]; then
    (cd "$(dirname "$(dirname "$rel")")" && ./bin/xlings self install </dev/null) > "$evidence/self-install.log" 2>&1 \
        || { tail -20 "$evidence/self-install.log"; exit 1; }
    X="$HOME/.xlings/bin/xlings"
    "$X" --version
    "$X" config --index-repo "xim:$index"
    "$X" update > "$evidence/update.log" 2>&1 || { tail -20 "$evidence/update.log"; exit 1; }
    run() { "$X" "$@"; }
    bun_payloads="$HOME/.xlings/data/xpkgs"
elif [ "$mode" = root ]; then
    # The guest's static programs, from the index, in a tools home.
    tools="$work/tools"
    XLINGS_HOME="$tools" "$rel" install -y xim:busybox xim:bwrap > "$evidence/tools.log" 2>&1 \
        || { tail -20 "$evidence/tools.log"; exit 1; }
    busybox="$(find "$tools/data/xpkgs" -name busybox -type f | head -1)"
    bwrap="$(find "$tools/data/xpkgs" -name bwrap -type f | head -1)"
    R="$work/root"
    mkdir -p "$R/etc/xlings" "$R/xlings/bin" "$R/bin" "$R/sbin" "$R/usr/bin" "$R/usr/sbin" "$R/root" "$R/tmp" \
             "$R/proc" "$R/sys" "$R/dev" "$R/run" "$R/grant"
    cp "$rel" "$R/xlings/bin/xlings"
    [ -f "$(dirname "$rel")/luban" ] && cp "$(dirname "$rel")/luban" "$R/xlings/bin/luban"
    cp "$busybox" "$R/bin/busybox"; ln -sf busybox "$R/bin/sh"; cp "$bwrap" "$R/usr/bin/bwrap"
    ln -sf /xlings/bin/xlings "$R/usr/bin/xlings"
    printf 'root:x:0:0:root:/root:/bin/sh\n' > "$R/etc/passwd"; printf 'root:x:0:\n' > "$R/etc/group"
    cat /etc/resolv.conf > "$R/etc/resolv.conf"; echo xlings-carrier > "$R/etc/hostname"
    echo '{ "home": "/xlings" }' > "$R/etc/xlings/root.json"; echo '{}' > "$R/xlings/.xlings.json"
    chmod 1777 "$R/tmp"
    mkdir -p "$R/xlings/idx" && (cd "$index" && git ls-files -z | xargs -0 tar -cf - 2>/dev/null) | tar -xf - -C "$R/xlings/idx"
    inroot() {
        env -i "$bwrap" --unshare-user --uid 0 --gid 0 --bind "$R" / --dev /dev --proc /proc \
            --setenv HOME /root --setenv XLINGS_HOME /xlings --setenv XLINGS_NON_INTERACTIVE 1 --setenv NO_COLOR 1 \
            --setenv PATH /xlings/bin:/xlings/subos/current/bin:/usr/bin:/bin:/usr/sbin:/sbin "$@"
    }
    run() { inroot /xlings/bin/xlings "$@"; }
    # As the host machine's first probe does: its applets, and (from xlings
    # 2026.11.22.1) /lib64 linked to the home's runtime.
    run __carrier-probe || true
    run --version
    run config --index-repo xim:/xlings/idx
    run update > "$evidence/update.log" 2>&1 || { tail -20 "$evidence/update.log"; exit 1; }
    bun_payloads="$R/xlings/data/xpkgs"
else
    echo "usage: native-binary-hosts.sh host|root <release.tar.gz> <index> <packages...>" >&2; exit 2
fi

for p in "$@"; do
    n="$(echo "$p" | tr ':@/' '___')"
    echo "== $p"
    if run install -y "$p" > "$evidence/$n.log" 2>&1; then
        echo "   installed"
    else
        echo "   FAILED"; tail -25 "$evidence/$n.log" | sed 's/^/   | /'
        failed="$failed $p"
    fi
done

# bun: the binary the recipe put in place runs.
bun="$(find "$bun_payloads" -path '*xim-x-bun*/node_modules/bun/bin/bun.exe' 2>/dev/null | head -1)"
if [ -n "$bun" ]; then
    if [ "$mode" = root ]; then v="$(inroot "${bun#"$R"}" --version 2>&1)" || v="exit $?: $v"
    else v="$("$bun" --version 2>&1)" || v="exit $?: $v"; fi
    echo "bun --version: $v"
    case "$v" in [0-9]*.[0-9]*) ;; *) failed="$failed bun--version" ;; esac
fi
if [ "$mode" = root ]; then cp -r "$R/xlings/logs/hooks" "$evidence/hooks" 2>/dev/null || true
else cp -r "$HOME/.xlings/logs/hooks" "$evidence/hooks" 2>/dev/null || true; fi
[ -z "$failed" ] || { echo "failed:$failed"; exit 1; }
echo "all installed"
