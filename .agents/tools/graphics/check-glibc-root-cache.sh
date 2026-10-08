#!/usr/bin/env bash
set -euo pipefail

PAYLOAD="$(realpath "${1:?usage: check-glibc-root-cache.sh <payload>}")"
PROBE="$(mktemp -d "${TMPDIR:-/tmp}/xlings-glibc-cache.XXXXXXXX")"
trap 'rm -rf "$PROBE"' EXIT
CC="${XLINGS_GFX_CC:-gcc}"
LOADER="$(find "$PAYLOAD/lib" -maxdepth 1 -name 'ld-linux-*.so.*' -type f | head -1)"
[[ -n "$LOADER" ]] || { echo "no payload loader" >&2; exit 1; }
ROOT="$PROBE/root"
mkdir -p "$ROOT/usr/lib64" "$ROOT/etc" "$ROOT/opt/vendor"
ln -s usr/lib64 "$ROOT/lib64"
cp "$LOADER" "$ROOT/usr/lib64/"
cp "$PAYLOAD/lib/libc.so.6" "$ROOT/usr/lib64/"
cat > "$PROBE/library.c" <<'EOF'
int cache_probe(void) { return 42; }
EOF
cat > "$PROBE/preload.c" <<'EOF'
int cache_probe(void) { return 73; }
EOF
cat > "$PROBE/main.c" <<'EOF'
extern int cache_probe(void);
int main(int argc, char **argv) { return cache_probe() == (argc == 1 ? 42 : 73) ? 0 : 1; }
EOF
"$CC" -shared -fPIC "$PROBE/library.c" -Wl,-soname,libxlings_cache_probe.so.1 \
    -o "$ROOT/opt/vendor/libxlings_cache_probe.so.1"
"$CC" -shared -fPIC "$PROBE/preload.c" -o "$ROOT/opt/vendor/preload.so"
"$CC" "$PROBE/main.c" "$ROOT/opt/vendor/libxlings_cache_probe.so.1" -o "$PROBE/main"
patchelf --remove-rpath --set-interpreter "$ROOT/lib64/$(basename "$LOADER")" "$PROBE/main"

# The configuration is empty and the cache output belongs to this probe.
# Entries name the test files by their actual absolute host path because
# this probe exercises loader path selection without requiring a mount namespace.
"$PAYLOAD/sbin/ldconfig" -f /dev/null -C "$ROOT/etc/ld.so.cache" \
    "$ROOT/usr/lib64" "$ROOT/opt/vendor"
"$PROBE/main"
printf '%s\n' "$ROOT/opt/vendor/preload.so" > "$ROOT/etc/ld.so.preload"
"$PROBE/main" preload

# The same binary under the managed payload loader must not use this root's
# cache or preload, even though both are present.
patchelf --set-interpreter "$LOADER" "$PROBE/main"
if "$PROBE/main" 2> "$PROBE/managed.log"; then
    echo "managed loader unexpectedly used the foreign root cache" >&2
    exit 1
fi
rg -q 'libxlings_cache_probe.so.1' "$PROBE/managed.log"
echo "root cache/preload follow the logical interpreter; managed loader stays isolated"
