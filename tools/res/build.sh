#!/usr/bin/env bash
# Build an xlings-res resource this index publishes, reproducibly, on the
# architecture it is for (xlings: Luban OS design part 2 §4.2; the aarch64
# ecosystem: .agents/docs/2026-10-11-luban-aarch64-and-docs-i18n-design.md in
# xlings).
#
#   tools/res/build.sh <what> <version> <out>
#
#   limine        boot files + a static `limine` tool
#   kernel-virt   a virt kernel: virtio, ext4, console built in
#   busybox       a static busybox (musl)
#   bwrap         a static bubblewrap (musl)
#   passt         static pasta and passt (musl)
#   e2fsprogs     static mke2fs & co (musl)
#   curl          a static curl (musl; TLS, socks5h)
#   proot         a static proot (musl)
#   musl          the musl libc payload, relocatable (loader links to libc.so)
#   make          a static GNU make (musl)
#   git           a static git (musl; https through libcurl), runtime prefix
#   vim           a static vim (musl) and its runtime files
#   wl-clipboard  static wl-copy / wl-paste (musl; libwayland built static)
#   xsel          a static xsel (musl; libX11/xcb static)
#   edk2-firmware the UEFI firmware qemu ships, decompressed (no build)
#   qemu-system   static qemu-system-x86_64 and -aarch64 (musl; user networking)
#   bash          bash on glibc (the shape x86_64's is)
#   coreutils     coreutils on glibc
#   openssl       openssl on glibc, lib64
#   binutils      binutils on glibc
#   gcc           gcc on glibc, configured as x86_64's (fromsource:gcc),
#                 against a sysroot xlings makes (glibc + linux-headers)
#
# Runs on the machine of the target architecture (CI: ubuntu-24.04 and
# ubuntu-24.04-arm). What it needs runs in a pinned container: the runner
# needs docker and nothing else. Static builds use Alpine (musl); what is
# linked against glibc uses Debian, the glibc an xlings install then patches
# onto the index's (elfpatch), as the x86_64 payloads are. The packages
# installed INSIDE a container are this factory's recipe, recorded in each
# payload's README.provenance; that the factory itself is built from the
# index (self-hosting) is the direction, not yet the state.
#
# Inputs are checked against digests in inputs.txt (upstream's own, or the
# digest measured when the input was added). Each build writes
# <out>/<name>-<version>-linux-<arch>.tar.gz (or the raw ELF for busybox) and
# a .sha256 beside it.
set -euo pipefail

what="$1"; version="$2"; out="$(mkdir -p "$3" && cd "$3" && pwd)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
arch="$(uname -m)"; [[ "$arch" == arm64 ]] && arch=aarch64
work="$(mktemp -d)"; trap 'rm -rf "$work" 2>/dev/null || sudo rm -rf "$work"' EXIT
log() { printf '[res] %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }

# The factory: pinned by digest (a tag moves; a digest does not).
ALPINE="alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc"
DEBIAN="debian:12@sha256:2c037a04925515fdd6ea85ea14a682d0e79931f5e9f5d07b6dbfc6ba12f9e858"
# The xlings that makes a sysroot for what links glibc.
XLINGS_CLIENT="${XLINGS_CLIENT:-2026.10.11.2}"

fetch() {   # url, expected sha256, file
    curl -fsSL --retry 3 -o "$3" "$1"
    echo "$2  $3" | sha256sum -c - >/dev/null || die "sha256 mismatch: $1"
}

input() {   # name version -> the recorded digest
    local sha; sha="$(awk -v n="$1" -v v="$2" '$1 == n && $2 == v { print $3 }' "$here/inputs.txt")"
    [[ -n "$sha" ]] || die "no input digest for $1 $2 in tools/res/inputs.txt"
    printf '%s' "$sha"
}

source_of() {   # name version url file
    fetch "$3" "$(input "$1" "$2")" "$4"
}

# A command in a container, $work mounted at /w; what it makes is ours after.
# The files go back to the runner's user however the build ends, and the
# build's status is the container's: a failed `a && b` chain fails it.
alpine() { docker run --rm -v "$work:/w" -w /w "$ALPINE" sh -euc "trap 'chown -R $(id -u):$(id -g) /w' EXIT; $1"; }
debian() {
    docker run --rm -v "$work:/w" -w /w -e DEBIAN_FRONTEND=noninteractive "$DEBIAN" \
        bash -euo pipefail -c "trap 'chown -R $(id -u):$(id -g) /w' EXIT; $1"
}

seal() {    # file -> file.sha256
    (cd "$(dirname "$1")" && sha256sum "$(basename "$1")" > "$(basename "$1").sha256")
    log "$(cat "$1.sha256")"
}

# Never a hard link in a payload: xlings extracts one with link(2), which
# Android's app sandbox and FAT refuse (.github/scripts/check-payload-hard-links.py).
pack() {    # directory under $work [contents only] -> $out/<name>-<version>-linux-<arch>.tar.gz
    local file="$out/$what-$version-linux-$arch.tar.gz"
    if [[ "${2:-}" == contents ]]; then
        tar --owner=0 --group=0 --numeric-owner --hard-dereference -czf "$file" -C "$work/$1" .
    else
        tar --owner=0 --group=0 --numeric-owner --hard-dereference -czf "$file" -C "$work" "$1"
    fi
    seal "$file"
    python3 -c 'import sys, tarfile; sys.exit(any(m.islnk() for m in tarfile.open(sys.argv[1])))' "$file" \
        || die "$file holds a hard link"
}

provenance() {  # directory, text
    printf '%s\n' "$2" > "$work/$1/README.provenance"
}

static_only() {   # every ELF given is statically linked
    local f
    for f in "$@"; do
        file -L "$f" | grep -Eq "statically linked|static-pie linked" || die "not static: $f ($(file -b "$f"))"
    done
}

glibc_only() {    # every ELF given needs nothing but glibc's libraries (and its own, named)
    local f lib allowed="libc.so.6 libm.so.6 libdl.so.2 libpthread.so.0 librt.so.1 ld-linux-aarch64.so.1 ld-linux-x86-64.so.2 $*"
    for f in $GLIBC_ELFS; do
        for lib in $(readelf -d "$f" 2>/dev/null | awk '/NEEDED/ { gsub(/[\[\]]/, "", $NF); print $NF }'); do
            [[ " $allowed " == *" $lib "* ]] || die "$f needs $lib, which no declared dependency provides"
        done
    done
}

APK_STATIC="build-base linux-headers"

case "$what" in
limine)
    sha="$(input limine-binary "$version")"
    fetch "https://github.com/limine-bootloader/limine/releases/download/v$version/limine-binary.tar.gz" "$sha" "$work/src.tar.gz"
    tar -xzf "$work/src.tar.gz" -C "$work"
    alpine "apk add -q build-base && cc -O2 -std=gnu11 -static -o /w/limine limine-binary/limine.c && strip /w/limine"
    root="$work/limine-$version"
    mkdir -p "$root/bin" "$root/share/limine"
    cp "$work/limine" "$root/bin/limine"
    for f in limine-bios-cd.bin limine-bios.sys limine-uefi-cd.bin limine-bios-pxe.bin \
             BOOTX64.EFI BOOTAA64.EFI BOOTIA32.EFI BOOTRISCV64.EFI LICENSE; do
        [[ -f "$work/limine-binary/$f" ]] && cp "$work/limine-binary/$f" "$root/share/limine/"
    done
    printf 'limine %s: upstream limine-binary.tar.gz (sha256 %s); bin/limine built static (musl, Alpine 3.20) from its limine.c\n' \
        "$version" "$sha" > "$root/README.provenance"
    file="$out/limine-$version-linux-$arch.tar.gz"
    tar --owner=0 --group=0 --numeric-owner --hard-dereference -czf "$file" -C "$work" "limine-$version"
    seal "$file" ;;
