# shellcheck shell=bash
# The graphics stack -- mesa and its closure (xlings design 2026-11-27 §5.8) --
# as res-build resources: sourced by tools/res/build.sh, whose helpers it uses
# (debian, source_of, input, seal, log, die; $what $version $out $work $arch
# $here).
#
# The build is this directory's: tiers.sh's order, build-in-subos.sh's build
# and its two checks (no input from the host, no host path in the payload),
# build-libllvm.sh for LLVM. They build in a SubOS, never on the machine
# around it: a released xlings makes the SubOS inside the pinned Debian
# container and installs the index's toolchain for this architecture into it.
# What the container itself gives a build is programs (sh, sed, pkg-config,
# bison), which leave nothing in a payload; build-in-subos.sh's input check
# fails a build that was configured against anything outside the home.
#
# A package is built in one SubOS with everything tiers.sh puts before it
# (minutes for the X libraries; mesa also builds LLVM), so a job needs no
# other job's artifact, and what it publishes is what it built.
#
# Then, as every res-build product: it is of this machine (rule M's static
# surface: the ELF files directly in bin/, sbin/, lib/ and lib64/), it needs no
# symbol version the index's gcc-runtime lacks (the libraries a consumer is
# given at run time are gcc-runtime 15.1.0's), it carries its provenance, and
# it is named <name>-<version>-linux-<arch>.tar.gz under the top directory the
# x86_64 payload of the same version has, which the recipe's install() moves.

# The client that makes the SubOS, and what it installs there.
gfx_client=2026.11.23.1
gfx_tools="glibc@2.44.3 gcc@16.2.0 gcc-runtime@15.1.0 binutils@2.47 ninja@1.12.1 python@3.13.12 patchelf@0.18.0 make@4.3 zlib@1.3.1 libxml2@2.13.5-1"
# cmake: Kitware's release for this architecture (inputs.txt), until the
# index's cmake entry for it is published.
gfx_cmake=4.5.1
# Built by tiers.sh but not in mesa's closure (the JDK's, the keyboard's).
gfx_skip="alsa-lib libXi libXcursor libXtst libxkbcommon"

# The upstream version tiers.sh builds, for the version the index publishes:
# mesa 25.0.7.3 is the index's third build of 25.0.7.
src_version="$version"
case "$what" in
    mesa) src_version="${version%.*}" ;;
esac

cp -r "$here/graphics" "$work/graphics"
cp "$here/inputs.txt" "$work/inputs.txt"
xl="xlings-$gfx_client-linux-$arch.tar.gz"
curl -fsSL --retry 3 -o "$work/$xl" "https://github.com/openxlings/xlings/releases/download/v$gfx_client/$xl"
curl -fsSL --retry 3 -o "$work/$xl.sha256" "https://github.com/openxlings/xlings/releases/download/v$gfx_client/$xl.sha256"
(cd "$work" && sha256sum -c "$xl.sha256" >/dev/null) || die "the xlings client does not match its digest"
source_of "cmake-linux-$arch" "$gfx_cmake" \
    "https://github.com/Kitware/CMake/releases/download/v$gfx_cmake/cmake-$gfx_cmake-linux-$arch.tar.gz" "$work/cmake.tar.gz"

if [[ "$what" == libllvm ]]; then
    gfx_step="XLINGS_GFX_STAGE=0 bash /w/graphics/build-libllvm.sh $src_version"
else
    gfx_step="bash /w/graphics/tiers.sh all --to $what --skip '$gfx_skip'"
