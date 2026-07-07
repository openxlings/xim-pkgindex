#!/usr/bin/env bash
# verify-toolchain.sh — INTERP-independent functional check of a (stripped)
# toolchain tarball. Extracts to a throwaway dir (never touches the shipped
# artifact), patchelf's the driver+backend binaries to a working loader on THIS
# machine, then runs a real end-to-end compile through the stripped cc1plus /
# collect2 / ld and executes the result.
#
# Works regardless of the build-temp INTERP baked into the tarball (that path
# usually does not exist on any other machine — xlings patches it at install
# time; see T-f). Proves strip did not corrupt the compiler.
#
# Usage:  verify-toolchain.sh TARBALL [--loader LD]
# Default loader: the xim glibc loader on this machine.
set -uo pipefail

TARBALL="${1:-}"; shift || true
LOADER="$HOME/.xlings/data/xpkgs/xim-x-glibc/2.39/lib64/ld-linux-x86-64.so.2"
while [ $# -gt 0 ]; do case "$1" in --loader) LOADER="$2"; shift 2;; *) shift;; esac; done
[ -f "$TARBALL" ] || { echo "error: tarball not found: $TARBALL" >&2; exit 2; }
command -v patchelf >/dev/null || { echo "error: patchelf required" >&2; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
tar -xzf "$TARBALL" -C "$T" || { echo "FAIL: tarball does not extract" >&2; exit 1; }
ROOT="$T/$(ls "$T")"
GLIBC_LIB="$(dirname "$LOADER")"

# detect compiler driver + libc flavor
CXX="$(find "$ROOT" -maxdepth 2 -path '*/bin/g++' | head -1)"
[ -n "$CXX" ] || CXX="$(find "$ROOT" -maxdepth 2 -path '*/bin/*-musl-g++' | head -1)"
[ -n "$CXX" ] || CXX="$(find "$ROOT" -maxdepth 2 -path '*/bin/clang++' | head -1)"
[ -n "$CXX" ] || { echo "SKIP: no g++/clang++ in $TARBALL"; exit 0; }

is_musl=0
case "$CXX" in *musl*) is_musl=1;; esac
# glibc headers live next to the loader: <glibc>/lib64/ld... -> <glibc>/include
GINC="${LOADER%/lib64/*}/include"
# for musl, prefer the toolchain's own musl libc as loader (musl libc.so == loader)
if [ "$is_musl" = 1 ]; then
  ML="$(find "$ROOT" -path '*-linux-musl/lib/libc.so' -o -name 'ld-musl-x86_64.so.1' 2>/dev/null | head -1)"
  [ -n "$ML" ] && LOADER="$ML" && GLIBC_LIB="$(dirname "$ML")"
fi
[ -e "$LOADER" ] || { echo "SKIP: loader not available: $LOADER (cannot run on this machine)"; exit 0; }
echo "verify: $(basename "$TARBALL")  flavor=$([ $is_musl = 1 ] && echo musl || echo glibc)  loader=$LOADER"

# patch interp + rpath on driver and backend executables (throwaway copy only).
# Skip binaries whose baked interp already resolves on THIS machine (upstream
# LLVM ships the standard /lib64 loader): they are runnable as-is, and
# patchelf on the huge statically-linked clang driver corrupts it (observed:
# clang --version goes silent after --set-interpreter/--set-rpath).
while IFS= read -r -d '' f; do
  case "$f" in *.a|*.o|*.so|*.so.*) continue;; esac
  file -b "$f" 2>/dev/null | grep -q 'ELF.*executable' || continue
  interp="$(patchelf --print-interpreter "$f" 2>/dev/null || true)"
  [ -n "$interp" ] && [ -e "$interp" ] && continue
  patchelf --set-interpreter "$LOADER" --set-rpath "$ROOT/lib64:$ROOT/lib:$GLIBC_LIB" "$f" 2>/dev/null || true
done < <(find "$ROOT" \( -path '*/bin/*' -o -path '*/libexec/*' \) -type f -print0)

printf '#include <cstdio>\n#include <vector>\n#include <string>\nint main(){std::vector<int>v{2,3,4};int s=0;for(int x:v)s+=x;std::string m="ok";std::printf("%%s sum=%%d\\n",m.c_str(),s);return s==9?0:1;}\n' > "$T/t.cpp"