kernel-virt)
    sums="$work/sha256sums.asc"
    curl -fsSL --retry 3 -o "$sums" "https://cdn.kernel.org/pub/linux/kernel/v${version%%.*}.x/sha256sums.asc"
    sha="$(grep " linux-$version.tar.xz\$" "$sums" | cut -d' ' -f1)"
    [[ -n "$sha" ]] || die "kernel.org lists no linux-$version.tar.xz"
    fetch "https://cdn.kernel.org/pub/linux/kernel/v${version%%.*}.x/linux-$version.tar.xz" "$sha" "$work/linux.tar.xz"
    cp "$here/kernel-virt.config" "$work/"
    karch=x86; image=arch/x86/boot/bzImage
    [[ "$arch" == aarch64 ]] && { karch=arm64; image=arch/arm64/boot/Image; }
    debian "apt-get -qq update && apt-get -qq install -y build-essential flex bison bc libelf-dev libssl-dev xz-utils kmod cpio >/dev/null \
        && tar -xJf linux.tar.xz && cd linux-$version \
        && make -s ARCH=$karch defconfig && make -s ARCH=$karch kvm_guest.config \
        && scripts/kconfig/merge_config.sh -m -O . .config /w/kernel-virt.config >/dev/null \
        && make -s ARCH=$karch olddefconfig \
        && for opt in VIRTIO_BLK VIRTIO_NET VIRTIO_PCI VIRTIO_CONSOLE EXT4_FS BLK_DEV_INITRD RD_GZIP DEVTMPFS DEVTMPFS_MOUNT EFI_STUB; do \
             grep -q \"^CONFIG_\$opt=y\" .config || { echo \"CONFIG_\$opt is not built in\"; exit 1; }; done \
        && make -s ARCH=$karch -j\$(nproc) LOCALVERSION=-virt $(basename "$image") \
        && make -s ARCH=$karch LOCALVERSION=-virt kernelrelease > /w/release"
    src="$work/linux-$version"; release="$(cat "$work/release")"
    root="$work/linux-kernel-virt-$version"
    mkdir -p "$root/lib/modules/$release"
    cp "$src/$image" "$root/lib/modules/$release/vmlinuz"
    cp "$src/.config" "$root/lib/modules/$release/config"
    printf 'linux %s (kernel.org, sha256 %s), %s defconfig + kvm_guest.config + kernel-virt.config; built in Debian 12; no modules: what a virtual machine needs is built in\n' \
        "$version" "$sha" "$karch" > "$root/README.provenance"
    file="$out/linux-kernel-virt-$version-linux-$arch.tar.gz"
    tar --owner=0 --group=0 --numeric-owner --hard-dereference -czf "$file" -C "$work" "linux-kernel-virt-$version"
    seal "$file" ;;
busybox)
    source_of busybox "$version" "https://busybox.net/downloads/busybox-$version.tar.bz2" "$work/busybox.tar.bz2"
    alpine "apk add -q build-base linux-headers perl && tar -xjf busybox.tar.bz2 && cd busybox-$version \
        && make -s defconfig >/dev/null && sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/; s/^CONFIG_TC=y/# CONFIG_TC is not set/' .config \
        && make -s oldconfig </dev/null >/dev/null && make -s -j\$(nproc) busybox && strip busybox && cp busybox /w/busybox.out"
    file="$out/busybox-$version-linux-$arch"
    cp "$work/busybox.out" "$file"
    seal "$file" ;;