fi
log "graphics: $what $src_version in a SubOS of xlings $gfx_client ($gfx_tools)"
debian "apt-get -qq update && apt-get -qq install -y --no-install-recommends ca-certificates curl xz-utils bzip2 file patch pkg-config bison flex gawk m4 >/dev/null \
    && mkdir -p /w/xl /w/logs && tar -xzf /w/$xl -C /w/xl && export XLINGS_HOME=/w/xh XLINGS_NON_INTERACTIVE=1 \
    && (cd /w/xl/*/ && ./bin/xlings self install) </dev/null >/w/logs/xlings-install.log 2>&1 \
    && /w/xh/bin/xlings install -y $gfx_tools </dev/null >/w/logs/tools.log 2>&1 \
    && mkdir -p /w/cmake && tar -xzf /w/cmake.tar.gz -C /w/cmake --strip-components=1 \
    && export PATH=/w/xh/subos/default/bin:/w/cmake/bin:\$PATH XLINGS_GFX_SUBOS=default XLINGS_GFX_WORK=/w/gfx XLINGS_GFX_INPUTS=/w/inputs.txt \
    && gcc --version | head -1 && cmake --version | head -1 \
    && $gfx_step" \
  || { for f in "$work"/logs/*.log $(ls -t "$work"/gfx/*.log 2>/dev/null | head -2); do
           [[ -f "$f" ]] && { log "--- ${f#"$work"/}"; tail -40 "$f" >&2; }; done
       mkdir -p "$out/failed-$what" && cp "$work"/logs/*.log "$work"/gfx/*.log "$out/failed-$what/" 2>/dev/null || true
       die "$what $src_version: the build failed"; }

built="$work/gfx/dist/$what-$src_version-linux-$arch.tar.gz"
[[ -f "$built" ]] || die "no $built"
mkdir -p "$work/pay" && tar -xzf "$built" -C "$work/pay"
d="$(ls "$work/pay")"
[[ "$d" == "$what-$src_version" ]] || die "the payload's directory is $d, not $what-$src_version"

# Rule M on the static surface, as the client judges an asset before it is
# registered (xlings docs/specs/payload-rules.md).
case "$arch" in x86_64) want=62 ;; aarch64) want=183 ;; esac
n=0
for f in "$work/pay/$d"/{bin,sbin,lib,lib64}/*; do
    [[ -f "$f" && ! -L "$f" && "$(head -c4 "$f")" == $'\x7fELF' ]] || continue
    m="$(od -An -t u2 -j 18 -N 2 "$f" | tr -d ' ')"
    [[ "$m" == "$want" ]] || die "${f#"$work/pay/"} is for ELF machine $m, not $arch"
    n=$((n + 1))
done
log "rule M: $n ELF files on the surface, all $arch"

# What it asks of the C++ runtime and of libgcc, against gcc-runtime 15.1.0.
rt="$(find "$work/xh/data/xpkgs" -path '*gcc-runtime/15.1.0/*' -name 'libstdc++.so.6' 2>/dev/null | head -1 || true)"
rt="${rt%/*}"
[[ -f "$rt/libstdc++.so.6" && -f "$rt/libgcc_s.so.1" ]] \
    || die "no gcc-runtime 15.1.0 in the SubOS's home: $(ls "$work/xh/data/xpkgs" 2>&1 | tr '\n' ' ')"
have="$(readelf -V --wide "$rt/libstdc++.so.6" "$rt/libgcc_s.so.1" | sed -n '/Version definition/,/Version needs/p' \
        | grep -oE '(GLIBCXX|CXXABI|GCC)_[0-9.]+' | sort -u || true)"
need="$(find "$work/pay/$d" -type f -exec sh -c 'head -c4 "$1" | grep -q ELF && readelf -V --wide "$1"' _ {} \; \
        | sed -n '/Version needs/,$p' | grep -oE '(GLIBCXX|CXXABI|GCC)_[0-9.]+' | sort -u || true)"
missing="$(comm -13 <(echo "$have") <(echo "$need") | tr '\n' ' ')"
[[ -z "${missing// /}" ]] || die "needs $missing, which gcc-runtime 15.1.0 does not define"
glibc_max="$(find "$work/pay/$d" -type f -exec sh -c 'head -c4 "$1" | grep -q ELF && readelf -V --wide "$1"' _ {} \; \
        | grep -oE 'GLIBC_2\.[0-9]+' | sort -t. -k2 -n -u | tail -1 || true)"
log "runtime: every C++ and libgcc symbol version is gcc-runtime 15.1.0's; newest glibc one ${glibc_max:-none}"

provenance "pay/$d" "$what $src_version for linux-$arch, built from upstream's source (sha256 in xim-pkgindex tools/res/inputs.txt) by tools/res/graphics (tiers.sh, build-in-subos.sh$([[ "$what" == libllvm || "$what" == mesa ]] && echo ", build-libllvm.sh")) in a SubOS that xlings $gfx_client made in Debian 12 with the index's $gfx_tools, and cmake $gfx_cmake (Kitware); checked: no input from outside the home, no host path in the payload, rule M on its surface ($n files), no symbol version beyond gcc-runtime 15.1.0 (newest glibc: ${glibc_max:-none})"
file="$out/$what-$version-linux-$arch.tar.gz"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 --format=gnu --hard-dereference -cf - -C "$work/pay" "$d" | gzip -n -9 > "$file"
python3 -c 'import sys, tarfile; sys.exit(any(m.islnk() for m in tarfile.open(sys.argv[1])))' "$file" || die "$file holds a hard link"
seal "$file"
