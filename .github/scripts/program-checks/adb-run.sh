#!/usr/bin/env bash
# adb-run.sh prebuild | run
#
# Measures the installed adb-run ($ADB_RUN) on an Android emulator: a program
# that reads `data/data.txt` relative to its own directory and relative to its
# working directory. `prebuild` compiles the program with the runner image's
# NDK before the emulator starts; `run` executes the criteria inside the
# emulator step. The variable MCPP_RUNTIME_FILES is written by hand here, in
# the format mcpp hands every runner.
set -uo pipefail

W="$RUNNER_TEMP/adb-run"
reading() { printf 'READING %s: %s\n' "$1" "$2"; }
fail() { echo "::error::$*"; exit 1; }
contains() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

case "${1:-}" in
prebuild)
    rm -rf "$W"; mkdir -p "$W/host dir/data"
    NDK="${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_HOME:-}}"
    CC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android24-clang"
    [ -x "$CC" ] || fail "no NDK clang at $CC (ANDROID_NDK_LATEST_HOME=${ANDROID_NDK_LATEST_HOME:-unset})"
    cat > "$W/probe.c" <<'C'
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int reads(const char *label, const char *path) {
    char buf[64] = {0};
    FILE *f = fopen(path, "r");
    if (!f) { printf("%s: open failed: %s\n", label, path); return 0; }
    if (!fgets(buf, sizeof buf, f)) buf[0] = 0;
    fclose(f);
    printf("%s: %s", label, buf);
    return strncmp(buf, "marker-634", 10) == 0;
}

int main(int argc, char **argv) {
    char self[PATH_MAX];
    ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1);
    if (n < 0) return 4;
    self[n] = 0;
    char beside[PATH_MAX];
    snprintf(beside, sizeof beside, "%s/data/data.txt", dirname(self));
    int a = reads("beside-program", beside);
    int b = reads("working-directory", "data/data.txt");
    printf("args:");
    for (int i = 1; i < argc; ++i) printf(" [%s]", argv[i]);
    printf("\n");
    return (a && b) ? 0 : 3;
}
C
    "$CC" -o "$W/probe" "$W/probe.c" || fail "the probe did not compile"
    file "$W/probe"
    printf 'marker-634\n' > "$W/host dir/data/data.txt"
    printf 'data/data.txt\t%s\n' "$W/host dir/data/data.txt" > "$W/runtime-files.tsv"
    printf 'data/data.txt %s\n' "$W/host dir/data/data.txt" > "$W/no-tab.tsv"
    : > "$W/empty.tsv"
    ;;
run)
    : "${ADB_RUN:?ADB_RUN must name the installed program}"
    # The SDK's adb, which started the server the emulator is attached to.
    export PATH="$ANDROID_HOME/platform-tools:$PATH"
    adb wait-for-device
    reading devices "$(adb devices | tr '\n' '|')"
    cd "$W" || exit 1

    # 1. Without the variable nothing is transferred: the program runs, and
    #    cannot open its file.
    out=$("$ADB_RUN" "$W/probe" "a b" c 2>&1); rc=$?
    reading without "exit=$rc $(printf '%s' "$out" | tr '\n' '|')"
    [ "$rc" -eq 3 ] || fail "without MCPP_RUNTIME_FILES: expected exit 3, got $rc"
    contains "$out" "args: [a b] [c]" || fail "the arguments did not arrive intact"

    # 2. With the variable, the file is beside the program and in its working
    #    directory, and the program's status is returned.
    out=$(MCPP_RUNTIME_FILES="$W/runtime-files.tsv" "$ADB_RUN" "$W/probe" "a b" 2>&1); rc=$?
    reading with "exit=$rc $(printf '%s' "$out" | tr '\n' '|')"
    [ "$rc" -eq 0 ] || fail "with MCPP_RUNTIME_FILES: expected exit 0, got $rc"
    contains "$out" "beside-program: marker-634" || fail "the file is not beside the program"
    contains "$out" "working-directory: marker-634" || fail "the file is not in the working directory"

    # 3. An empty list transfers nothing.
    out=$(MCPP_RUNTIME_FILES="$W/empty.tsv" "$ADB_RUN" "$W/probe" 2>&1); rc=$?
    reading empty "exit=$rc"
    [ "$rc" -eq 3 ] || fail "an empty list: expected exit 3, got $rc"

    # 4. A malformed list is refused, naming the line.
    out=$(MCPP_RUNTIME_FILES="$W/no-tab.tsv" "$ADB_RUN" "$W/probe" 2>&1); rc=$?
    reading no-tab "exit=$rc $(printf '%s' "$out" | tr '\n' '|')"
    [ "$rc" -eq 2 ] || fail "a line without a TAB: expected exit 2, got $rc"
    contains "$out" "no-tab.tsv:1 has no TAB" || fail "the refusal does not name the line"

    # 5. Nothing a run pushed is left on the device.
    left=$(adb shell ls /data/local/tmp 2>/dev/null | tr -d '\r')
    reading left "$(printf '%s' "$left" | tr '\n' ' ')"
    contains "$left" "adb-run." && fail "a run directory was left on the device"

    echo "adb-run: every criterion held"
    ;;
*)
    echo "usage: adb-run.sh prebuild|run" >&2
    exit 2
    ;;
esac
exit 0