bwrap)
    source_of bubblewrap "$version" "https://github.com/containers/bubblewrap/releases/download/v$version/bubblewrap-$version.tar.xz" "$work/bwrap.tar.xz"
    alpine "apk add -q build-base meson ninja-build pkgconf libcap-dev libcap-static linux-headers xz \
        && tar -xJf bwrap.tar.xz && cd bubblewrap-$version \
        && LDFLAGS=-static meson setup build --prefix=/usr --default-library=static --prefer-static \
             -Dman=disabled -Dselinux=disabled -Dtests=false -Dbash_completion=disabled -Dzsh_completion=disabled >/dev/null \
        && ninja -C build bwrap >/dev/null && strip build/bwrap && cp build/bwrap /w/bwrap.out"
    static_only "$work/bwrap.out"
    root="$work/bwrap-$version-linux-$arch"
    mkdir -p "$root/bin"
    cp "$work/bwrap.out" "$root/bin/bwrap"
    file="$out/bwrap-$version-linux-$arch.tar.gz"
    tar --owner=0 --group=0 --numeric-owner --hard-dereference -czf "$file" -C "$work" "bwrap-$version-linux-$arch"
    seal "$file" ;;
passt)
    # Upstream tags are <date>.<commit>; the commit is the input, checked.
    commit="$(input passt "$version")"
    git clone -q https://passt.top/passt "$work/passt"
    git -C "$work/passt" checkout -q "$commit"
    [[ "$(git -C "$work/passt" rev-parse HEAD)" == "$commit" ]] || die "passt: $commit is not what was checked out"
    d="passt-$version-linux-$arch"
    alpine "apk add -q build-base linux-headers coreutils && cd passt && make -s static VERSION=$version >/dev/null \
        && mkdir -p /w/$d/bin && cp pasta passt /w/$d/bin/ && strip /w/$d/bin/*"
    static_only "$work/$d/bin/pasta" "$work/$d/bin/passt"
    "$work/$d/bin/pasta" --version | head -1 | grep -q "$version" || die "pasta does not report $version"
    provenance "$d" "passt $version: git https://passt.top/passt at $commit; make static in Alpine 3.20 (musl)"
    pack "$d" ;;
e2fsprogs)
    source_of e2fsprogs "$version" "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v$version/e2fsprogs-$version.tar.xz" "$work/src.tar.xz"
    d="e2fsprogs-$version-linux-$arch"
    alpine "apk add -q $APK_STATIC xz && tar -xJf src.tar.xz && mkdir build && cd build \
        && ../e2fsprogs-$version/configure -q --prefix=/usr --sysconfdir=/etc --with-root-prefix= \
             --enable-libuuid --enable-libblkid --disable-nls --disable-fuse2fs --disable-elf-shlibs \
             --disable-uuidd --disable-fsck LDFLAGS=-static >/dev/null \
        && make -s -j\$(nproc) >/dev/null && make -s install DESTDIR=/w/stage >/dev/null \
        && mkdir -p /w/$d/sbin /w/$d/usr/sbin /w/$d/etc \
        && cp -a /w/stage/sbin/. /w/$d/sbin/ && cp -a /w/stage/usr/sbin/. /w/$d/usr/sbin/ \
        && cp ../e2fsprogs-$version/misc/mke2fs.conf.in /w/$d/etc/mke2fs.conf \
        && strip /w/$d/sbin/* /w/$d/usr/sbin/* 2>/dev/null || true"
    [[ -x "$work/$d/sbin/mke2fs" ]] || die "no sbin/mke2fs"
    static_only "$work/$d/sbin/mke2fs"
    "$work/$d/sbin/mke2fs" -V 2>&1 | grep -q "$version" || die "mke2fs does not report $version"
    provenance "$d" "e2fsprogs $version (kernel.org, sha256 $(input e2fsprogs "$version")); static, Alpine 3.20 (musl)"
    pack "$d" ;;
curl)
    source_of curl "$version" "https://curl.se/download/curl-$version.tar.xz" "$work/src.tar.xz"
    d="curl-$version-linux-$arch"
    alpine "apk add -q $APK_STATIC xz openssl-dev openssl-libs-static zlib-dev zlib-static nghttp2-dev nghttp2-static pkgconf \
        && tar -xJf src.tar.xz && cd curl-$version \
        && ./configure -q --prefix=/usr --disable-shared --enable-static --with-openssl --with-nghttp2 --with-zlib \
             --without-libpsl --without-libidn2 --without-brotli --without-zstd --disable-ldap --disable-manual \
             --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --with-ca-fallback LDFLAGS=-static \
             PKG_CONFIG='pkg-config --static' >/dev/null \
        && make -s -j\$(nproc) LDFLAGS=-all-static >/dev/null \
        && mkdir -p /w/$d/bin && cp src/curl /w/$d/bin/ && strip /w/$d/bin/curl"
    static_only "$work/$d/bin/curl"
    "$work/$d/bin/curl" --version | grep -q "curl $version" || die "curl does not report $version"
    "$work/$d/bin/curl" --version | grep -qi "socks5" || "$work/$d/bin/curl" --help all | grep -q -- "--socks5-hostname" || die "curl has no socks5h"
    provenance "$d" "curl $version (curl.se, sha256 $(input curl "$version")); static with OpenSSL, nghttp2, zlib; Alpine 3.20 (musl)"
    pack "$d" ;;
proot)
    source_of proot "$version" "https://github.com/proot-me/proot/archive/refs/tags/v$version.tar.gz" "$work/src.tar.gz"
    d="proot-$version-linux-$arch"
    alpine "apk add -q $APK_STATIC talloc-dev talloc-static bsd-compat-headers bash && tar -xzf src.tar.gz && cd proot-$version/src \
        && make -s loader.elf build.h >/dev/null && make -s -j\$(nproc) proot LDFLAGS='-static -ltalloc' >/dev/null \
        && mkdir -p /w/$d/bin && cp proot /w/$d/bin/ && strip /w/$d/bin/proot"
    static_only "$work/$d/bin/proot"
    "$work/$d/bin/proot" --help >/dev/null 2>&1 || die "proot does not run"
    provenance "$d" "proot $version (github.com/proot-me/proot tag v$version, sha256 $(input proot "$version")); static with talloc; Alpine 3.20 (musl)"
    pack "$d" ;;
