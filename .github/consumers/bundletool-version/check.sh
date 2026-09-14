#!/usr/bin/env bash
# The installed bundletool runs through the launcher its recipe wrote, with the
# JDK the recipe declares.
set -uo pipefail
: "${REGISTRY:?}"
fail() { echo "::error::bundletool-version: $*"; exit 1; }

launcher="$REGISTRY/data/xpkgs/xim-x-bundletool/1.18.3/bin/bundletool"
[ -x "$launcher" ] || fail "$launcher is absent or not executable"
java_home=$(sed -n 's/^JAVA_HOME="\(.*\)"$/\1/p' "$launcher")
echo "READING bundletool.java-home: $java_home"
[ -x "$java_home/bin/java" ] || fail "the JDK the launcher names has no bin/java"
out=$("$launcher" version 2>&1); rc=$?
echo "READING bundletool.version: exit=$rc $out"
[ "$rc" -eq 0 ] || fail "bundletool version exited $rc"
[ "$out" = "1.18.3" ] || fail "bundletool version printed '$out'"
echo "bundletool-version: every criterion held"
