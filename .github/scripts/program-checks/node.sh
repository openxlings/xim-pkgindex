#!/usr/bin/env bash
# Runs the installed node ($NODE) on the thing xlings#605 broke: a native
# module whose own dependencies node's loader has to find. Every criterion
# prints one READING line; the script exits non-zero on the first criterion
# that does not hold.
#
# 1. node runs.
# 2. Linux, on OUR loader: node NEEDs every glibc compat soname its libdir
#    ships, and a module carrying a DT_RUNPATH that NEEDs two of them loads --
#    while a copy of the same node without them fails on the same module with
#    ENOENT. The copy is what proves the probe reaches the defect at all: on
#    the host's loader ld.so.cache serves the soname and both would pass.
# 3. Everywhere: `sharp` -- the module #605 was reported against -- installs
#    through this node's npm and encodes a PNG.
set -uo pipefail
: "${NODE:?NODE must name the installed program}"

W="${RUNNER_TEMP:-$(mktemp -d)}/node-native"
rm -rf "$W"; mkdir -p "$W"

reading() { printf 'READING %s: %s\n' "$1" "$2"; }
fail() { echo "::error::$*"; exit 1; }
contains() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

bindir="$(dirname "$NODE")"
export PATH="$bindir:$PATH"

# 1.
out=$("$NODE" --version 2>&1); rc=$?
reading "node --version" "exit=$rc $out"
[ "$rc" -eq 0 ] || fail "node --version exited $rc: $out"

# 2.
if [ "$(uname -s)" = "Linux" ]; then
    command -v patchelf >/dev/null || fail "patchelf is needed to read and forge ELF headers"
    command -v cc >/dev/null || fail "a C compiler is needed to build the probe module"
    interp=$(patchelf --print-interpreter "$NODE"); libdir=${interp%/*}
    rpath=$(patchelf --print-rpath "$NODE")
    needed=$(patchelf --print-needed "$NODE" | tr '\n' ' ')
    reading "interpreter" "$interp"
    reading "NEEDED" "$needed"

    case ":$rpath:" in
    *":$libdir:"*)
        compat="libresolv.so.2 libutil.so.1 librt.so.1 libanl.so.1 libdl.so.2 libpthread.so.0"
        for so in $compat; do
            [ -e "$libdir/$so" ] || continue
            contains " $needed" " $so " || fail "node runs on $interp but does not NEED $so, which that libdir ships"
        done
        [ -e "$libdir/libresolv.so.2" ] || fail "$libdir ships no libresolv.so.2; the probe below would prove nothing"

        printf 'int xlings_probe;\n' > "$W/probe.c"
        cc -shared -fPIC "$W/probe.c" -o "$W/libprobe.so" || fail "could not build the probe"
        # patchelf's default tag is DT_RUNPATH, which is the point: an object
        # with one is searched only on it, never on node's RPATH.
        patchelf --add-needed libresolv.so.2 --add-needed libutil.so.1 \
                 --set-rpath '$ORIGIN' "$W/libprobe.so" || fail "could not stamp the probe"
        reading "probe" "$(patchelf --print-needed "$W/libprobe.so" | tr '\n' ' ')RUNPATH=$(patchelf --print-rpath "$W/libprobe.so")"

        dl='try { process.dlopen({ exports: {} }, process.argv[1]); console.log("loaded") } catch (e) { console.log(e.message) }'
        got=$("$NODE" -e "$dl" "$W/libprobe.so" 2>&1)
        reading "dlopen through node" "$got"
        contains "$got" "cannot open shared object file" && fail "node could not load a module that NEEDs libresolv.so.2: $got"

        cp "$NODE" "$W/node-control"
        remove=""
        for so in libresolv.so.2 libutil.so.1; do
            contains " $needed" " $so " && remove="$remove --remove-needed $so"
        done
        # shellcheck disable=SC2086
        patchelf $remove "$W/node-control" || fail "could not build the control"
        got=$("$W/node-control" -e "$dl" "$W/libprobe.so" 2>&1)
        reading "dlopen through the control (compat sonames removed)" "$got"
        contains "$got" "cannot open shared object file" \
            || fail "the control loaded the probe too, so the probe does not reach the #605 path: $got"
        ;;
    *)
        reading "loader" "host's ($interp is not on node's RPATH); ld.so.cache serves the compat sonames"
        ;;
    esac
fi

# 3.
cd "$W" || exit 1
printf '{"name":"xlings-node-native","private":true}\n' > package.json
npm install --no-audit --no-fund sharp > npm.log 2>&1; rc=$?
reading "npm install sharp" "exit=$rc $(tail -1 npm.log)"
[ "$rc" -eq 0 ] || { cat npm.log; fail "npm install sharp exited $rc"; }
out=$("$NODE" -e '
require("sharp")({ create: { width: 4, height: 4, channels: 3, background: "red" } })
  .png().toBuffer()
  .then(b => console.log("PNG " + b.length))
  .catch(e => { console.log(e.message); process.exit(1) })' 2>&1); rc=$?
reading "sharp encodes a PNG" "exit=$rc $out"
[ "$rc" -eq 0 ] && contains "$out" "PNG " || fail "sharp did not load or encode: $out"