musl)
    # Relocatable: the loader link is relative (lib/ld-musl-<arch>.so.1 ->
    # libc.so) and lives under the prefix; libc.so names no RPATH.
    source_of musl "$version" "https://musl.libc.org/releases/musl-$version.tar.gz" "$work/src.tar.gz"
    d="musl-$version"
    prefix="/home/xlings/.xlings_data/xim/xpkgs/fromsource-x-musl/$version"
    alpine "apk add -q build-base && tar -xzf src.tar.gz && cd musl-$version \
        && ./configure --prefix=$prefix --syslibdir=$prefix/lib --disable-gcc-wrapper --enable-shared --enable-static >/dev/null \
        && make -s -j\$(nproc) >/dev/null && make -s install DESTDIR=/w/stage >/dev/null \
        && mkdir -p /w/$d && cp -a /w/stage$prefix/. /w/$d/ \
        && ln -sfn libc.so /w/$d/lib/ld-musl-$arch.so.1 && { [ -e /w/$d/lib64 ] || ln -s lib /w/$d/lib64; } \
        && printf 'int printf(const char*,...); int main(void){printf(\"musl payload ok\\\\n\");return 0;}\n' > /w/hello.c \
        && gcc -nostdinc -nostdlib -isystem /w/$d/include -o /w/hello /w/$d/lib/crt1.o /w/$d/lib/crti.o /w/hello.c \
             -L/w/$d/lib -lc /w/$d/lib/crtn.o -Wl,--dynamic-linker=/w/$d/lib/ld-musl-$arch.so.1 \
        && test \"\$(/w/hello)\" = 'musl payload ok' \
        && /w/$d/lib/libc.so 2>&1 | grep -q 'Version $version'"
    [[ -z "$(readelf -d "$work/$d/lib/libc.so" | grep -E 'RPATH|RUNPATH' || true)" ]] || die "libc.so names an RPATH"
    [[ "$(readlink "$work/$d/lib/ld-musl-$arch.so.1")" == libc.so ]] || die "the loader link is not relative"
    provenance "$d" "musl $version (musl.libc.org, sha256 $(input musl "$version")); built in Alpine 3.20; loader link relative, no RPATH; a program linked against it ran"
    pack "$d" ;;
make)
    source_of make "$version" "https://ftpmirror.gnu.org/gnu/make/make-$version.tar.gz" "$work/src.tar.gz"
    d="make-$version-linux-$arch"
    alpine "apk add -q build-base && tar -xzf src.tar.gz && cd make-$version \
        && ./configure -q --prefix=/w/$d --disable-nls LDFLAGS=-static CFLAGS='-O2 -std=gnu11' >/dev/null \
        && make -s -j\$(nproc) >/dev/null && make -s install >/dev/null \
        && strip /w/$d/bin/make && ln -sf make /w/$d/bin/gmake && rm -f /w/$d/share/info/dir"
    static_only "$work/$d/bin/make"
    "$work/$d/bin/make" --version | grep -q "GNU Make $version" || die "make does not report $version"
    provenance "$d" "GNU make $version (ftpmirror.gnu.org, sha256 $(input make "$version")); static, Alpine 3.20 (musl)"
    pack "$d" ;;
git)
    # <upstream>-<n>: n counts this index's own builds of that release.
    up="${version%-*}"
    source_of git "$up" "https://mirrors.edge.kernel.org/pub/software/scm/git/git-$up.tar.xz" "$work/src.tar.xz"
    cv="$(awk '$1 == "curl" { print $2 }' "$here/inputs.txt")"
    source_of curl "$cv" "https://curl.se/download/curl-$cv.tar.xz" "$work/curl.tar.xz"
    flags="prefix=/ gitexecdir=libexec/git-core template_dir=share/git-core/templates sysconfdir=/etc \
        RUNTIME_PREFIX=YesPlease NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_PERL=YesPlease NO_PYTHON=YesPlease \
        NO_REGEX=NeedsStartEnd NO_INSTALL_HARDLINKS=YesPlease USE_LIBPCRE= CURL_CONFIG=/opt/curl/bin/curl-config \
        CURL_LDFLAGS='-L/opt/curl/lib -lcurl -lnghttp2 -lssl -lcrypto -lz' LDFLAGS=-static CFLAGS=-O2"
    # libcurl as the curl package is built (no IDN, no PSL: libidn2's gnulib
    # error() collides with git's), so git's https is that curl's.
    alpine "apk add -q $APK_STATIC xz openssl-dev openssl-libs-static zlib-dev zlib-static nghttp2-dev nghttp2-static \
            expat-dev expat-static pkgconf perl file \
        && tar -xJf curl.tar.xz && cd curl-$cv \
        && ./configure -q --prefix=/opt/curl --disable-shared --enable-static --with-openssl --with-nghttp2 --with-zlib \
             --without-libpsl --without-libidn2 --without-brotli --without-zstd --disable-ldap --disable-manual \
             --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --with-ca-fallback >/dev/null \
        && make -s -j\$(nproc) >/dev/null && make -s install >/dev/null && cd /w \
        && tar -xJf src.tar.xz && cd git-$up \
        && make -s -j\$(nproc) $flags all >/dev/null \
        && make -s $flags DESTDIR=/w/git install >/dev/null \
        && rm -rf /w/git/share/man /w/git/share/perl5 /w/git/share/gitweb \
        && find /w/git/bin /w/git/libexec -type f -perm -u+x -exec sh -c 'file \"\$1\" | grep -q ELF && strip \"\$1\"' _ {} \\;"
    static_only "$work/git/bin/git" "$work/git/libexec/git-core/git-remote-https"
    "$work/git/bin/git" --version | grep -q "git version $up" || die "git does not report $up"
    "$work/git/bin/git" --exec-path | grep -q "$work/git/libexec/git-core" || die "git's exec path is not relative to itself"
    provenance git "git $up (kernel.org, sha256 $(input git "$up")); static (curl, OpenSSL, expat, zlib), RUNTIME_PREFIX; Alpine 3.20 (musl)"
    pack git contents ;;
