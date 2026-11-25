#!/usr/bin/env bash
# Build the `slint` payload — Slint's C++ SDK (libslint_cpp, its headers and
# slint-compiler) from the release tag, with a stated cargo feature set — and
# check what it needs at run time before it may ship.
#
# Plan: mcpp-index/.agents/docs/2026-11-20-add-slint-mwrap-plan.md §4.
#
# WHY A BUILD AND NOT UPSTREAM'S BINARY. Upstream's SDK is one feature set:
# the CMake defaults plus Skia, live preview and the LinuxKMS backend, whose
# libslint_cpp.so NEEDs libinput, libudev, libgbm (here: all of xim:mesa),
# libxkbcommon, fontconfig and freetype. The CMake DEFAULT set
# (api/cpp/cmake/SlintFeatures.cmake) is what a CMake user gets from
# FetchContent without options, and built from the same tag it NEEDs
# libfontconfig.so.1 and the C runtime only: X11, Wayland and GL are
# dlopen()ed. That is the `default` profile.
#
# WHAT IS BUILT, EXACTLY AS api/cpp/CMakeLists.txt DOES IT:
#   * `slint-cpp` (the cdylib) with --no-default-features --features <set>,
#     cbindgen's headers written to SLINT_GENERATED_INCLUDE_DIR;
#   * on macOS, `-install_name @rpath/libslint_cpp.dylib` on that crate alone
#     (CMakeLists.txt's corrosion_add_target_local_rustflags);
#   * `slint-compiler`, with its default features;
#   * the notices by upstream's own scripts/prepare_binary_package.sh, given
#     the same feature flags, so THIRDPARTY.md lists the crates linked.
#
# LAYOUT (the layout of upstream's SDK, so a CMake user's find_package works
# from it too):
#   bin/slint-compiler[.exe]
#   lib/libslint_cpp.so | lib/libslint_cpp.dylib | bin/slint_cpp.dll + lib/slint_cpp.lib
#   include/slint/{slint.h, …, private/*.h}
#   licenses/{LICENSE.md, THIRDPARTY.md (the library), THIRDPARTY-slint-compiler.md}
#   BUILD-INFO.txt
#
# Usage:  build-slint.sh <version> <profile> <outdir>
#   profile: default
# Env:    SLINT_SRC   an extracted source tree (else the tag archive is fetched)
#         CARGO_JOBS  cargo -j
#
# Exit codes (.agents/tools/README.md): 0 proven, 1 broken, 3 could-not-run.
set -euo pipefail

version=${1:?version}; profile=${2:?profile}; outdir=${3:?outdir}

case "$profile" in
  default)
    # SlintFeatures.cmake, desktop defaults (renderer-skia is ON only for
    # Android/iOS; backend-linuxkms is OFF). `compiler` is the separate crate.
    features="std,interpreter,backend-winit,renderer-femtovg,renderer-software,accessibility,system-tray,testing" ;;
  *) echo "unknown profile '$profile'" >&2; exit 3 ;;
esac

case "$(uname -s)" in
  Linux)  os=linux ;;
  Darwin) os=macosx ;;
  MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) echo "unsupported host $(uname -s)" >&2; exit 3 ;;
esac
case "$(uname -m)" in
  x86_64|AMD64) arch=x86_64 ;;
  aarch64|arm64) arch=$([ "$os" = macosx ] && echo arm64 || echo aarch64) ;;
  *) echo "unsupported arch $(uname -m)" >&2; exit 3 ;;
esac
command -v cargo >/dev/null || { echo "cargo not found" >&2; exit 3; }

name="slint-${version}-${profile}-${os}-${arch}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$outdir"

