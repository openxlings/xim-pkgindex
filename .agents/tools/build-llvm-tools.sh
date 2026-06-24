#!/usr/bin/env bash
#
# build-llvm-tools.sh — carve the slim `llvm-tools` bundle out of a full LLVM
# distribution.
#
# `llvm-tools` (pkgs/l/llvm-tools.lua) ships ONLY three editor tools —
# clang-format, clang-tidy, clangd — laid out as:
#
#     llvm-tools-<ver>-<platform>-<arch>/bin/<tool>[.exe]
#
# The linux/windows artifacts on the xlings-res/llvm release already follow
# this layout. This script reproduces it for any platform (notably macOS,
# which had no slim bundle) by extracting just those three binaries from an
# upstream full-LLVM tarball / directory and repacking them.
#
# On macOS the script verifies — via an embedded Mach-O LC_LOAD_DYLIB reader
# (no `otool` needed, runs on Linux) — that every extracted binary depends
# ONLY on system libraries (/usr/lib, /System). If a tool needs a bundled
# dylib (e.g. libclang-cpp.dylib) the bundle would be incomplete, so the
# script aborts loudly instead of shipping something that won't run.
#
# Usage:
#   build-llvm-tools.sh --in <full-llvm.tar.xz|dir> \
#       --version 20.1.7 --platform macosx --arch arm64 \
#       [--out <dir>] [--format tar.xz|tar.gz]
#
# Output: <out>/llvm-tools-<ver>-<platform>-<arch>.<format> + sha256 + report.
#
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
log() { echo ">> $*" >&2; }

IN="" VERSION="" PLATFORM="" ARCH="" OUT="$PWD" FMT="tar.xz"
while [ $# -gt 0 ]; do
    case "$1" in
        --in)       IN="$2"; shift 2;;
        --version)  VERSION="$2"; shift 2;;
        --platform) PLATFORM="$2"; shift 2;;
        --arch)     ARCH="$2"; shift 2;;
        --out)      OUT="$2"; shift 2;;
        --format)   FMT="$2"; shift 2;;
        -h|--help)  grep '^#' "$0" | sed 's/^# \?//'; exit 0;;
        *) die "unknown arg: $1";;
    esac
done

[ -n "$IN" ]       || die "--in is required (full LLVM tarball or extracted dir)"
[ -n "$VERSION" ]  || die "--version is required (e.g. 20.1.7)"
[ -n "$PLATFORM" ] || die "--platform is required (linux|macosx|windows)"
[ -n "$ARCH" ]     || die "--arch is required (x86_64|arm64)"
[ -e "$IN" ]       || die "input not found: $IN"
case "$FMT" in tar.xz|tar.gz) ;; *) die "--format must be tar.xz or tar.gz";; esac

SUFFIX=""
[ "$PLATFORM" = "windows" ] && SUFFIX=".exe"
TOOLS=(clang-format clang-tidy clangd)
BUNDLE="llvm-tools-${VERSION}-${PLATFORM}-${ARCH}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/$BUNDLE/bin"

# --- locate the three binaries inside the input ----------------------------
if [ -d "$IN" ]; then
    SRCROOT="$IN"
else
    log "extracting bin/ tools from $IN ..."
    # Extract only the three tools regardless of the archive's top dir name.
    case "$IN" in
        *.tar.xz) tar -xJf "$IN" -C "$WORK/src" --strip-components=0 2>/dev/null \
                    || { mkdir -p "$WORK/src"; tar -xJf "$IN" -C "$WORK/src"; };;
        *.tar.gz|*.tgz) mkdir -p "$WORK/src"; tar -xzf "$IN" -C "$WORK/src";;
        *.zip) mkdir -p "$WORK/src"; ( cd "$WORK/src" && unzip -q "$IN" );;
        *) die "unsupported input archive: $IN";;
    esac
    SRCROOT="$WORK/src"
fi

found=0
for t in "${TOOLS[@]}"; do
    # find first match for bin/<tool> anywhere under the source root
    p="$(find "$SRCROOT" -type f -path "*/bin/${t}${SUFFIX}" -print -quit 2>/dev/null || true)"
    [ -z "$p" ] && p="$(find "$SRCROOT" -type f -name "${t}${SUFFIX}" -print -quit 2>/dev/null || true)"
    [ -n "$p" ] || die "could not find ${t}${SUFFIX} under $SRCROOT"
    cp "$p" "$WORK/$BUNDLE/bin/${t}${SUFFIX}"
    chmod +x "$WORK/$BUNDLE/bin/${t}${SUFFIX}"
    log "  + ${t}${SUFFIX}  ($(du -h "$WORK/$BUNDLE/bin/${t}${SUFFIX}" | cut -f1))"
    found=$((found+1))
done
[ "$found" -eq 3 ] || die "expected 3 tools, got $found"