vim)
    source_of vim "$version" "https://github.com/vim/vim/archive/refs/tags/v$version.tar.gz" "$work/src.tar.gz"
    d="vim-$version-linux-$arch"
    alpine "apk add -q $APK_STATIC ncurses-dev ncurses-static && tar -xzf src.tar.gz && cd vim-$version \
        && ./configure -q --prefix=/usr --with-features=huge --disable-gui --without-x --disable-nls \
             --enable-multibyte --disable-netbeans --disable-canberra --disable-libsodium --with-tlib=ncursesw \
             LDFLAGS=-static >/dev/null \
        && make -s -j\$(nproc) >/dev/null && make -s install DESTDIR=/w/stage >/dev/null \
        && mkdir -p /w/$d/bin /w/$d/share && cp /w/stage/usr/bin/vim /w/$d/bin/ && strip /w/$d/bin/vim \
        && cp -a /w/stage/usr/share/vim /w/$d/share/"
    static_only "$work/$d/bin/vim"
    "$work/$d/bin/vim" --version | head -3 | grep -q "Included patches: 1-${version##*.}" || die "vim does not report $version"
    rt="$(ls -d "$work/$d/share/vim"/vim[0-9]* | head -1)"
    [[ -f "$rt/syntax/syntax.vim" ]] || die "no runtime files"
    VIM="$work/$d/share/vim" "$work/$d/bin/vim" -es -N -u NONE -c 'if !filereadable($VIMRUNTIME . "/syntax/syntax.vim") | cquit | endif' -c 'qa!' \
        || die "vim does not find its runtime through \$VIM"
    provenance "$d" "vim $version (github.com/vim/vim tag v$version, sha256 $(input vim "$version")); static (ncurses), huge features, no X; runtime in share/vim; Alpine 3.20 (musl)"
    pack "$d" ;;
wl-clipboard)
    source_of wl-clipboard "$version" "https://github.com/bugaevc/wl-clipboard/archive/refs/tags/v$version.tar.gz" "$work/src.tar.gz"
    wv="$(awk '$1 == "wayland" { print $2 }' "$here/inputs.txt")"
    source_of wayland "$wv" "https://gitlab.freedesktop.org/wayland/wayland/-/releases/$wv/downloads/wayland-$wv.tar.xz" "$work/wayland.tar.xz"
    d="wl-clipboard-$version-linux-$arch"
    # libwayland-client built static, with its own scanner (the
    # distribution's is another version).
    alpine "apk add -q $APK_STATIC meson samurai pkgconf xz expat-dev expat-static libffi-dev wayland-protocols \
        && tar -xJf wayland.tar.xz && cd wayland-$wv \
        && meson setup build --prefix=/opt/wl --default-library=static -Ddocumentation=false -Dtests=false \
             -Ddtd_validation=false -Dscanner=true >/dev/null \
        && ninja -C build install >/dev/null && cd /w \
        && tar -xzf src.tar.gz && cd wl-clipboard-$version && export PATH=/opt/wl/bin:\$PATH \
        && PKG_CONFIG_PATH=/opt/wl/lib/pkgconfig:/opt/wl/share/pkgconfig LDFLAGS=-static meson setup build --prefer-static --default-library=static \
        && ninja -C build \
        && mkdir -p /w/$d/bin && cp build/src/wl-copy build/src/wl-paste /w/$d/bin/ && strip /w/$d/bin/*"
    static_only "$work/$d/bin/wl-copy" "$work/$d/bin/wl-paste"
    "$work/$d/bin/wl-copy" --version | grep -q "$version" || die "wl-copy does not report $version"
    provenance "$d" "wl-clipboard $version (github.com/bugaevc/wl-clipboard tag v$version, sha256 $(input wl-clipboard "$version")); static, libwayland-client $wv built static; Alpine 3.20 (musl)"
    pack "$d" ;;
xsel)
    source_of xsel "$version" "https://github.com/kfish/xsel/archive/refs/tags/$version.tar.gz" "$work/src.tar.gz"
    d="xsel-$version-linux-$arch"
    alpine "apk add -q $APK_STATIC libx11-dev libx11-static libxcb-dev libxcb-static libxau-dev libxdmcp-dev pkgconf autoconf automake \
        && tar -xzf src.tar.gz && cd xsel-$version && autoreconf -fi >/dev/null 2>&1 \
        && ./configure -q --prefix=/usr LDFLAGS=-static LIBS='-lX11 -lxcb -lXau -lXdmcp' >/dev/null \
        && make -s -j\$(nproc) CFLAGS='-O2 -Wno-error' >/dev/null \
        && mkdir -p /w/$d/bin && cp xsel /w/$d/bin/ && strip /w/$d/bin/xsel"
    static_only "$work/$d/bin/xsel"
    "$work/$d/bin/xsel" --version 2>&1 | grep -q "$version" || die "xsel does not report $version"
    provenance "$d" "xsel $version (github.com/kfish/xsel, sha256 $(input xsel "$version")); static (libX11, xcb); Alpine 3.20 (musl)"
    pack "$d" ;;