# ── LLVM slim-package admission gate ────────────────────────────────────
# Catches the two release-blocking regression classes at the packaging
# source instead of at users:
#   1. missing payload files (a slim carve once shipped without
#      libatomic.so.1 → every produced binary died at load time);
#   2. non-hermetic CRT resolution (mcpp issue #195: the driver must find
#      Scrt1.o/crti.o/crtn.o in the sandbox glibc via -B, never fall back
#      to the host's /lib or pass bare names to lld).
case "$CXX" in *clang++*)
  echo "llvm gate: asset completeness"
  [ -f "$ROOT/share/libc++/v1/std.cppm" ] \
      || { echo "FAIL: slim package missing share/libc++/v1/std.cppm (import std unusable)"; exit 1; }
  find "$ROOT/lib" -name 'libc++.so*'      | grep -q . \
      || { echo "FAIL: slim package missing libc++.so"; exit 1; }
  find "$ROOT/lib" -name 'libatomic.so.1'  | grep -q . \
      || { echo "FAIL: slim package missing libatomic.so.1 (libc++ NEEDs it; every binary would die at load)"; exit 1; }

  TRIPLE="$(ls "$ROOT/lib" | grep -- '-linux-' | head -1)"
  CLANG_FLAGS="--no-default-config -nostdinc++ -stdlib=libc++ \
    -isystem $ROOT/include/c++/v1 \
    -fuse-ld=lld --rtlib=compiler-rt --unwindlib=libunwind \
    -B$GLIBC_LIB -L$GLIBC_LIB -Wl,--dynamic-linker=$LOADER -Wl,-rpath,$GLIBC_LIB"
  [ -d "$ROOT/include/$TRIPLE/c++/v1" ] && CLANG_FLAGS="$CLANG_FLAGS -isystem $ROOT/include/$TRIPLE/c++/v1"
  [ -d "$GINC" ] && CLANG_FLAGS="$CLANG_FLAGS -isystem $GINC"
  [ -d "$ROOT/lib/$TRIPLE" ] && CLANG_FLAGS="$CLANG_FLAGS -L$ROOT/lib/$TRIPLE -Wl,-rpath,$ROOT/lib/$TRIPLE"

  echo "llvm gate: hermetic CRT resolution (-###)"
  dry="$("$CXX" $CLANG_FLAGS -### -x c++ /dev/null -o /dev/null 2>&1)"
  bad="$(echo "$dry" | tr ' ' '\n' | tr -d '"' \
         | grep -E '(^|/)(S|g|r|M)?crt[1in]\.o$' | grep -v clang_rt \
         | grep -v "^$GLIBC_LIB/" || true)"
  [ -z "$bad" ] || { echo "FAIL: CRT resolves outside the glibc payload:"; echo "$bad" | sed 's/^/  /'; exit 1; }

  echo "llvm gate: import std end-to-end"
  printf 'import std;\nint main(){ std::println("ok import {}", 42); return 0; }\n' > "$T/m.cpp"
  "$CXX" $CLANG_FLAGS -std=c++23 --precompile -x c++-module \
      "$ROOT/share/libc++/v1/std.cppm" -o "$T/std.pcm" 2>"$T/err" \
      || { echo "FAIL: std module precompile"; sed 's/^/  /' "$T/err"; exit 1; }
  "$CXX" $CLANG_FLAGS -std=c++23 -fmodule-file=std="$T/std.pcm" \
      "$T/m.cpp" "$T/std.pcm" -o "$T/m" 2>"$T/err" \
      || { echo "FAIL: import std compile/link"; sed 's/^/  /' "$T/err"; exit 1; }
  mout="$("$T/m" 2>&1)" || { echo "FAIL: import std binary run error: $mout"; exit 1; }
  [ "$mout" = "ok import 42" ] || { echo "FAIL: import std wrong output: $mout"; exit 1; }
  echo "llvm gate: PASS"
  ;;
esac

if [ "$is_musl" = 1 ]; then
  # static output: self-contained, exercises stripped backend + static libs
  "$CXX" -O2 -std=c++17 -static "$T/t.cpp" -o "$T/t" 2>"$T/err" || { echo "FAIL: compile error"; sed 's/^/  /' "$T/err"; exit 1; }
  out="$("$T/t" 2>&1)" || { echo "FAIL: run error: $out"; exit 1; }
else
  # Prefer a real subos sysroot (how gcc actually runs); fall back to -isystem.
  SYSROOT="${VERIFY_SYSROOT:-$HOME/.xlings/subos/current}"
  if [ -f "$SYSROOT/usr/include/stdlib.h" ]; then sr="--sysroot=$SYSROOT"
  elif [ -d "$GINC" ]; then sr="-isystem $GINC"
  else sr=""; fi
  "$CXX" -O2 -std=c++17 $sr "$T/t.cpp" -o "$T/t" \
      -Wl,--dynamic-linker="$LOADER" -Wl,-rpath,"$GLIBC_LIB" 2>"$T/err" \
      || { echo "FAIL: compile error"; sed 's/^/  /' "$T/err"; exit 1; }
  out="$(LD_LIBRARY_PATH="$ROOT/lib64:$GLIBC_LIB" "$T/t" 2>&1)" || { echo "FAIL: run error: $out"; exit 1; }
fi

[ "$out" = "ok sum=9" ] && { echo "PASS: compiled & ran ($out)"; exit 0; } \
                        || { echo "FAIL: wrong output: $out"; exit 1; }
