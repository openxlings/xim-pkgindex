#!/usr/bin/env bash
#
# build-llvm-subpkg.sh — carve an xlings-res LLVM sub-package (core | libcxx |
# tools) out of a full upstream LLVM distribution.
#
# This generalizes build-llvm-tools.sh: same carve + repack + sha256 flow, but
# manifest-driven so it can produce all three sub-packages defined by the
# llvm-subpackaging skill (.agents/skills/llvm-subpackaging):
#
#   llvm-core    compiler driver + lld + binutils-equivalents + compiler-rt
#                + clang builtin headers
#   llvm-libcxx  libc++ / libc++abi / libunwind (headers + libs)
#   llvm-tools   clang-format, clang-tidy, clangd + clang builtin headers
#
# Output layout (matches existing assets):
#   <pkg>-<ver>-<platform>-<arch>/{bin,lib,include}/...
# Asset naming: <pkg>-<ver>-<platform>-<arch>.<ext>
#   macosx -> tar.xz ; windows -> tar.xz + zip ; linux -> tar.gz + tar.xz
#
# macOS binaries are verified self-contained (system-only dylibs) via an
# embedded Mach-O LC_LOAD_DYLIB reader (no otool; runs on Linux). NO strip
# (LLVM release binaries carry no DWARF debug_info; see the skill).
#
# Usage:
#   build-llvm-subpkg.sh --in <full-llvm.tar.xz|dir> --pkg core|libcxx|tools \
#       --version 22.1.8 --platform macosx --arch arm64 \
#       [--out <dir>] [--formats "tar.xz zip"]
#
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
log() { echo ">> $*" >&2; }

IN="" PKG="" VERSION="" PLATFORM="" ARCH="" OUT="$PWD" FORMATS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --in)       IN="$2"; shift 2;;
        --pkg)      PKG="$2"; shift 2;;
        --version)  VERSION="$2"; shift 2;;
        --platform) PLATFORM="$2"; shift 2;;
        --arch)     ARCH="$2"; shift 2;;
        --out)      OUT="$2"; shift 2;;
        --formats)  FORMATS="$2"; shift 2;;
        -h|--help)  grep '^#' "$0" | sed 's/^# \?//'; exit 0;;
        *) die "unknown arg: $1";;
    esac
done

[ -n "$IN" ]       || die "--in is required (full LLVM tarball or extracted dir)"
[ -n "$PKG" ]      || die "--pkg is required (core|libcxx|tools)"
[ -n "$VERSION" ]  || die "--version is required (e.g. 22.1.8)"
[ -n "$PLATFORM" ] || die "--platform is required (linux|macosx|windows)"
[ -n "$ARCH" ]     || die "--arch is required (x86_64|arm64)"
[ -e "$IN" ]       || die "input not found: $IN"
case "$PKG" in llvm|core|libcxx|tools) ;; *) die "--pkg must be llvm|core|libcxx|tools";; esac

# default formats per platform (match existing released assets)
if [ -z "$FORMATS" ]; then
    case "$PLATFORM" in
        macosx)  FORMATS="tar.xz";;
        windows) FORMATS="tar.xz zip";;
        linux)   FORMATS="tar.gz tar.xz";;
    esac
fi

EXE=""
[ "$PLATFORM" = "windows" ] && EXE=".exe"
MAJOR="${VERSION%%.*}"
# merged toolchain ships as `llvm-<ver>-...`; component pkgs as `llvm-<pkg>-<ver>-...`
if [ "$PKG" = "llvm" ]; then
    BUNDLE="llvm-${VERSION}-${PLATFORM}-${ARCH}"
else
    BUNDLE="llvm-${PKG}-${VERSION}-${PLATFORM}-${ARCH}"
fi

# `llvm` core bin manifest — authoritative per-platform set, matching the
# existing xlings-res `llvm-<ver>-<platform>` assets so all platforms stay
# consistent. Unix (linux/mac) = the linux `llvm` set (34); windows = the
# existing windows `llvm` set (27 exes + 2 openmp DLLs).
if [ "$PLATFORM" = "windows" ]; then
    CORE_BINS=(
        clang clang++ clang-cl clang-scan-deps lld-link
        llvm-addr2line llvm-ar llvm-config llvm-cov llvm-cvtres llvm-cxxfilt
        llvm-dlltool llvm-lib llvm-mt llvm-nm llvm-objcopy llvm-objdump
        llvm-profdata llvm-ranlib llvm-rc llvm-readelf llvm-readobj llvm-size
        llvm-strings llvm-strip llvm-symbolizer llvm-windres
    )
    CORE_DLLS=(libiomp5md.dll libomp.dll)   # openmp runtime, bundled on windows