qemu-system)
    # qemu's system emulators for x86_64 and aarch64 guests, static (musl),
    # with user-mode networking (libslirp, built static here): what `luban
    # try` boots a VM with and gives it a network -- or only a proxy -- with.
    # Firmware (SeaBIOS, EDK II) in share/qemu, decompressed.
    # <upstream>-rN: this index's Nth build of it. r1: the prefix is /usr --
    # qemu relocates its data directory only under a prefix it can strip
    # (`/` is not one), and r0 looked for its ROMs in /share/qemu.
    v="${version%%-r[0-9]*}"
    source_of qemu "$v" "https://download.qemu.org/qemu-$v.tar.xz" "$work/qemu.tar.xz"
    sv="$(awk '$1 == "libslirp" { print $2 }' "$here/inputs.txt")"
    source_of libslirp "$sv" "https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v$sv/libslirp-v$sv.tar.gz" "$work/slirp.tar.gz"
    # libfdt (the aarch64 virt machine's device tree), as qemu's own subproject:
    # its release tarball leaves dtc to git (dtc.wrap: v1.6.1), and no distro
    # ships libfdt.a.
    dv="$(awk '$1 == "dtc" { print $2 }' "$here/inputs.txt")"
    source_of dtc "$dv" "https://mirrors.edge.kernel.org/pub/software/utils/dtc/dtc-$dv.tar.xz" "$work/dtc.tar.xz"
    d="qemu-system-$version-linux-$arch"
    alpine "apk add -q $APK_STATIC python3 py3-setuptools meson samurai pkgconf perl bash flex bison xz bzip2 \
            glib-dev glib-static pixman-dev pixman-static zlib-dev zlib-static libffi-dev pcre2-dev gettext-static \
            gettext-dev util-linux-dev util-linux-static \
        && tar -xzf slirp.tar.gz && cd libslirp-v$sv \
        && meson setup build --prefix=/opt/slirp --default-library=static >/dev/null && ninja -C build install >/dev/null \
        && cd /w && tar -xJf qemu.tar.xz && tar -xJf dtc.tar.xz && mv dtc-$dv qemu-$v/subprojects/dtc \
        && mkdir qb && cd qb \
        && PKG_CONFIG_PATH=/opt/slirp/lib/pkgconfig ../qemu-$v/configure --static --prefix=/usr \
             --target-list=x86_64-softmmu,aarch64-softmmu --enable-slirp --enable-fdt=internal \
             --disable-docs --disable-tools --disable-guest-agent --disable-user --disable-linux-user --disable-bsd-user \
             --disable-vnc --disable-sdl --disable-gtk --disable-curses --disable-spice --disable-opengl \
             --disable-virglrenderer --disable-libssh --disable-curl --disable-gnutls --disable-nettle --disable-gcrypt \
             --disable-libusb --disable-usb-redir --disable-smartcard --disable-xkbcommon --disable-dbus-display \
             --disable-linux-io-uring --disable-libudev --disable-zstd --disable-pa --disable-alsa --disable-jack \
             --disable-oss --disable-pipewire --disable-sndio --audio-drv-list= --disable-capstone --disable-libdaxctl \
             --disable-blkio --disable-brlapi --disable-vde --disable-libnfs --disable-rbd --disable-glusterfs \
             --disable-libiscsi --disable-seccomp --disable-cap-ng --disable-attr --disable-selinux \
             --disable-bzip2 --disable-lzo --disable-snappy --disable-numa --disable-linux-aio --disable-libpmem \
             --disable-fuse --disable-lzfse --disable-libkeyutils > /w/configure.log 2>&1 \
        && make -j\$(nproc) > /w/make.log 2>&1 && make install DESTDIR=/w/stage > /w/install.log 2>&1 \
        && mkdir -p /w/$d/bin /w/$d/share && cp /w/stage/usr/bin/qemu-system-x86_64 /w/stage/usr/bin/qemu-system-aarch64 /w/$d/bin/ \
        && strip /w/$d/bin/* && cp -a /w/stage/usr/share/qemu /w/$d/share/ \
        && find /w/$d/share/qemu -name '*.bz2' -exec bunzip2 -f {} +" \
      || { for f in configure make install; do [[ -f "$work/$f.log" ]] && { log "--- $f.log"; tail -40 "$work/$f.log" >&2; }; done; die "qemu build failed"; }
    static_only "$work/$d/bin/qemu-system-x86_64" "$work/$d/bin/qemu-system-aarch64"
    for q in x86_64 aarch64; do
        "$work/$d/bin/qemu-system-$q" --version | grep -q "version $v" || die "qemu-system-$q does not report $v"
        "$work/$d/bin/qemu-system-$q" -M none -netdev help | grep -qx user || die "qemu-system-$q has no user networking"
        # Its data directory is found beside it, wherever the payload is: a
        # ROM only share/qemu has, from a copy of the payload elsewhere.
        "$work/$d/bin/qemu-system-$q" -M none -L help | while read -r p; do [[ -d "$p" ]] && realpath "$p"; done \
            | grep -qx "$(realpath "$work/$d/share/qemu")" \
            || die "qemu-system-$q does not find its data beside it: $("$work/$d/bin/qemu-system-$q" -M none -L help | tr '\n' ' ')"
    done
    [[ -f "$work/$d/share/qemu/bios-256k.bin" && -f "$work/$d/share/qemu/edk2-aarch64-code.fd" && -f "$work/$d/share/qemu/edk2-x86_64-code.fd" ]] \
        || die "the firmware is not in share/qemu"
    provenance "$d" "qemu $v (download.qemu.org, sha256 $(input qemu "$v")) system emulators for x86_64 and aarch64, static (musl, Alpine 3.20), user networking from libslirp $sv and libfdt from dtc $dv, built static; firmware decompressed in share/qemu"
    pack "$d" ;;
