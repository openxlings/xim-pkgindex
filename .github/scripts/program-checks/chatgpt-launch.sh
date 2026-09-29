#!/usr/bin/env bash
# Starts the installed ChatGPT on a virtual X server and requires it to stay up
# in the three situations where Chromium could reach for its Qt UI:
#
#   default   nothing asked for: GTK, which gtk3 (a DT_NEEDED) provides
#   kde       XDG_CURRENT_DESKTOP=KDE KDE_SESSION_VERSION=6: the desktop that
#             makes Chromium look for libqt6_shim.so
#   qt        --ui-toolkit=qt: the flag that makes it look for one
#
# The payload no longer ships libqt5_shim.so / libqt6_shim.so (nor the Qt
# packages they needed), so the last two are a dlopen that finds nothing. That
# has to end in GTK and not in a crash, and this is the only place it is run:
# `ci-test.yml` installs a recipe and never starts it, and chatgpt.sh runs the
# helpers, not the app.
#
# `default` is the control. If it does not stay up either, the app does not run
# on this runner at all and the other two say nothing about Qt; the script
# says so instead of blaming the shims.
#
# Needs a display (xvfb-run) and `chatgpt` on PATH -- the xvm shim, because it
# carries the environment config() registered (XDG_DATA_DIRS for gtk3's
# GSettings schemas, the graphics discovery variables). Every criterion prints
# one READING line; the script exits non-zero on the first that does not hold.
set -uo pipefail
: "${CHATGPT_APP:?CHATGPT_APP must name the installed app/ directory}"

reading() { printf 'READING %s: %s\n' "$1" "$2"; }
fail() { echo "::error::$*"; exit 1; }

[ -n "${DISPLAY:-}" ] || fail "no display: run this under xvfb-run"
command -v chatgpt >/dev/null || fail "chatgpt is not on PATH (the xvm shim of the installed package)"
[ -x "$CHATGPT_APP/ChatGPT" ] || fail "no executable at $CHATGPT_APP/ChatGPT"

# The browser process: the ChatGPT of this payload that was not started with
# --type=... (the zygote, GPU, renderer and utility children all are).
main_pid() {
    local p
    for p in $(pgrep -f "$CHATGPT_APP/ChatGPT" 2>/dev/null); do
        tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -q -- '--type=' || { echo "$p"; return; }
    done
}

stop_app() {
    pkill -f "$CHATGPT_APP/ChatGPT" 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -f "$CHATGPT_APP/ChatGPT" >/dev/null 2>&1 || return 0
        sleep 1
    done
    pkill -9 -f "$CHATGPT_APP/ChatGPT" 2>/dev/null
}

# run_case <name> [VAR=value ...] -- [app args ...]
run_case() {
    local name=$1; shift
    local -a envs=()
    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
    shift
    local dir; dir=$(mktemp -d)
    stop_app
    # --no-sandbox: hosted runners restrict unprivileged user namespaces, and
    # the AppArmor profile that would allow them needs root. The sandbox is not
    # what is under test. --disable-gpu: no GPU here, and the GPU process is
    # not either.
    # LD_DEBUG=libs only makes the loader say what it looked for: whether the
    # Qt shim was asked for at all is printed, not asserted (see below).
    env LD_DEBUG=libs "${envs[@]}" chatgpt --no-sandbox --disable-gpu \
        "--user-data-dir=$dir/profile" "$@" >"$dir/out.log" 2>&1 &
    local pid=""
    for _ in $(seq 1 30); do
        pid=$(main_pid)
        [ -n "$pid" ] && break
        sleep 1
    done
    local why=""
    [ "$name" = default ] && why=" (the control: without Qt in play the app does not stay up on this runner, so the other cases say nothing)"
    if [ -z "$pid" ]; then
        grep -av '^ *[0-9]*:' "$dir/out.log" | tail -n 60
        stop_app
        fail "$name: the ChatGPT browser process never started$why"
    fi
    # Long enough for the toolkit to be chosen and the first window to be
    # made; two looks, so a process that dies late is not taken for one that
    # stays.
    sleep 20
    kill -0 "$pid" 2>/dev/null || { grep -av '^ *[0-9]*:' "$dir/out.log" | tail -n 60; stop_app; fail "$name: exited within 20s$why"; }
    sleep 10
    kill -0 "$pid" 2>/dev/null || { grep -av '^ *[0-9]*:' "$dir/out.log" | tail -n 60; stop_app; fail "$name: exited within 30s$why"; }
    local maps; maps=$(cat "/proc/$pid/maps" 2>/dev/null)
    local gtk=0 qt=0
    grep -q 'libgtk-3' <<<"$maps" && gtk=1
    grep -qi 'libQt' <<<"$maps" && qt=1
    # Informational: a 0 here means the app never reached for the shim, so the
    # case exercised nothing and the `up 30s` above is the control again.
    local asked; asked=$(grep -ac 'libqt[56]_shim' "$dir/out.log")
    reading "$name" "pid=$pid up 30s, libgtk-3 mapped=$gtk, Qt mapped=$qt, loader lookups of a Qt shim=$asked"
    grep -av '^ *[0-9]*:' "$dir/out.log" | tail -n 15 | sed 's/^/    | /'
    stop_app
    [ "$qt" -eq 0 ] || fail "$name: a Qt library is mapped into the app"
    rm -rf "$dir"
    return 0
}

run_case default --
run_case kde XDG_CURRENT_DESKTOP=KDE KDE_SESSION_VERSION=6 --
run_case qt -- --ui-toolkit=qt
