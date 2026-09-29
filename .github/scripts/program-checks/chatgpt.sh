#!/usr/bin/env bash
# Runs what the installed ChatGPT payload ($CHATGPT_APP, its app/ directory)
# ships next to the GUI. `ci-test.yml` installs the recipe and removes it; it
# never executes anything inside it. The first release installed cleanly while
# every statically linked helper -- the codex app-server among them -- had been
# corrupted by elfpatch and dumped core, and the app could not get past its
# first screen. Every criterion prints one READING line; the script exits
# non-zero on the first one that does not hold.
#
# 1. Every executable ELF except the GUI itself runs `--version` without dying
#    from a signal. An unknown-argument exit is fine; a core dump is not.
# 2. The statically linked ones carry no RPATH/RUNPATH: nothing patched them.
# 3. Every x86_64 glibc object resolves through the payload's own loader with
#    nothing from outside the xlings home. musl and Android prebuilds are
#    skipped: the app never loads them on a glibc host.
# 4. The payload carries no Chromium Qt UI shim (libqt5_shim.so, libqt6_shim.so):
#    nothing declares the Qt packages they load, so a shim left in would be a
#    dlopen target that resolves nowhere. chatgpt-launch.sh starts the app in
#    the situations that look for one.
set -uo pipefail
: "${CHATGPT_APP:?CHATGPT_APP must name the installed app/ directory}"
home="${XLINGS_HOME:-$HOME/.xlings}"

reading() { printf 'READING %s: %s\n' "$1" "$2"; }
fail() { echo "::error::$*"; exit 1; }
is_elf() { [ "$(head -c4 "$1" 2>/dev/null | od -An -c | tr -d ' ')" = "177ELF" ]; }

# What landed, before judging it: a short payload reads as missing helpers.
reading "payload" "$(find "$CHATGPT_APP" -type f | wc -l) files, $(du -sb "$CHATGPT_APP" | cut -f1) bytes"
reading "disk" "$(df -h "$CHATGPT_APP" | tail -1)"
for f in resources/codex resources/rg resources/cua_node/bin/node; do
    reading "$f" "$(ls -l "$CHATGPT_APP/$f" 2>&1)"
done

# `chatgpt` is bin/chatgpt next to app/: it gates the sandbox, then execs the app
launcher="$(dirname "$CHATGPT_APP")/bin/chatgpt"
[ -x "$launcher" ] && sh -n "$launcher" || fail "no runnable launcher at $launcher"
grep -q "exec \"\$app/ChatGPT\" \"\$@\"" "$launcher" || fail "the launcher does not exec the app"
reading "launcher" "$launcher"

loader=$(readelf -l "$CHATGPT_APP/ChatGPT" | sed -n 's/.*interpreter: \(.*\)\]/\1/p')
reading "loader" "$loader"
case "$loader" in "$home"/*) ;; *) fail "ChatGPT's interpreter is not an xlings payload: $loader" ;; esac

static=0; ran=0
while IFS= read -r f; do
    is_elf "$f" || continue
    case "$f" in */ChatGPT|*.so|*.so.*|*.node) continue ;; esac
    # </dev/null: a helper reading stdin would eat the rest of the file list
    timeout 20 "$f" --version </dev/null >/dev/null 2>&1; rc=$?
    ran=$((ran + 1))
    reading "${f#"$CHATGPT_APP"/} --version" "exit=$rc"
    [ "$rc" -lt 128 ] || fail "${f#"$CHATGPT_APP"/} died with exit $rc"
    if ! readelf -l "$f" | grep -q "INTERP" && ! readelf -d "$f" 2>/dev/null | grep -q "(NEEDED)"; then
        static=$((static + 1))
        if readelf -d "$f" 2>/dev/null | grep -qE "\((RPATH|RUNPATH)\)"; then
            fail "statically linked ${f#"$CHATGPT_APP"/} was given an RPATH"
        fi
    fi
done < <(find "$CHATGPT_APP" -type f -perm -u+x)
reading "executables" "ran=$ran static-untouched=$static"
[ "$static" -ge 4 ] || fail "expected the static helpers (codex, codex-code-mode-host, rg, node_repl), found $static"

checked=0
while IFS= read -r f; do
    is_elf "$f" || continue
    case "$f" in *musl*|*android*) continue ;; esac
    file -b "$f" | grep -q "x86-64.*dynamically linked" || continue
    out=$("$loader" --list "$f" </dev/null 2>&1) || fail "${f#"$CHATGPT_APP"/}: $out"
    missing=$(printf '%s\n' "$out" | grep "not found")
    [ -z "$missing" ] || fail "${f#"$CHATGPT_APP"/}: $missing"
    host=$(printf '%s\n' "$out" | grep -oE "=> /[^ ]+" | grep -v "=> $home/")
    [ -z "$host" ] || fail "${f#"$CHATGPT_APP"/} resolves from the host: $host"
    checked=$((checked + 1))
done < <(find "$CHATGPT_APP" -type f)
reading "glibc objects resolved inside $home" "$checked"
[ "$checked" -gt 0 ] || fail "no dynamic objects were checked"

shims=$(find "$CHATGPT_APP" -name 'libqt*_shim.so' -print)
reading "Qt UI shims" "${shims:-none}"
[ -z "$shims" ] || fail "the payload still carries Chromium's Qt UI shims: $shims"