else
    CORE_BINS=(
        clang clang++ clang-${MAJOR} clang-cl clang-cpp clang-scan-deps
        ld64.lld ld.lld lld lld-link wasm-ld
        llvm-addr2line llvm-ar llvm-as llvm-bitcode-strip llvm-config llvm-cov
        llvm-dis llvm-dlltool llvm-lib llvm-link llvm-nm llvm-objcopy llvm-objdump
        llvm-otool llvm-profdata llvm-ranlib llvm-rc llvm-readelf llvm-readobj
        llvm-size llvm-strip llvm-symbolizer hwasan_symbolize
    )
    CORE_DLLS=()
fi
TOOLS_BINS=(clang-format clang-tidy clangd)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DEST="$WORK/$BUNDLE"
mkdir -p "$DEST"

# --- locate / extract source root -----------------------------------------
if [ -d "$IN" ]; then
    SRCROOT="$IN"
else
    log "extracting $IN (full decompress; reuse a dir input to avoid repeating) ..."
    mkdir -p "$WORK/src"
    case "$IN" in
        *.tar.xz) tar -xJf "$IN" -C "$WORK/src";;
        *.tar.gz|*.tgz) tar -xzf "$IN" -C "$WORK/src";;
        *.zip) ( cd "$WORK/src" && unzip -q "$IN" );;
        *) die "unsupported input archive: $IN";;
    esac
    SRCROOT="$WORK/src"
fi

# top dir inside the source (e.g. LLVM-22.1.8-macOS-ARM64 or clang+llvm-...)
TOP="$(find "$SRCROOT" -maxdepth 2 -type d -name 'bin' -print -quit 2>/dev/null | xargs -r dirname)"
[ -n "$TOP" ] && [ -d "$TOP" ] || die "could not locate <root>/bin under $SRCROOT"
log "source root: $TOP"

copy_bin() { # $1 = basename (no exe suffix)
    local name="$1$EXE" src="$TOP/bin/$1$EXE"
    if [ -e "$src" ] || [ -L "$src" ]; then
        cp -a "$src" "$DEST/bin/$name"
        return 0
    fi
    return 1
}

copy_builtin_headers() {
    local hs="$TOP/lib/clang/$MAJOR/include"
    [ -d "$hs" ] || die "missing builtin headers: lib/clang/$MAJOR/include"
    mkdir -p "$DEST/lib/clang/$MAJOR"
    cp -R "$hs" "$DEST/lib/clang/$MAJOR/include"
    [ -f "$DEST/lib/clang/$MAJOR/include/stddef.h" ] || die "builtin headers missing stddef.h"
    log "  + lib/clang/$MAJOR/include ($(du -sh "$DEST/lib/clang/$MAJOR/include" | cut -f1))"
}

do_tools() {
    mkdir -p "$DEST/bin"
    for t in "${TOOLS_BINS[@]}"; do copy_bin "$t" || die "missing $t$EXE"; log "  + bin/$t$EXE"; done
    copy_builtin_headers
}

do_core() {
    mkdir -p "$DEST/bin"
    local n=0 t
    for t in "${CORE_BINS[@]}"; do
        if copy_bin "$t"; then n=$((n+1)); else log "  - (absent on $PLATFORM) $t"; fi
    done
    [ "$n" -ge 5 ] || die "core: only $n binaries found, expected the clang/lld/llvm-* set"
    log "  + $n core binaries"
    # bundled runtime DLLs (windows openmp)
    for d in "${CORE_DLLS[@]:-}"; do
        [ -n "$d" ] || continue
        if [ -e "$TOP/bin/$d" ]; then cp -a "$TOP/bin/$d" "$DEST/bin/$d"; log "  + bin/$d"; fi
    done
    copy_builtin_headers
    # compiler-rt
    if [ -d "$TOP/lib/clang/$MAJOR/lib" ]; then
        cp -R "$TOP/lib/clang/$MAJOR/lib" "$DEST/lib/clang/$MAJOR/lib"
        log "  + lib/clang/$MAJOR/lib (compiler-rt, $(du -sh "$DEST/lib/clang/$MAJOR/lib" | cut -f1))"
    fi
}

