#!/usr/bin/env bash
# A recipe that declares `macosx` must not use a GNU-only `stat` flag.
#
# macOS ships BSD stat. `stat -c` is a GNU spelling and an ERROR there, and the
# failure mode is not a visible error but a silently empty capture:
#
#   pkgs/a/android-ndk.lua   `stat -c%s` measured a 30 MB BMI as 0 bytes, so the
#                            install-time self-test raised "did not produce a
#                            usable BMI" with empty compiler output underneath.
#                            The criterion failed, not the thing measured, and
#                            the diagnostic accused the toolchain.
#   pkgs/g/gitcode-hosts.lua `stat -c "%a"` captured the hosts file's mode
#                            before opening it to 666 to write it, then restored
#                            it with the captured value -- so an empty capture
#                            made the restore `sudo chmod  /etc/hosts`, which
#                            fails, leaving the file WORLD-WRITABLE.
#
# Both were found on one afternoon, in unrelated packages, by the same flag. The
# denominator is what makes this a check rather than two fixes: every recipe
# that declares a `macosx` table is examined, so the next one is caught before a
# macOS runner has to find it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

strip_lua_comments() {
  awk '
    { line = $0 }
    inblock {
      i = index(line, "]]")
      if (i == 0) { print ""; next }
      line = substr(line, i + 2); inblock = 0
    }
    {
      b = index(line, "--[[")
      d = index(line, "--")
      if (b > 0 && (d == 0 || b <= d)) {
        pre = substr(line, 1, b - 1)
        rest = substr(line, b + 4)
        j = index(rest, "]]")
        if (j == 0) { inblock = 1; print pre; next }
        print pre substr(rest, j + 2); next
      }
      if (d > 0) { print substr(line, 1, d - 1); next }
      print line
    }
  ' "$1"
}

fail=0
examined=0
for file in pkgs/*/*.lua; do
  [ -f "$file" ] || continue
  code=$(strip_lua_comments "$file")
  # Only recipes that can run on macOS are in scope; a Linux-only package may
  # legitimately use the GNU spelling.
  grep -qE '^[[:space:]]*macosx[[:space:]]*=' <<<"$code" || continue
  examined=$((examined + 1))
  hits=$(grep -nE 'stat[[:space:]]+(-c|--format)' <<<"$code" || true)
  if [ -n "$hits" ]; then
    echo "ERROR: $file declares macosx and uses a GNU-only stat flag:"
    sed 's/^/    /' <<<"$hits"
    echo "    use a host branch (BSD: -f%z for size, -f%Lp for mode), or read"
    echo "    the value in-process -- io.open(p,\"rb\"):seek(\"end\") for a size."
    fail=1
  fi
done

# A check whose denominator can silently become zero is not a check.
if [ "$examined" -lt 5 ]; then
  echo "ERROR: only $examined macosx-declaring recipes examined; the"
  echo "       enumeration is too small to be evidence"
  exit 1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "OK: $examined macosx-declaring recipes use no GNU-only stat flag"
