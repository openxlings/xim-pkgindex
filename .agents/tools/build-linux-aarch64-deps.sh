#!/usr/bin/env bash
# Build the native LLVM dependency closure from pinned upstream releases.
# Distribution tools are bootstrap inputs; published libraries carry no host
# search paths. gcc-runtime is built from GCC 15.1.0, not renamed distro files.
set -euo pipefail
[[ $(uname -m) == aarch64 || $(uname -m) == arm64 ]] || { echo 'native aarch64 host required' >&2; exit 1; }
WORK="${AARCH64_DEPS_WORK:-/tmp/aarch64-deps}"
OUT="${AARCH64_DEPS_OUT:-/tmp/aarch64-assets}"
JOBS="${AARCH64_DEPS_JOBS:-$(nproc)}"
mkdir -p "$WORK" "$OUT"
: > "$OUT/upstream-sources.sha256"
fetch() {
    local url="$1" file="$2" expected="$3"
    [[ -f "$file" ]] || curl -fL --retry 3 "$url" -o "$file"
    printf "%s  %s\n" "$expected" "$file" | sha256sum -c -
    sha256sum "$file" >> "$OUT/upstream-sources.sha256"
}
pack() {
    local stem="$1"
    {
        printf 'Package: %s\nArchitecture: aarch64\n' "$stem"
        printf 'Builder: %s\n' "$(uname -srmo)"
        printf 'Bootstrap compiler: %s\n' "$(gcc --version | head -1)"
        printf 'Source archive digests:\n'
        cat "$OUT/upstream-sources.sha256"
    } > "$WORK/$stem/PROVENANCE.txt"
    : > "$WORK/$stem/ELF-MANIFEST.txt"
    while IFS= read -r -d '' file; do
        [[ $(head -c 4 "$file") == $'\x7fELF' ]] || continue
        readelf -h "$file" | grep -q 'Machine:.*AArch64' || { echo "foreign ELF: $file" >&2; exit 1; }
        patchelf --remove-rpath "$file"
        {
            printf '\nFile: %s\n' "${file#"$WORK/$stem/"}"
            sha256sum "$file"
            readelf -h -l -d -V "$file"
        } >> "$WORK/$stem/ELF-MANIFEST.txt"
    done < <(find "$WORK/$stem" -type f \( -name '*.so*' -o -perm -u+x \) -print0)
    tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@${SOURCE_DATE_EPOCH:-0}" -C "$WORK" -cf - "$stem" | gzip -n -9 > "$OUT/$stem.tar.gz"
    (cd "$OUT" && sha256sum "$stem.tar.gz" > "$stem.tar.gz.sha256")
}
# Header-only artifacts still require target-specific asm/ headers.
fetch https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.11.1.tar.xz "$WORK/linux-5.11.1.tar.xz" 057d6522edf930fe52271cd616ae918fdb591a60809c9c01fa698041f764b9be
tar -xf "$WORK/linux-5.11.1.tar.xz" -C "$WORK"
rm -rf "$WORK/linux-headers-5.11.1-linux-aarch64"
make -C "$WORK/linux-5.11.1" ARCH=arm64 headers_install INSTALL_HDR_PATH="$WORK/linux-headers-5.11.1-linux-aarch64"
cp "$WORK/linux-5.11.1/COPYING" "$WORK/linux-headers-5.11.1-linux-aarch64/LICENSE"
pack linux-headers-5.11.1-linux-aarch64

fetch https://zlib.net/fossils/zlib-1.3.1.tar.gz "$WORK/zlib-1.3.1.tar.gz" 9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
tar -xf "$WORK/zlib-1.3.1.tar.gz" -C "$WORK"
rm -rf "$WORK/zlib-1.3.1-linux-aarch64"
(cd "$WORK/zlib-1.3.1" && ./configure --prefix=/usr && make -j"$JOBS" && make install DESTDIR="$WORK/zlib-1.3.1-linux-aarch64/stage")
mv "$WORK/zlib-1.3.1-linux-aarch64/stage/usr/"* "$WORK/zlib-1.3.1-linux-aarch64/"
rm -rf "$WORK/zlib-1.3.1-linux-aarch64/stage"
cp "$WORK/zlib-1.3.1/LICENSE" "$WORK/zlib-1.3.1-linux-aarch64/LICENSE"
pack zlib-1.3.1-linux-aarch64

fetch https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.5.tar.xz "$WORK/libxml2-2.13.5.tar.xz" 74fc163217a3964257d3be39af943e08861263c4231f9ef5b496b6f6d4c7b2b6
tar -xf "$WORK/libxml2-2.13.5.tar.xz" -C "$WORK"
rm -rf "$WORK/libxml2-2.13.5-linux-aarch64"
(cd "$WORK/libxml2-2.13.5" && ./configure --prefix=/usr --without-python --without-lzma --without-zlib --without-readline --without-iconv && make -j"$JOBS" && make install DESTDIR="$WORK/libxml2-2.13.5-linux-aarch64/stage")
mv "$WORK/libxml2-2.13.5-linux-aarch64/stage/usr/"* "$WORK/libxml2-2.13.5-linux-aarch64/"
rm -rf "$WORK/libxml2-2.13.5-linux-aarch64/stage"
cp "$WORK/libxml2-2.13.5/Copyright" "$WORK/libxml2-2.13.5-linux-aarch64/LICENSE"
pack libxml2-2.13.5-linux-aarch64

fetch https://ftp.gnu.org/gnu/gcc/gcc-15.1.0/gcc-15.1.0.tar.xz "$WORK/gcc-15.1.0.tar.xz" e2b09ec21660f01fecffb715e0120265216943f038d0e48a9868713e54f06cea
tar -xf "$WORK/gcc-15.1.0.tar.xz" -C "$WORK"
rm -rf "$WORK/gcc-runtime-15.1.0-linux-aarch64"
mkdir -p "$WORK/gcc-build" "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64"
(cd "$WORK/gcc-build" && "$WORK/gcc-15.1.0/configure" --prefix=/usr --enable-languages=c,c++ --disable-bootstrap --disable-multilib --disable-libsanitizer --disable-libvtv --disable-libquadmath --disable-libssp --without-isl && make -j"$JOBS")
# Only libraries are published; compiler executables remain build inputs.
while IFS= read -r -d '' file; do
    name="$(basename "$file")"
    [[ "$name" =~ ^lib(std[c][+][+]|gcc_s|gomp|atomic|itm)[.]so([.][0-9]+)*$ ]] || continue
    cp -a "$file" "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64/"
done < <(find "$WORK/gcc-build/aarch64-unknown-linux-gnu" -name 'lib*.so*' \( -type f -o -type l \) -print0)
[[ -f "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64/libstdc++.so.6" ]]
[[ -f "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64/libgcc_s.so.1" ]]
[[ -f "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64/libatomic.so.1" ]]
cp "$WORK/gcc-15.1.0/COPYING3" "$WORK/gcc-runtime-15.1.0-linux-aarch64/COPYING3"
cp "$WORK/gcc-15.1.0/COPYING.RUNTIME" "$WORK/gcc-runtime-15.1.0-linux-aarch64/LICENSE"
pack gcc-runtime-15.1.0-linux-aarch64