# ── the source ──────────────────────────────────────────────────────────────
if [ -z "${SLINT_SRC:-}" ]; then
  archive="$work/slint-${version}.tar.gz"
  curl -fsSL -o "$archive" "https://github.com/slint-ui/slint/archive/refs/tags/v${version}.tar.gz"
  pin=$(grep -E "^${version} " "$(dirname "$0")/sources.sha256" | cut -d' ' -f2 || true)
  [ -n "$pin" ] || { echo "no sha256 pinned for ${version} in sources.sha256" >&2; exit 1; }
  got=$( (sha256sum "$archive" 2>/dev/null || shasum -a 256 "$archive") | cut -d' ' -f1)
  [ "$got" = "$pin" ] || { echo "source sha256 $got != pinned $pin" >&2; exit 1; }
  if [ "$os" = windows ]; then
    # The tag archive holds 159 symlinks (license texts, assets) that tar under
    # git-bash cannot create; each becomes a copy of its target instead.
    py=$(command -v python3 || command -v python)
    "$py" - "$archive" "$work" <<'PY'
import os, shutil, sys, tarfile
archive, dest = sys.argv[1], sys.argv[2]
with tarfile.open(archive) as tar:
    members = tar.getmembers()
    tar.extractall(dest, members=[m for m in members if not (m.issym() or m.islnk())], filter="data")
    links = [m for m in members if m.issym() or m.islnk()]
for _ in range(len(links) + 1):           # a link may name another link
    pending = []
    for m in links:
        path = os.path.join(dest, m.name)
        target = os.path.normpath(os.path.join(os.path.dirname(path), m.linkname)) if m.issym() \
            else os.path.join(dest, m.linkname)
        if os.path.isdir(target):
            shutil.copytree(target, path, dirs_exist_ok=True)
        elif os.path.isfile(target):
            os.makedirs(os.path.dirname(path), exist_ok=True); shutil.copyfile(target, path)
        else:
            pending.append(m)
    if not pending:
        break
    links = pending
if pending:
    sys.exit("unresolved links: " + ", ".join(m.name for m in pending))
PY
  else
    tar -xzf "$archive" -C "$work"
  fi
  SLINT_SRC="$work/slint-${version}"
fi
src=$(cd "$SLINT_SRC" && pwd)

# ── build ───────────────────────────────────────────────────────────────────
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$work/target}"
export SLINT_GENERATED_INCLUDE_DIR="$work/generated_include/"
jobs=(-j "${CARGO_JOBS:-0}"); [ -n "${CARGO_JOBS:-}" ] || jobs=()
cd "$src"
if [ "$os" = macosx ]; then
  cargo rustc --release --locked ${jobs[@]+"${jobs[@]}"} -p slint-cpp --lib --no-default-features --features "$features" \
    -- -C "link-arg=-Wl,-install_name,@rpath/libslint_cpp.dylib"
else
  cargo build --release --locked ${jobs[@]+"${jobs[@]}"} -p slint-cpp --lib --no-default-features --features "$features"
fi
cargo build --release --locked ${jobs[@]+"${jobs[@]}"} -p slint-compiler

# ── assemble ────────────────────────────────────────────────────────────────
pkg="$work/$name"
mkdir -p "$pkg/bin" "$pkg/lib" "$pkg/include/slint"
rel="$CARGO_TARGET_DIR/release"
case "$os" in
  linux)   cp "$rel/libslint_cpp.so" "$pkg/lib/"; cp "$rel/slint-compiler" "$pkg/bin/" ;;
  macosx)  cp "$rel/libslint_cpp.dylib" "$pkg/lib/"; cp "$rel/slint-compiler" "$pkg/bin/" ;;
  windows) cp "$rel/slint_cpp.dll" "$pkg/bin/"; cp "$rel/slint_cpp.dll.lib" "$pkg/lib/slint_cpp.lib"
           cp "$rel/slint-compiler.exe" "$pkg/bin/" ;;