edk2-firmware)
    # What qemu ships in pc-bios/ at tag v<version>, decompressed: firmware
    # is the same file whichever machine runs the emulator.
    d="edk2-firmware-$version"
    mkdir -p "$work/$d/share/edk2"
    for f in edk2-x86_64-code.fd edk2-aarch64-code.fd; do
        source_of "$f.bz2" "$version" "https://raw.githubusercontent.com/qemu/qemu/v$version/pc-bios/$f.bz2" "$work/$f.bz2"
        bunzip2 -c "$work/$f.bz2" > "$work/$d/share/edk2/$f"
    done
    source_of edk2-licenses.txt "$version" "https://raw.githubusercontent.com/qemu/qemu/v$version/pc-bios/edk2-licenses.txt" "$work/$d/share/edk2/edk2-licenses.txt"
    for f in edk2-x86_64-code.fd edk2-aarch64-code.fd; do
        [[ "$(stat -c %s "$work/$d/share/edk2/$f")" -ge $((2 * 1024 * 1024)) ]] || die "$f is too small to be firmware"
    done
    provenance "$d" "UEFI firmware (EDK II) as qemu $version ships it in pc-bios/, decompressed; digests of the .bz2 inputs in tools/res/inputs.txt"
    pack "$d" ;;
bash|coreutils|openssl|binutils)
    v="${version%%-r[0-9]*}"   # <upstream>-rN: this index's Nth build of it; the payload keeps the name
    case "$what" in
        bash)      url="https://ftpmirror.gnu.org/gnu/bash/bash-$v.tar.gz"; d="bash-$version" ;;
        coreutils) url="https://ftpmirror.gnu.org/gnu/coreutils/coreutils-$v.tar.xz"; d="coreutils-$version" ;;
        openssl)   url="https://github.com/openssl/openssl/releases/download/openssl-$v/openssl-$v.tar.gz"; d="openssl-$version-linux-$arch" ;;
        binutils)  url="https://ftpmirror.gnu.org/gnu/binutils/binutils-$v.tar.xz"; d="binutils-$version-linux-$arch" ;;
    esac
    src="src.tar.${url##*.tar.}"
    source_of "$what" "$v" "$url" "$work/$src"
    case "$what" in
        bash) steps="cd bash-$v && ./configure -q --prefix=/usr --without-bash-malloc >/dev/null \
                && make -s -j\$(nproc) >/dev/null && mkdir -p /w/$d/bin && cp bash bashbug /w/$d/bin/ && strip /w/$d/bin/bash" ;;
        coreutils) steps="cd coreutils-$v && FORCE_UNSAFE_CONFIGURE=1 ./configure -q --prefix=/w/$d --disable-nls \
                --without-selinux --without-openssl --without-libgmp --disable-acl --disable-xattr --disable-libcap >/dev/null \
                && make -s -j\$(nproc) >/dev/null && make -s install >/dev/null && rm -rf /w/$d/share \
                && strip /w/$d/bin/* /w/$d/libexec/coreutils/*.so" ;;
        openssl) target=linux-x86_64; [[ "$arch" == aarch64 ]] && target=linux-aarch64
            steps="cd openssl-$v && ./Configure $target --prefix=/w/$d --openssldir=/w/$d/ssl --libdir=lib64 shared no-tests >/dev/null \
                && make -s -j\$(nproc) >/dev/null && make -s install_sw install_ssldirs >/dev/null" ;;
        binutils) steps="mkdir build && cd build && ../binutils-$v/configure -q --with-pkgversion=xlings-fromsource \
                --prefix=/w/$d --enable-plugins --enable-new-dtags --disable-nls --disable-gprofng --disable-werror \
                --enable-gold --enable-ld=default >/dev/null && make -s -j\$(nproc) >/dev/null && make -s install >/dev/null \
                && strip /w/$d/bin/* 2>/dev/null || true" ;;
    esac
    debian "apt-get -qq update && apt-get -qq install -y build-essential bison texinfo file xz-utils perl >/dev/null \
        && tar -xf $src && $steps"
    GLIBC_ELFS="$(find "$work/$d" -type f -exec sh -c 'file -b "$1" | grep -q "^ELF.*dynamically linked" && echo "$1"' _ {} \;)"
    [[ -n "$GLIBC_ELFS" ]] || die "$what: no dynamically linked ELF in the payload"
    case "$what" in
        openssl)  glibc_only libssl.so.3 libcrypto.so.3 ;;
        binutils) glibc_only libbfd-$v.so libopcodes-$v.so libctf.so.0 libctf-nobfd.so.0 libsframe.so.1 libz.so.1 libstdc++.so.6 libgcc_s.so.1 ;;
        *)        glibc_only ;;
    esac
    case "$what" in
        bash)      "$work/$d/bin/bash" -c 'echo $BASH_VERSION' | grep -q "^$v" || die "bash does not report $version" ;;
        coreutils) "$work/$d/bin/ls" --version | grep -q "$v" || die "ls does not report $version" ;;
        openssl)   LD_LIBRARY_PATH="$work/$d/lib64" "$work/$d/bin/openssl" version | grep -q "OpenSSL $v" || die "openssl does not report $version" ;;
        binutils)  "$work/$d/bin/ld" --version | grep -q "$v" || die "ld does not report $version" ;;
    esac
    provenance "$d" "$what $version (sha256 $(input "$what" "$v")); built in Debian 12 against its glibc (an xlings install patches it onto the index's glibc)"
    pack "$d" ;;
