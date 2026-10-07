#!/usr/bin/env bash
# Build admission only: archives remain immutable; index activation additionally
# requires the installed-client and mcpp consumer gates.
set -euo pipefail
[[ $(uname -m) == aarch64 || $(uname -m) == arm64 ]] || { echo 'native aarch64 admission required' >&2; exit 1; }
OUT="${1:-/tmp/aarch64-assets}"
WORK="${AARCH64_ADMISSION_WORK:-/tmp/aarch64-admission}"
rm -rf "$WORK"; mkdir -p "$WORK"
(cd "$OUT" && sha256sum -c SHA256SUMS)
for stem in llvm-23.1.3 llvm-tools-23.1.3 glibc-2.44.3-r1 gcc-runtime-15.1.0 linux-headers-5.11.1 zlib-1.3.1 libxml2-2.13.5; do
    archive="$OUT/$stem-linux-aarch64.tar.gz"
    [[ -f "$archive" ]] || { echo "missing closure archive: $archive" >&2; exit 1; }
    tar -xf "$archive" -C "$WORK"
done
GLIBC="$WORK/glibc-2.44.3-r1-linux-aarch64"
LOADER="$GLIBC/lib/ld-linux-aarch64.so.1"
# Relocate only this private admission copy, preserving reserved string sizes.
python3 - "$GLIBC" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
reserved = b'/nonexistent/xlings-use-rpath-not-default-search'
placeholder = reserved + b'/' * (255 - len(reserved))
replacement = str(root).encode()
assert len(replacement) <= len(placeholder)
replacement += b'/' * (len(placeholder) - len(replacement))
for file in root.rglob('*'):
    if file.is_symlink() or not file.is_file():
        continue
    before = file.read_bytes()
    if placeholder in before:
        after = before.replace(placeholder, replacement)
        assert len(after) == len(before)
        file.write_bytes(after)
PY
LLVM="$WORK/llvm-23.1.3-linux-aarch64"
TOOLS="$WORK/llvm-tools-23.1.3-linux-aarch64"
LIBS="$GLIBC/lib:$LLVM/lib:$LLVM/lib/aarch64-unknown-linux-gnu:$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64:$WORK/zlib-1.3.1-linux-aarch64/lib:$WORK/libxml2-2.13.5-linux-aarch64/lib"
unset LD_LIBRARY_PATH LD_PRELOAD CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LOCPATH GCONV_PATH TZDIR
: > "$OUT/managed-process-admission.log"
for tool in clang clangd clang-tidy clang-format ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-readobj llvm-size llvm-strings llvm-strip; do
    binary="$LLVM/bin/$tool"
    [[ -e "$binary" ]] || binary="$TOOLS/bin/$tool"
    [[ -e "$binary" ]] || { echo "missing admitted tool: $tool" >&2; exit 1; }
    listed="$("$LOADER" --library-path "$LIBS" --list "$binary")"
    printf '%s\n%s\n' "$tool" "$listed" >> "$OUT/managed-process-admission.log"
    # Every resolved library path must originate in the private closure.
    awk -v root="$WORK/" '/=>/ { if ($3 !~ /^\// || index($3,root) != 1) bad=1 } END {exit bad}' <<< "$listed"
    "$LOADER" --library-path "$LIBS" "$binary" --version >> "$OUT/managed-process-admission.log" 2>&1
done
# A real header placed on the runner's default host search path must remain
# inaccessible under the managed policy. The control proves the fixture is
# actually reachable when that policy is absent.
HOST_SENTINEL="/usr/local/include/llvm2313-admission-${GITHUB_RUN_ID:-local}.h"
sudo mkdir -p /usr/local/include
printf '#define LLVM2313_HOST_SHADOW 1\n' | sudo tee "$HOST_SENTINEL" >/dev/null
trap 'sudo rm -f "$HOST_SENTINEL"' EXIT
printf '#include <%s>\nint value = LLVM2313_HOST_SHADOW;\n' "$(basename "$HOST_SENTINEL")" > "$WORK/header-shadow.c"
RESOURCE="$LLVM/lib/clang/23"
"$LOADER" --library-path "$LIBS" "$LLVM/bin/clang" --no-default-config \
    -resource-dir "$RESOURCE" -E "$WORK/header-shadow.c" -o /dev/null
if "$LOADER" --library-path "$LIBS" "$LLVM/bin/clang" --no-default-config \
    -resource-dir "$RESOURCE" -nostdlibinc -nostdinc++ \
    -isystem "$GLIBC/include" -isystem "$WORK/linux-headers-5.11.1-linux-aarch64/include" \
    -E "$WORK/header-shadow.c" -o /dev/null 2> "$WORK/header-shadow.err"; then
    echo 'FAIL: host-only header accessible through managed policy' >&2; exit 1
fi
grep -F "$(basename "$HOST_SENTINEL")" "$WORK/header-shadow.err" | grep -q 'file not found'
sudo rm -f "$HOST_SENTINEL"
trap - EXIT
printf 'Host header shadow: control reachable, managed search rejects it.\n' > "$OUT/managed-header-negative-admission.log"
# Re-run the default-data probe against the relocated final archive content.
python3 - .agents/tools/graphics/build-glibc.sh "$WORK/data.c" <<'PY'
import pathlib, sys
script = pathlib.Path(sys.argv[1]).read_text()
source = script.split('cat > "$TPROBE/main.c" <<\'C\'\n', 1)[1].split('\nC\n', 1)[0]
pathlib.Path(sys.argv[2]).write_text(source)
PY
gcc "$WORK/data.c" -o "$WORK/data"
patchelf --remove-rpath "$WORK/data"
patchelf --set-interpreter "$LOADER" "$WORK/data"
"$WORK/data" | tee "$OUT/managed-data-admission.log"
bash .agents/tools/verify-toolchain.sh "$OUT/llvm-23.1.3-linux-aarch64.tar.gz" \
    --loader "$LOADER" --runtime-library-path "$LIBS" \
    --linux-headers "$WORK/linux-headers-5.11.1-linux-aarch64/include" \
    | tee "$OUT/managed-toolchain-admission.log"
python3 - "$OUT" <<'PY'
import json, os, pathlib, sys
out = pathlib.Path(sys.argv[1])
digests = {line.split()[1]: line.split()[0] for line in (out/'SHA256SUMS').read_text().splitlines()}
(out/'BUILD-ADMISSION.json').write_text(json.dumps({
    'schema': 1, 'status': 'passed', 'architecture': 'aarch64',
    'commit': os.environ.get('GITHUB_SHA', ''), 'run_id': os.environ.get('GITHUB_RUN_ID', ''),
    'source_commit': os.environ.get('ADMISSION_SOURCE_COMMIT', os.environ.get('GITHUB_SHA', '')),
    'source_run_id': os.environ.get('ADMISSION_SOURCE_RUN_ID', os.environ.get('GITHUB_RUN_ID', '')),
    'archives': digests,
    'gates': ['managed-process-libraries', 'default-timezone-locale-gconv-host-nss-policy',
              'managed-uapi-crt', 'host-header-negative', 'std-and-std.compat', 'cxx-compile-link-run'],
    'index_activation': 'requires installed-client and mcpp consumer acceptance',
}, indent=2) + '\n')
PY

cat "$OUT/BUILD-ADMISSION.json"
