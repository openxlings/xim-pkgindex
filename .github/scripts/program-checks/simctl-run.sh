#!/usr/bin/env bash
# Runs the installed simctl-run ($SIMCTL_RUN) on iOS simulator bundles built
# here: a program that exits 7, a program that aborts, and a program that loads
# UIKit. Every criterion prints one READING line; the script exits non-zero on
# the first criterion that does not hold.
set -uo pipefail
: "${SIMCTL_RUN:?SIMCTL_RUN must name the installed program}"
RUNS="${RUNS:-10}"

W="$RUNNER_TEMP/simctl-run"
rm -rf "$W"; mkdir -p "$W"
cd "$W" || exit 1

reading() { printf 'READING %s: %s\n' "$1" "$2"; }
fail() { echo "::error::$*"; exit 1; }
# macOS has no `timeout`; a run that never returns must still end the step.
bounded() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }
# Substring tests without a pipe: under `pipefail`, `printf | grep -q` can
# report a match as a failure when grep exits before printf has written.
contains() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

SDK=$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null)
[ -n "$SDK" ] || fail "this runner has no iphonesimulator SDK"

make_app() {  # make_app <bundle-id> <C body> [extra link flags...]
    local id="$1" body="$2"; shift 2
    local app="$W/$id.app"
    mkdir -p "$app"
    printf '#include <stdio.h>\n#include <stdlib.h>\nint main(int argc, char **argv) {\n    puts("SIMCTL-RUN-MARKER");\n    for (int i = 1; i < argc; ++i) printf("arg=%%s\\n", argv[i]);\n    fflush(stdout);\n    %s\n}\n' "$body" > "$W/$id.c"
    xcrun --sdk iphonesimulator clang -target arm64-apple-ios17.0-simulator \
        -isysroot "$SDK" "$W/$id.c" -o "$app/probe" "$@" > "$W/$id.cc.txt" 2>&1 \
        || { cat "$W/$id.cc.txt"; fail "$id did not compile"; }
    cat > "$app/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>probe</string>
<key>CFBundleIdentifier</key><string>$id</string>
<key>CFBundleName</key><string>probe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
<key>MinimumOSVersion</key><string>17.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
<key>LSRequiresIPhoneOS</key><true/>
</dict></plist>
P
    codesign --force --sign - "$app" > /dev/null 2>&1 || fail "$id could not be signed ad hoc"
}
make_app org.xim-pkgindex.simctl-run.exit7 'return 7;'
make_app org.xim-pkgindex.simctl-run.abort 'abort();'
make_app org.xim-pkgindex.simctl-run.uikit 'return 7;' -framework UIKit
contains "$(otool -L "$W/org.xim-pkgindex.simctl-run.uikit.app/probe")" "/UIKit.framework/" \
    || fail "the UIKit probe does not load UIKit, so it cannot select the launch path"

# 1. A bundle that does not load UIKit: the application's status and output,
#    every time.
seen=0; statuses=""
i=0
while [ "$i" -lt "$RUNS" ]; do
    i=$((i + 1))
    out=$(bounded 300 "$SIMCTL_RUN" "$W/org.xim-pkgindex.simctl-run.exit7.app" one "two three" 2>&1); rc=$?
    if contains "$out" "SIMCTL-RUN-MARKER" && contains "$out" "arg=two three"; then
        seen=$((seen + 1))
    fi
    statuses="$statuses $rc"
    [ "$i" -eq 1 ] && reading exit7.first "exit=$rc $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
done
reading exit7 "output and arguments in $seen/$RUNS; statuses:$statuses"
[ "$seen" -eq "$RUNS" ] || fail "the output or the arguments were lost in $((RUNS - seen)) of $RUNS runs"
for s in $statuses; do [ "$s" -eq 7 ] || fail "a run returned $s, not the application's 7"; done

# 2. An aborting application: the signal, as the shell reports it.
out=$(bounded 300 "$SIMCTL_RUN" "$W/org.xim-pkgindex.simctl-run.abort.app" 2>&1); rc=$?
reading abort "exit=$rc $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
[ "$rc" -eq 134 ] || fail "an aborting application returned $rc, not 134"

# 3. A bundle whose executable loads UIKit takes the launch path and says that
#    the status is simctl's. The status itself is recorded, not asserted.
out=$(bounded 300 "$SIMCTL_RUN" "$W/org.xim-pkgindex.simctl-run.uikit.app" 2>&1); rc=$?
reading uikit "exit=$rc $(printf '%s' "$out" | tr '\n' '|' | cut -c1-400)"
contains "$out" "is launched; the status that follows is simctl's, not the application's" \
    || fail "a UIKit bundle did not take the launch path, or did not say whose status it returns"

# 4. A bare executable keeps the 0.1.0 path: spawned, its status returned.
out=$(bounded 300 "$SIMCTL_RUN" "$W/org.xim-pkgindex.simctl-run.exit7.app/probe" 2>&1); rc=$?
reading bare "exit=$rc $(printf '%s' "$out" | tr '\n' '|' | cut -c1-300)"
[ "$rc" -eq 7 ] || fail "a bare executable returned $rc, not 7"

echo "simctl-run: every criterion held"