gcc)
    # As x86_64's (fromsource:gcc): a prebuilt compiler builds the new one
    # with the same configure, against a sysroot xlings itself makes from the
    # index (glibc + linux-headers). The stage-0 compiler is the pinned
    # factory's; what ships is gcc built by it, verified below.
    source_of gcc "$version" "https://ftpmirror.gnu.org/gnu/gcc/gcc-$version/gcc-$version.tar.xz" "$work/gcc.tar.xz"
    xl="xlings-$XLINGS_CLIENT-linux-$arch.tar.gz"
    curl -fsSL --retry 3 -o "$work/$xl" "https://github.com/openxlings/xlings/releases/download/v$XLINGS_CLIENT/$xl"
    curl -fsSL --retry 3 -o "$work/$xl.sha256" "https://github.com/openxlings/xlings/releases/download/v$XLINGS_CLIENT/$xl.sha256"
    (cd "$work" && sha256sum -c "$xl.sha256" >/dev/null) || die "the xlings client does not match its digest"
    glibc_v="$(awk '$1 == "gcc-sysroot-glibc" { print $2 }' "$here/inputs.txt")"
    headers_v="$(awk '$1 == "gcc-sysroot-linux-headers" { print $2 }' "$here/inputs.txt")"
    d="gcc-$version-linux-$arch"
    triple="$arch-linux-gnu"
    debian "apt-get -qq update && apt-get -qq install -y build-essential flex bison texinfo xz-utils bzip2 curl wget ca-certificates file python3 >/dev/null \
        && mkdir -p /w/xl && tar -xzf $xl -C /w/xl && export XLINGS_HOME=/w/xh \
        && (cd /w/xl/*/ && ./bin/xlings self install </dev/null >/w/xlings-install.log 2>&1) \
        && /w/xh/bin/xlings install -y glibc@$glibc_v linux-headers@$headers_v </dev/null >/w/sysroot.log 2>&1 \
        && S=\$(dirname \$(dirname \$(ls /w/xh/subos/*/lib/crt1.o | head -1))) && echo \$S > /w/sysroot \
        && test -f \$S/usr/include/stdio.h && test -d \$S/usr/include/linux \
        && { [ -e \$S/lib64 ] || ln -s lib \$S/lib64; } && mkdir -p \$S/usr \
        && { [ -e \$S/usr/lib ] || ln -s ../lib \$S/usr/lib; } && { [ -e \$S/usr/lib64 ] || ln -s ../lib \$S/usr/lib64; } \
        && tar -xJf gcc.tar.xz && cd gcc-$version \
        && sed -i 's/--no-verbose/ /; s#ftp://gcc.gnu.org#https://gcc.gnu.org#' contrib/download_prerequisites \
        && ./contrib/download_prerequisites >/w/prereq.log 2>&1 \
        && mkdir /w/build && cd /w/build \
        && /w/gcc-$version/configure --with-pkgversion=xlings-fromsource \
             --with-build-sysroot=\$S --with-sysroot=\$S --prefix=/w/$d \
             --enable-languages=c,c++ --disable-multilib --disable-bootstrap \
             --disable-werror --disable-lto --enable-threads=posix \
             --build=$triple --host=$triple --target=$triple --enable-libsanitizer >/w/configure.log 2>&1 \
        && make -j\$(nproc) >/w/make.log 2>&1 && make install-strip >/w/install.log 2>&1 \
        && cd /w && printf '#include <stdio.h>\nint main(void){puts(\"c ok\");return 0;}\n' > t.c \
        && printf 'import std;\nint main(){ std::println(\"c++23 ok {}\", std::ranges::fold_left(std::views::iota(1,5), 0, std::plus{})); }\n' > t.cpp \
        && L=\$(ls \$S/lib/ld-linux-*.so.* | head -1) \
        && /w/$d/bin/gcc --sysroot=\$S -Wl,--dynamic-linker=\$L -Wl,-rpath,\$S/lib:/w/$d/lib64 t.c -o tc && ./tc \
        && /w/$d/bin/g++ --sysroot=\$S -std=c++23 -fmodules -fsearch-include-path -c bits/std.cc -o std.o \
        && /w/$d/bin/g++ --sysroot=\$S -std=c++23 -fmodules t.cpp std.o -Wl,--dynamic-linker=\$L -Wl,-rpath,\$S/lib:/w/$d/lib64 -o tcpp \
        && ./tcpp | tee /w/cxx.out" \
      || { for f in xlings-install sysroot prereq configure make install; do
               [[ -f "$work/$f.log" ]] && { log "--- $f.log"; tail -40 "$work/$f.log" >&2; }; done; die "gcc build failed"; }
    grep -q "c++23 ok 10" "$work/cxx.out" || die "the C++23 check did not print what it should"
    "$work/$d/bin/gcc" --version | head -1 | grep -q "$version" || die "gcc does not report $version"
    [[ -d "$work/$d/lib64" && -f "$work/$d/lib64/libstdc++.so.6" ]] || die "no lib64/libstdc++.so.6"
    GLIBC_ELFS="$(find "$work/$d/bin" "$work/$d/libexec" -type f -exec sh -c 'file -b "$1" | grep -q "^ELF.*dynamically linked" && echo "$1"' _ {} \;)"
    glibc_only libstdc++.so.6 libgcc_s.so.1 libzstd.so.1 libz.so.1
    provenance "$d" "gcc $version (ftpmirror.gnu.org, sha256 $(input gcc "$version")) configured as fromsource:gcc (c,c++; no multilib, no bootstrap, no LTO; libsanitizer), $triple, against a sysroot of xim:glibc@$glibc_v + xim:linux-headers@$headers_v made by xlings $XLINGS_CLIENT; stage 0 is Debian 12's gcc; a C program and a C++23 program using import std built and ran"
    pack "$d" ;;
*)
    die "unknown resource: $what" ;;
esac