esac
cp -R "$src/api/cpp/include/." "$pkg/include/slint/"
mkdir -p "$pkg/include/slint/private"
cp -R "$SLINT_GENERATED_INCLUDE_DIR/private/." "$pkg/include/slint/private/"
# Run where upstream runs it: from the crate, whose Cargo.toml the generator
# analyzes ($PWD/Cargo.toml) -- the library's notices from api/cpp, the
# compiler's from tools/compiler (upstream's slint_tool_binary.yaml).
(cd "$src/api/cpp" && bash "$src/scripts/prepare_binary_package.sh" "$pkg" --no-default-features --features "$features")
(cd "$src/tools/compiler" && cargo run --locked --manifest-path "$src/xtask/Cargo.toml" -- license \
   --manifest-path "$src/tools/compiler/Cargo.toml" -o "$pkg/licenses/THIRDPARTY-slint-compiler.md")

# ── the closure ─────────────────────────────────────────────────────────────
# What the library and the compiler need at run time, and nothing else.
needed_ok=1
case "$os" in
  linux)
    allowed="libfontconfig.so.1 libgcc_s.so.1 libm.so.6 libc.so.6 ld-linux-x86-64.so.2 ld-linux-aarch64.so.1"
    for f in "$pkg/lib/libslint_cpp.so" "$pkg/bin/slint-compiler"; do
      for n in $(readelf -d "$f" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p'); do
        case " $allowed " in *" $n "*) ;; *) echo "UNEXPECTED NEEDED $n in $(basename "$f")" >&2; needed_ok=0 ;; esac
      done
      if readelf -d "$f" | grep -q -E "RPATH|RUNPATH"; then echo "RPATH/RUNPATH in $(basename "$f")" >&2; needed_ok=0; fi
    done
    glibc_max=$(objdump -T "$pkg/lib/libslint_cpp.so" "$pkg/bin/slint-compiler" | grep -o 'GLIBC_[0-9.]*' | sort -V | tail -1)
    ;;
  macosx)
    for f in "$pkg/lib/libslint_cpp.dylib" "$pkg/bin/slint-compiler"; do
      otool -L "$f" | tail -n +2 | awk '{print $1}' | while read -r d; do
        case "$d" in /usr/lib/*|/System/Library/*|@rpath/libslint_cpp.dylib) ;; *) echo "UNEXPECTED dylib $d in $(basename "$f")" >&2; exit 1 ;; esac
      done || needed_ok=0
    done
    otool -D "$pkg/lib/libslint_cpp.dylib" | grep -q '@rpath/libslint_cpp.dylib' || { echo "install_name is not @rpath" >&2; needed_ok=0; }
    ;;
esac
[ "$needed_ok" = 1 ] || exit 1

# ── record and pack ─────────────────────────────────────────────────────────
{
  echo "slint ${version} (tag v${version}), profile ${profile}"
  echo "cargo features (slint-cpp): --no-default-features --features ${features}"
  echo "slint-compiler: default features"
  echo "built on: ${os}-${arch}, $(rustc --version), $(cargo --version)"
  [ -n "${glibc_max:-}" ] && echo "highest glibc symbol version: ${glibc_max}"
  [ -n "${GITHUB_RUN_ID:-}" ] && echo "CI run: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID}"
  echo "SLINT_FEATURE_* defined by the headers:"
  grep -o 'define SLINT_FEATURE_[A-Z_]*' "$pkg/include/slint/private/slint_generated_public.h" | sed 's/define /  /'
} > "$pkg/BUILD-INFO.txt"

cd "$work"
if [ "$os" = windows ]; then
  (command -v 7z >/dev/null && 7z a -tzip -bd "$outdir/$name.zip" "$name" >/dev/null) \
    || powershell -NoProfile -Command "Compress-Archive -Path '$name' -DestinationPath '$(cygpath -w "$outdir/$name.zip")'"
  artifact="$outdir/$name.zip"
else
  tar -czf "$outdir/$name.tar.gz" "$name"
  artifact="$outdir/$name.tar.gz"
fi
(cd "$outdir" && { sha256sum "$(basename "$artifact")" 2>/dev/null || shasum -a 256 "$(basename "$artifact")"; } > "$(basename "$artifact").sha256")
[ -s "$artifact" ] || { echo "no archive produced" >&2; exit 1; }
cat "$pkg/BUILD-INFO.txt"
echo "built $artifact"