do_libcxx() {
    # headers
    if [ -d "$TOP/include/c++" ]; then
        mkdir -p "$DEST/include"; cp -R "$TOP/include/c++" "$DEST/include/c++"
        log "  + include/c++ ($(du -sh "$DEST/include/c++" | cut -f1))"
    else die "libcxx: missing include/c++/v1"; fi
    # per-triple headers (e.g. include/<triple>/c++/v1)
    local d rel f found=0
    while IFS= read -r d; do
        rel="${d#$TOP/}"; mkdir -p "$DEST/$(dirname "$rel")"; cp -R "$d" "$DEST/$rel"
        log "  + $rel"
    done < <(find "$TOP/include" -mindepth 2 -maxdepth 2 -type d -name 'c++' 2>/dev/null)
    # libs: libc++ / libc++abi / libunwind (+ modules json), preserve path
    # under lib/.
    while IFS= read -r f; do
        rel="${f#$TOP/}"; mkdir -p "$DEST/$(dirname "$rel")"; cp -a "$f" "$DEST/$rel"; found=$((found+1))
    done < <(find "$TOP/lib" -maxdepth 2 \( \
        -name 'libc++*' -o -name 'libc++abi*' -o -name 'libunwind*' -o -name 'libc++.modules.json' \
        \) 2>/dev/null)
    log "  + $found libcxx lib artifacts"
    [ "$found" -ge 1 ] || die "libcxx: no libc++/libc++abi/libunwind libs found (not shipped on $PLATFORM?)"

    # libatomic — Linux self-containment. libatomic carries the out-of-line
    # __atomic_* libcalls that 16-byte/oversized std::atomic lower to; libc++
    # over-links it (a phantom NEEDED) so OMITTING it crashes EVERY binary at
    # load with `libatomic.so.1: cannot open`, and genuine atomic users can't
    # link. CRUCIALLY it is a GCC runtime lib — LLVM builds no libatomic
    # (clang/cmake/caches/Release.cmake DEFAULT_RUNTIMES has none), so the
    # upstream LLVM Linux release does NOT ship it (verified: 0 files in
    # LLVM-22.1.8-Linux-X64). The upstream tarball silently relies on the host
    # GCC's libatomic; for a self-contained package we must carry our own.
    # Source it from the build host's GCC and drop it beside libc++ in the
    # per-triple lib dir. (mcpp .agents/docs
    # 2026-06-26-llvm22-libatomic-self-containment-design.md.)
    if [ "$PLATFORM" = "linux" ]; then
        local cxxdir atomic_real base atomic_a
        cxxdir=$(dirname "$(find "$DEST/lib" -maxdepth 2 -name 'libc++.so.1' 2>/dev/null | head -1)")
        [ -n "$cxxdir" ] && [ -d "$cxxdir" ] \
            || die "libatomic: cannot locate libc++ triple lib dir under $DEST/lib"
        command -v gcc >/dev/null 2>&1 \
            || die "libatomic: gcc not on build host (needed to source libatomic for self-containment)"
        atomic_real=$(readlink -f "$(gcc -print-file-name=libatomic.so.1)" 2>/dev/null)
        [ -n "$atomic_real" ] && [ -e "$atomic_real" ] \
            || die "libatomic: 'gcc -print-file-name=libatomic.so.1' did not resolve to a real file"
        base=$(basename "$atomic_real")            # e.g. libatomic.so.1.2.0
        cp "$atomic_real" "$cxxdir/$base"
        ln -sf "$base" "$cxxdir/libatomic.so.1"
        ln -sf libatomic.so.1 "$cxxdir/libatomic.so"
        atomic_a=$(gcc -print-file-name=libatomic.a 2>/dev/null)
        [ -n "$atomic_a" ] && [ -e "$atomic_a" ] && cp "$atomic_a" "$cxxdir/libatomic.a"
        log "  + libatomic (host gcc: $base + .so/.so.1${atomic_a:+ + .a})"
    fi
    # libc++ std modules (share/libc++/v1/std.cppm) — needed by `import std;`
    if [ -d "$TOP/share/libc++" ]; then
        mkdir -p "$DEST/share"; cp -R "$TOP/share/libc++" "$DEST/share/libc++"
        log "  + share/libc++ ($(du -sh "$DEST/share/libc++" | cut -f1))"
    fi
}

