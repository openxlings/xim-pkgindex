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
fetch() {
    local url="$1" file="$2"
    [[ -f "$file" ]] || curl -fL --retry 3 "$url" -o "$file"
    sha256sum "$file" >> "$OUT/upstream-sources.sha256"
}
pack() {
    local stem="$1"
    while IFS= read -r -d '' file; do
        [[ $(head -c 4 "$file") == $'\x7fELF' ]] || continue
        readelf -h "$file" | grep -q 'Machine:.*AArch64' || { echo "foreign ELF: $file" >&2; exit 1; }
        patchelf --remove-rpath "$file"
    done < <(find "$WORK/$stem" -type f \( -name '*.so*' -o -perm -u+x \) -print0)
    tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@${SOURCE_DATE_EPOCH:-0}" -C "$WORK" -cf - "$stem" | gzip -n -9 > "$OUT/$stem.tar.gz"
    (cd "$OUT" && sha256sum "$stem.tar.gz" > "$stem.tar.gz.sha256")
}
# Header-only artifacts still require target-specific asm/ headers.
fetch https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.11.1.tar.xz "$WORK/linux-5.11.1.tar.xz"
tar -xf "$WORK/linux-5.11.1.tar.xz" -C "$WORK"
make -C "$WORK/linux-5.11.1" ARCH=arm64 headers_install INSTALL_HDR_PATH="$WORK/linux-headers-5.11.1-linux-aarch64"
pack linux-headers-5.11.1-linux-aarch64

fetch https://zlib.net/fossils/zlib-1.3.1.tar.gz "$WORK/zlib-1.3.1.tar.gz"
tar -xf "$WORK/zlib-1.3.1.tar.gz" -C "$WORK"
(cd "$WORK/zlib-1.3.1" && ./configure --prefix=/usr && make -j"$JOBS" && make install DESTDIR="$WORK/zlib-1.3.1-linux-aarch64/stage")
mv "$WORK/zlib-1.3.1-linux-aarch64/stage/usr/"* "$WORK/zlib-1.3.1-linux-aarch64/"
rm -rf "$WORK/zlib-1.3.1-linux-aarch64/stage"
pack zlib-1.3.1-linux-aarch64

fetch https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.5.tar.xz "$WORK/libxml2-2.13.5.tar.xz"
tar -xf "$WORK/libxml2-2.13.5.tar.xz" -C "$WORK"
(cd "$WORK/libxml2-2.13.5" && ./configure --prefix=/usr --without-python --without-lzma --without-zlib --without-readline --without-iconv && make -j"$JOBS" && make install DESTDIR="$WORK/libxml2-2.13.5-linux-aarch64/stage")
mv "$WORK/libxml2-2.13.5-linux-aarch64/stage/usr/"* "$WORK/libxml2-2.13.5-linux-aarch64/"
rm -rf "$WORK/libxml2-2.13.5-linux-aarch64/stage"
pack libxml2-2.13.5-linux-aarch64

fetch https://ftp.gnu.org/gnu/gcc/gcc-15.1.0/gcc-15.1.0.tar.xz "$WORK/gcc-15.1.0.tar.xz"
tar -xf "$WORK/gcc-15.1.0.tar.xz" -C "$WORK"
mkdir -p "$WORK/gcc-build" "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64"
(cd "$WORK/gcc-build" && "$WORK/gcc-15.1.0/configure" --prefix=/usr --enable-languages=c,c++ --disable-bootstrap --disable-multilib --disable-libsanitizer --disable-libvtv --disable-libquadmath --disable-libssp --without-isl && make -j"$JOBS")
# Only libraries are published; compiler executables remain build inputs.
while IFS= read -r -d '' file; do
    cp -a "$file" "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64/"
done < <(find "$WORK/gcc-build/aarch64-unknown-linux-gnu" -name 'lib*.so*' \( -type f -o -type l \) -print0)
[[ -f "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64/libstdc++.so.6" ]]
[[ -f "$WORK/gcc-runtime-15.1.0-linux-aarch64/lib64/libgcc_s.so.1" ]]
pack gcc-runtime-15.1.0-linux-aarch64