# --- clang builtin headers (resource-dir) ----------------------------------
# clangd derives its resource-dir from its OWN location (<bin>/../lib/clang/<major>)
# and auto-adds <resource-dir>/include to the search path. Without the builtin
# headers there (stddef.h, stdint.h, the intrinsic headers, ...), any TU that
# pulls in libc++ <cstddef> — e.g. via `#include <gtest/gtest.h>` — fails with
# "'stddef.h' file not found", because libc++'s <stddef.h> does
# `#include_next <stddef.h>` expecting the compiler builtin header. These are
# host-independent text headers, so they ship in every platform's bundle.
RESVER="${VERSION%%.*}"
HDRSRC="$(find "$SRCROOT" -type d -path "*/lib/clang/${RESVER}/include" -print -quit 2>/dev/null || true)"
[ -n "$HDRSRC" ] || die "could not find lib/clang/${RESVER}/include under $SRCROOT"
mkdir -p "$WORK/$BUNDLE/lib/clang/${RESVER}"
cp -R "$HDRSRC" "$WORK/$BUNDLE/lib/clang/${RESVER}/include"
[ -f "$WORK/$BUNDLE/lib/clang/${RESVER}/include/stddef.h" ] || die "builtin headers copy missing stddef.h"
log "  + lib/clang/${RESVER}/include  ($(du -sh "$WORK/$BUNDLE/lib/clang/${RESVER}/include" | cut -f1) builtin headers)"

# --- macOS self-containment check (Mach-O LC_LOAD_DYLIB) -------------------
if [ "$PLATFORM" = "macosx" ]; then
    log "verifying macOS binaries are self-contained (system-only dylibs) ..."
    python3 - "$WORK/$BUNDLE/bin"/* <<'PY' || die "self-containment check failed"
import struct, sys
MH=(0xFEEDFACE,0xFEEDFACF); LOAD={0x0C,0x80000018,0x8000001F}; RPATH=0x1C
def macho(data,off):
    le=struct.unpack_from("<I",data,off)[0]; be=struct.unpack_from(">I",data,off)[0]
    en="<" if le in MH else ">"; magic=le if le in MH else be
    is64=magic==0xFEEDFACF
    nc=struct.unpack_from(en+("IiiIIII" if not is64 else "IiiIIIII"),data,off)[4]
    o=off+(32 if is64 else 28); deps=[]; rp=[]
    for _ in range(nc):
        cmd,sz=struct.unpack_from(en+"II",data,o)
        if cmd in LOAD:
            no=struct.unpack_from(en+"I",data,o+8)[0]
            deps.append(data[o+no:o+sz].split(b"\0")[0].decode())
        elif cmd==RPATH:
            no=struct.unpack_from(en+"I",data,o+8)[0]
            rp.append(data[o+no:o+sz].split(b"\0")[0].decode())
        o+=sz
    return deps,rp
bad=False
for path in sys.argv[1:]:
    data=open(path,"rb").read()
    be=struct.unpack_from(">I",data,0)[0]
    offs=[]
    if be in (0xCAFEBABE,0xCAFEBABF):
        n=struct.unpack_from(">I",data,4)[0]; is64=be==0xCAFEBABF; a=8
        for _ in range(n):
            if is64: off=struct.unpack_from(">Q",data,a+8)[0]; a+=32
            else:    off=struct.unpack_from(">I",data,a+8)[0]; a+=20
            offs.append(off)
    else: offs=[0]
    deps=set(); rps=set()
    for off in offs:
        d,r=macho(data,off); deps|=set(d); rps|=set(r)
    ext=[d for d in deps if not (d.startswith("/usr/lib/") or d.startswith("/System/"))]
    print(f"   {path.split('/')[-1]}: {len(deps)} deps, {len(rps)} rpath", file=sys.stderr)
    for d in sorted(deps): print(f"      {d}", file=sys.stderr)
    if ext:
        bad=True
        for d in ext: print(f"      !! NON-SYSTEM (would need bundling): {d}", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
    log "  OK: all macOS tools depend only on system libraries"
fi

# --- repack ----------------------------------------------------------------
mkdir -p "$OUT"
OUTFILE="$OUT/${BUNDLE}.${FMT}"
log "packing $OUTFILE ..."
case "$FMT" in
    tar.xz) tar -C "$WORK" -cJf "$OUTFILE" "$BUNDLE";;
    tar.gz) tar -C "$WORK" -czf "$OUTFILE" "$BUNDLE";;
esac

SIZE="$(du -h "$OUTFILE" | cut -f1)"
SHA="$(sha256sum "$OUTFILE" | cut -d' ' -f1)"
echo
echo "=== llvm-tools bundle built ==="
echo "  bundle : $BUNDLE"
echo "  file   : $OUTFILE"
echo "  size   : $SIZE"
echo "  sha256 : $SHA"
echo "  layout :"
tar -tf "$OUTFILE" | sed 's/^/    /'