case "$PKG" in
  tools)  do_tools;;
  core)   do_core;;
  libcxx) do_libcxx;;
  llvm)   do_core
          # libc++ only ships on linux/macOS; windows clang uses the MSVC STL
          if [ -d "$TOP/include/c++" ]; then do_libcxx; else log "  (no libc++ on $PLATFORM — MSVC STL)"; fi;;
esac

# --- macOS self-containment check (Mach-O LC_LOAD_DYLIB) -------------------
if [ "$PLATFORM" = "macosx" ] && [ -d "$DEST/bin" ]; then
    log "verifying macOS binaries are self-contained (system-only dylibs) ..."
    # only real Mach-O files (skip symlinks)
    mapfile -t MACHO < <(find "$DEST/bin" -type f)
    if [ "${#MACHO[@]}" -gt 0 ]; then
        python3 - "${MACHO[@]}" <<'PY' || die "self-containment check failed"
import struct, sys
MH=(0xFEEDFACE,0xFEEDFACF); LOAD={0x0C,0x80000018,0x8000001F}; RPATH=0x1C
def macho(data,off):
    le=struct.unpack_from("<I",data,off)[0]; be=struct.unpack_from(">I",data,off)[0]
    en="<" if le in MH else ">"; magic=le if le in MH else be
    is64=magic==0xFEEDFACF
    nc=struct.unpack_from(en+("IiiIIII" if not is64 else "IiiIIIII"),data,off)[4]
    o=off+(32 if is64 else 28); deps=[]
    for _ in range(nc):
        cmd,sz=struct.unpack_from(en+"II",data,o)
        if cmd in LOAD:
            no=struct.unpack_from(en+"I",data,o+8)[0]
            deps.append(data[o+no:o+sz].split(b"\0")[0].decode(errors="replace"))
        o+=sz
    return deps
bad=False
for path in sys.argv[1:]:
    data=open(path,"rb").read()
    if len(data)<4: continue
    be=struct.unpack_from(">I",data,0)[0]
    le=struct.unpack_from("<I",data,0)[0]
    offs=[]
    if be in (0xCAFEBABE,0xCAFEBABF):
        n=struct.unpack_from(">I",data,4)[0]; is64=be==0xCAFEBABF; a=8
        for _ in range(n):
            if is64: off=struct.unpack_from(">Q",data,a+8)[0]; a+=32
            else:    off=struct.unpack_from(">I",data,a+8)[0]; a+=20
            offs.append(off)
    elif le in MH or be in MH: offs=[0]
    else: continue  # not Mach-O (e.g. a script) — skip
    deps=set()
    for off in offs: deps|=set(macho(data,off))
    ext=[d for d in deps if not (d.startswith("/usr/lib/") or d.startswith("/System/"))]
    if ext:
        bad=True
        print(f"   !! {path.split('/')[-1]} non-system deps:", file=sys.stderr)
        for d in ext: print(f"        {d}", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
        log "  OK: all macOS binaries depend only on system libraries"
    fi
fi

# --- repack ----------------------------------------------------------------
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"   # absolutize: the zip step cd's into $WORK
echo
echo "=== $BUNDLE ==="
for FMT in $FORMATS; do
    OUTFILE="$OUT/${BUNDLE}.${FMT}"
    case "$FMT" in
        tar.xz) tar -C "$WORK" -cJf "$OUTFILE" "$BUNDLE";;
        tar.gz) tar -C "$WORK" -czf "$OUTFILE" "$BUNDLE";;
        zip)    ( cd "$WORK" && zip -q -r -X "$OUTFILE" "$BUNDLE" );;
        *) die "unknown format: $FMT";;
    esac
    SHA="$(sha256sum "$OUTFILE" | cut -d' ' -f1)"
    printf "  %-10s %8s  %s\n" "$FMT" "$(du -h "$OUTFILE" | cut -f1)" "$SHA"
    echo "$SHA  $(basename "$OUTFILE")" >> "$OUT/SHA256SUMS.txt"
done
