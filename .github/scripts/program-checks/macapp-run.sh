#!/usr/bin/env bash
# Runs the installed macapp-run ($MACAPP_RUN) on application bundles built
# here. Every criterion prints one READING line; the script exits non-zero on
# the first criterion that does not hold.
set -uo pipefail
: "${MACAPP_RUN:?MACAPP_RUN must name the installed program}"

W="$RUNNER_TEMP/macapp-run"
rm -rf "$W"; mkdir -p "$W/elsewhere"
cd "$W" || exit 1

reading() { printf 'READING %s: %s\n' "$1" "$2"; }
fail() { echo "::error::$*"; exit 1; }
# has_line <text> <line>: an exact line of the text, tested without a pipe.
# Under `pipefail`, a pipe into `grep -q` can report a match as a failure when
# grep exits before the writer has finished.
has_line() {
    local line
    while IFS= read -r line; do
        [ "$line" = "$2" ] && return 0
    done <<< "$1"
    return 1
}

# The program reports what the main bundle resolves to, the resource it finds,
# and its arguments; it exits 7, or aborts when its first argument says so.
cat > probe.c <<'C'
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void print_url(const char *label, CFURLRef url) {
    char buf[4096];
    if (url && CFURLGetFileSystemRepresentation(url, true, (UInt8 *)buf, sizeof buf))
        printf("%s=%s\n", label, buf);
    else
        printf("%s=none\n", label);
}

int main(int argc, char **argv) {
    CFBundleRef bundle = CFBundleGetMainBundle();
    print_url("bundle", bundle ? CFBundleCopyBundleURL(bundle) : NULL);
    print_url("resource", bundle ? CFBundleCopyResourceURL(bundle, CFSTR("greeting"),
                                                           CFSTR("txt"), NULL) : NULL);
    printf("args=");
    for (int i = 1; i < argc; ++i) printf("%s%s", i > 1 ? "|" : "", argv[i]);
    printf("\n");
    fflush(stdout);
    if (argc > 1 && strcmp(argv[1], "abort") == 0) abort();
    return 7;
}
C
cc -o probe probe.c -framework CoreFoundation || fail "the probe did not compile"

make_bundle() {  # make_bundle <bundle> <CFBundleExecutable> [no-plist]
    local app="$W/$1"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    printf 'greeting\n' > "$app/Contents/Resources/greeting.txt"
    cp probe "$app/Contents/MacOS/probe"
    [ "${3:-}" = "no-plist" ] && return 0
    cat > "$app/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$2</string>
<key>CFBundleIdentifier</key><string>org.xim-pkgindex.macapp-run.probe</string>
<key>CFBundleName</key><string>Probe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
P
}
make_bundle Probe.app probe
make_bundle Missing.app absent
make_bundle NoPlist.app probe no-plist
# A binary property list: plutil reads it the same way.
make_bundle Binary.app probe
plutil -convert binary1 "$W/Binary.app/Contents/Info.plist" || fail "plutil could not convert"

root="$(cd "$W/Probe.app" && pwd)"

# 1. Arguments, output and status reach the caller; the main bundle and its
#    resource resolve.
out=$("$MACAPP_RUN" "$W/Probe.app" one "two three"); rc=$?
reading run "exit=$rc $(printf '%s' "$out" | tr '\n' ' ')"
[ "$rc" -eq 7 ] || fail "expected exit 7, got $rc"
has_line "$out" "args=one|two three" || fail "the arguments did not arrive intact"
has_line "$out" "bundle=$root" || fail "the main bundle is not $root"
has_line "$out" "resource=$root/Contents/Resources/greeting.txt" || fail "the resource did not resolve"

# 2. A relative bundle path with a trailing slash, from another directory.
out=$(cd "$W/elsewhere" && "$MACAPP_RUN" ../Probe.app/); rc=$?
reading relative "exit=$rc $(printf '%s' "$out" | tr '\n' ' ')"
[ "$rc" -eq 7 ] || fail "a relative bundle path: expected exit 7, got $rc"
has_line "$out" "resource=$root/Contents/Resources/greeting.txt" \
    || fail "a relative bundle path: the resource did not resolve"

# 3. A binary Info.plist.
"$MACAPP_RUN" "$W/Binary.app" > binary.out; rc=$?
reading binary-plist "exit=$rc"
[ "$rc" -eq 7 ] || fail "a binary Info.plist: expected exit 7, got $rc"

# 4. A signal reaches the caller as the shell reports it.
"$MACAPP_RUN" "$W/Probe.app" abort > /dev/null 2>&1; rc=$?
reading abort "exit=$rc"
[ "$rc" -eq 134 ] || fail "an aborting program: expected exit 134, got $rc"

# 5. The control: the same binary outside a bundle finds no resource, so the
#    resource criterion above distinguishes a bundle run from a bare one.
out=$(./probe); rc=$?
reading control "exit=$rc $(printf '%s' "$out" | tr '\n' ' ')"
has_line "$out" "resource=none" || fail "the control found a resource outside a bundle"

# 6. Refusals exit 2 and name what is missing.
refuse() {  # refuse <label> <expected stderr fragment> <operand>
    local err rc
    err=$("$MACAPP_RUN" "$3" 2>&1 >/dev/null); rc=$?
    reading "refuse.$1" "exit=$rc $err"
    [ "$rc" -eq 2 ] || fail "$1: expected exit 2, got $rc"
    case "$err" in *"$2"*) ;; *) fail "$1: the refusal does not say '$2'" ;; esac
}
printf 'x' > "$W/file.app"
refuse absent "does not exist" "$W/Absent.app"
refuse file "is not a directory" "$W/file.app"
refuse no-plist "has no Contents/Info.plist" "$W/NoPlist.app"
refuse missing-executable "has no Contents/MacOS/absent" "$W/Missing.app"

echo "macapp-run: every criterion held"
