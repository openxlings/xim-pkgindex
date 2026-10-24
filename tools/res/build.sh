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
#   virtiofsd     a static virtiofsd (musl; libseccomp, libcap-ng): a Luban machine's files
#   e2fsprogs     static mke2fs & co (musl)
#   curl          a static curl (musl; TLS, socks5h)
#   proot         a static proot (musl)
#   musl          the musl libc payload, relocatable (loader links to libc.so)
#   make          a static GNU make (musl)
#   git           a static git (musl; https through libcurl), runtime prefix
#   vim           a static vim (musl) and its runtime files
#   tmux          a static tmux (musl; libevent, ncurses) and the terminfo it needs
#   htop          a static htop (musl; ncurses) and the terminfo it needs
#   procps-ng     static ps, top, free, pgrep, pkill, pidof, uptime, vmstat, watch (musl; ncurses) and terminfo
#   sudo          a static sudo and visudo (musl; no PAM, sudoers built in)
#   wl-clipboard  static wl-copy / wl-paste (musl; libwayland built static)
#   xsel          a static xsel (musl; libX11/xcb static)
#   edk2-firmware the UEFI firmware qemu ships, decompressed (no build)
#   qemu-system   static qemu-system-x86_64 and -aarch64 (musl; user networking)
#   qemu-system-gl qemu-system-x86_64 with OpenGL (virglrenderer, egl-headless; glibc, dynamic)
#   labwc-desktop the labwc desktop session, relocatable (musl loader and libraries inside)
#   foot          luban:foot, a terminal, as a component tree (Alpine 3.24; bundle below)
#   xwayland      luban:xwayland, X11 programs on Wayland, built without glamor and GLX
#   labwc         luban:labwc, the labwc desktop, on a wlroots built with pixman alone
#   audio         luban:audio: PipeWire, WirePlumber, pipewire-pulse and the luban sink
#   qt-runtime    luban:qt-runtime, the Qt the Qt desktops share (Qt 6, mesa, their libraries; no programs)
#   lxqt          luban:lxqt, LXQt on luban:labwc, its libraries beyond the Qt runtime's
#   kde           luban:kde, KDE Plasma nested in luban:labwc, all it brings beyond the Qt runtime (preview)
#   falkon        luban:falkon, the browser of every Luban desktop (Falkon on QtWebEngine), on the Qt runtime
#   audacious     luban:audacious, the desktops' music player (Audacious), on the Qt runtime
#   bash          bash on glibc (the shape x86_64's is)
#   coreutils     coreutils on glibc
#   openssl       openssl on glibc, lib64
#   binutils      binutils on glibc
#   gcc           gcc on glibc, configured as x86_64's (fromsource:gcc),
#                 against a sysroot xlings makes (glibc + linux-headers)
#
# Data, the same on every architecture (built once, <name>-<version>.tar.gz):
#   terminfo        the terminal descriptions (ncurses' terminfo.src, compiled)
#   adwaita-cursors GNOME's Adwaita cursor theme, and the default theme naming it
#   luban-fonts     the fonts the Luban OS window ships with
#   sample-music    luban:sample-music, a piece to play (the Open Goldberg Variations' Aria, CC0)
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
# Luban's resources, apart from the generic ones (xlings design 2026-10-20
# WuXian §16.5): its desktop components, their bundling and the machine kernel.
luban="$here/luban"
arch="$(uname -m)"; [[ "$arch" == arm64 ]] && arch=aarch64
work="$(mktemp -d)"; trap 'rm -rf "$work" 2>/dev/null || sudo rm -rf "$work"' EXIT
log() { printf '[res] %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }

# The factory: pinned by digest (a tag moves; a digest does not).
ALPINE="alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc"
DEBIAN="debian:12@sha256:2c037a04925515fdd6ea85ea14a682d0e79931f5e9f5d07b6dbfc6ba12f9e858"
# The desktop components' (bundle below): one Alpine for all of them, so their
# trees agree with each other and with the Qt runtime.
ALPINE_DESKTOP="alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6"
# Rust's own toolchain on Alpine (what is built in Rust; its musl target links static).
RUST_ALPINE="rust:1.91-alpine3.22@sha256:8efbfb788786eeb127adc581394349c5fb567712156e0f8c2e499acadbc23756"
# The Qt runtime the Qt desktops are built on (luban:qt-runtime): Alpine
# 3.24's Qt at this index's build of it. A Qt desktop names it exactly, and
# its build checks the Qt it links is this one.
QT_RUNTIME="6.11.1-r2"
QT_RUNTIME_APKS="qt6-qtbase qt6-qtbase-x11 qt6-qtbase-wayland qt6-qtwayland qt6-qtsvg qt6-qtdeclarative mesa-dri-gallium"
# The Qt runtime's tree (tools/res/luban/qt-runtime/tree.sh <dir>, in the Alpine
# container): the Qt libraries, their plugins and QML modules, every library
# they link and the musl loader.
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

input_version() {   # name -> the one version of it inputs.txt records
    local v; v="$(awk -v n="$1" '$1 == n { print $2 }' "$here/inputs.txt")"
    [[ -n "$v" && "$(wc -l <<< "$v")" -eq 1 ]] || die "tools/res/inputs.txt needs exactly one $1 (has: ${v:-none})"
    printf '%s' "$v"
}

source_of() {   # name version url file
    fetch "$3" "$(input "$1" "$2")" "$4"
}

# A command in a container, $work mounted at /w; what it makes is ours after.
# The files go back to the runner's user however the build ends, and the
# build's status is the container's: a failed `a && b` chain fails it.
alpine() { docker run --rm -v "$work:/w" -w /w "${ALPINE_IMAGE:-$ALPINE}" sh -euc "trap 'chown -R $(id -u):$(id -g) /w' EXIT; $1"; }
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

# A data resource: the same bytes for every architecture, so one archive
# without an architecture in its name, its one directory <name>-<version>.
pack_data() {   # directory under $work -> $out/<name>-<version>.tar.gz
    local file="$out/$what-$version.tar.gz"
    tar --owner=0 --group=0 --numeric-owner --hard-dereference --sort=name --mtime=@0 -czf "$file" -C "$work" "$1"
    seal "$file"
    python3 -c 'import sys, tarfile; sys.exit(any(m.islnk() for m in tarfile.open(sys.argv[1])))' "$file" \
        || die "$file holds a hard link"
}

provenance() {  # directory, text
    printf '%s\n' "$2" > "$work/$1/README.provenance"
}

# A Luban desktop component as one relocatable tree (xlings: 2026-10-18 Luban
# OS distribution design §4.6, §13.5): Alpine's builds of its programs, with
# the musl loader and every library they link, private to it:
#
#   bin/<program>                 runs the loader on the program (bundle/run.in)
#   libexec/<name>/bin/<program>  the program; no ELF names a loader (no-interp.py)
#   libexec/<name>/lib/           its libraries and the loader
#   libexec/<name>/env            what the programs read, sourced by bin/<program>
#   etc/, share/                  tools/res/<name>: defaults, sessions, checks
#
# The tree is the package's own -- a root projects libexec/<name>/ whole and
# never merges it with another package's -- so it runs on a glibc root, a musl
# one, or a host. Its own directory: libexec/<name>, never libexec/lib.
#
#   bundle <name> <dir> "<programs, absolute in the container>" "<shell run first>" ["<more libraries' files>"]
bundle() {
    local name="$1" d="$2" progs="$3" prep="$4" more="${5:-}" p loader="ld-musl-$arch.so.1"
    cp "$luban/bundle/strip-rpath.sh" "$work/"
    ALPINE_IMAGE="$ALPINE_DESKTOP" alpine "$prep \
        && apk info -v 2>/dev/null | sort > /w/installed \
        && mkdir -p /w/$d/bin /w/$d/libexec/$name/bin /w/$d/libexec/$name/lib \
        && for p in $progs; do cp -L \$p /w/$d/libexec/$name/bin/; done \
        && for f in $progs $more; do ldd \$f | awk '/=>/ { print \$3 }'; done | sort -u > /w/libs \
        && while read -r l; do cp -L \"\$l\" /w/$d/libexec/$name/lib/; done < /w/libs \
        && cp -L /lib/$loader /w/$d/libexec/$name/lib/ \
        && apk add -q patchelf && sh /w/strip-rpath.sh /w/$d/libexec/$name"
    [[ ! -e "$work/$d/lib" ]] || die "a lib/ in the tree: a root would link it into its /usr/lib"
    cp -r "$luban/$name/." "$work/$d/"
    mv "$work/$d/env" "$work/$d/libexec/$name/env"
    n="$(python3 "$luban/bundle/no-interp.py" "$work/$d/libexec/$name/bin")"
    [[ "$n" -ge 1 ]] || die "PT_INTERP left in place ($n changed)"
    # A library may be a program too (libcap.so.2 prints its version): it
    # names no loader either -- a Luban system refuses an ELF whose loader is
    # outside its checked closure.
    python3 "$luban/bundle/no-interp.py" "$work/$d/libexec/$name/lib" >/dev/null
    for p in $progs; do
        p="$(basename "$p")"
        sed -e "s/@NAME@/$name/g" -e "s/@PROG@/$p/g" -e "s/@LOADER@/$loader/g" "$luban/bundle/run.in" > "$work/$d/bin/$p"
        chmod 755 "$work/$d/bin/$p"
    done
    mkdir -p "$work/$d/share/licenses"
}

# The Alpine package a bundle's version is the build of, checked.
bundle_upstream() {  # alpine package, version
    grep -q "^$1-$2-r" "$work/installed" || die "Alpine 3.24's $1 is not $2: $(grep "^$1-[0-9]" "$work/installed")"
}

# A headless session of a component in Debian -- a root that is not Alpine's,
# with nothing of the tree's system: its compositor runs and a client draws.
headless() {  # dir, shell (in /w/<dir>, with XDG_RUNTIME_DIR and WAYLAND_DISPLAY)
    debian "cd /w/$1 && export HOME=/tmp/home XDG_RUNTIME_DIR=/tmp/rt WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 WAYLAND_DISPLAY=wayland-0 \
        && mkdir -p -m 700 /tmp/rt /tmp/home && $2" \
      || { log "--- session.log"; tail -40 "$work/session.log" >&2 || true; die "the session did not run"; }
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
    # <kernel.org version>[-r<N>]: a revision is the same source with a changed
    # kernel-virt.config.
    kv="${version%%-r*}"
    sums="$work/sha256sums.asc"
    curl -fsSL --retry 3 -o "$sums" "https://cdn.kernel.org/pub/linux/kernel/v${kv%%.*}.x/sha256sums.asc"
    sha="$(grep " linux-$kv.tar.xz\$" "$sums" | cut -d' ' -f1)"
    [[ -n "$sha" ]] || die "kernel.org lists no linux-$kv.tar.xz"
    fetch "https://cdn.kernel.org/pub/linux/kernel/v${kv%%.*}.x/linux-$kv.tar.xz" "$sha" "$work/linux.tar.xz"
    cp "$luban/kernel-virt.config" "$work/"
    karch=x86; image=arch/x86/boot/bzImage
    [[ "$arch" == aarch64 ]] && { karch=arm64; image=arch/arm64/boot/Image; }
    debian "apt-get -qq update && apt-get -qq install -y build-essential flex bison bc libelf-dev libssl-dev xz-utils kmod cpio >/dev/null \
        && tar -xJf linux.tar.xz && cd linux-$kv \
        && make -s ARCH=$karch defconfig && make -s ARCH=$karch kvm_guest.config \
        && scripts/kconfig/merge_config.sh -m -O . .config /w/kernel-virt.config >/dev/null \
        && make -s ARCH=$karch olddefconfig \
        && for opt in VIRTIO_BLK VIRTIO_NET VIRTIO_PCI VIRTIO_CONSOLE EXT4_FS BLK_DEV_INITRD RD_GZIP DEVTMPFS DEVTMPFS_MOUNT EFI_STUB VIRTIO_FS UDMABUF DRM DRM_VIRTIO_GPU; do \
             grep -q \"^CONFIG_\$opt=y\" .config || { echo \"CONFIG_\$opt is not built in\"; exit 1; }; done \
        && make -s ARCH=$karch -j\$(nproc) LOCALVERSION=-virt $(basename "$image") \
        && make -s ARCH=$karch LOCALVERSION=-virt kernelrelease > /w/release"
    src="$work/linux-$kv"; release="$(cat "$work/release")"
    root="$work/linux-kernel-virt-$version"
    mkdir -p "$root/lib/modules/$release"
    cp "$src/$image" "$root/lib/modules/$release/vmlinuz"
    cp "$src/.config" "$root/lib/modules/$release/config"
    printf 'linux %s (kernel.org, sha256 %s), %s defconfig + kvm_guest.config + kernel-virt.config (%s); built in Debian 12; no modules: what a virtual machine needs is built in\n' \
        "$kv" "$sha" "$karch" "$version" > "$root/README.provenance"
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
virtiofsd)
    # A Luban machine's files over virtio-fs (xlings design 2026-10-21 §4):
    # unprivileged, one a share, started by the machine's supervisor. Rust's
    # own toolchain: its musl target links static, Alpine's rust does not.
    source_of virtiofsd "$version" "https://gitlab.com/virtio-fs/virtiofsd/-/archive/v$version/virtiofsd-v$version.tar.gz" "$work/src.tar.gz"
    d="virtiofsd-$version-linux-$arch"
    ALPINE_IMAGE="$RUST_ALPINE" alpine "apk add -q musl-dev libseccomp-dev libseccomp-static libcap-ng-dev libcap-ng-static \
        && tar -xzf src.tar.gz && cd virtiofsd-v$version \
        && LIBSECCOMP_LINK_TYPE=static LIBSECCOMP_LIB_PATH=/usr/lib LIBCAPNG_LINK_TYPE=static LIBCAPNG_LIB_PATH=/usr/lib \
             CARGO_HOME=/w/cargo cargo build -q --release --locked --target $arch-unknown-linux-musl \
        && mkdir -p /w/$d/bin && cp target/$arch-unknown-linux-musl/release/virtiofsd /w/$d/bin/ && strip /w/$d/bin/virtiofsd"
    static_only "$work/$d/bin/virtiofsd"
    "$work/$d/bin/virtiofsd" --version | grep -q "$version" || die "virtiofsd does not report $version"
    provenance "$d" "virtiofsd $version: https://gitlab.com/virtio-fs/virtiofsd tag v$version; cargo build --release --target $arch-unknown-linux-musl in rust:1.91-alpine3.22 (static)"
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
tmux|htop)
    # A terminal program: static (ncursesw, and libevent for tmux), with the
    # terminfo entries of the terminals it meets (a root may have none):
    # share/terminfo, which the recipe names in TERMINFO_DIRS.
    if [[ "$what" == tmux ]]; then
        source_of tmux "$version" "https://github.com/tmux/tmux/releases/download/$version/tmux-$version.tar.gz" "$work/src.tar.gz"
        unpack="tar -xzf src.tar.gz"; deps="libevent-dev libevent-static bison"
        build="./configure -q --prefix=/usr --enable-static --disable-utf8proc >/dev/null"
    else
        source_of htop "$version" "https://github.com/htop-dev/htop/releases/download/$version/htop-$version.tar.xz" "$work/src.tar.xz"
        unpack="tar -xJf src.tar.xz"; deps="xz"
        build="./configure -q --prefix=/usr --enable-static --enable-unicode >/dev/null"
    fi
    d="$what-$version-linux-$arch"
    terms="xterm xterm-256color screen screen-256color tmux tmux-256color foot foot-direct linux vt100 vt220 dumb"
    alpine "apk add -q $APK_STATIC $deps ncurses-dev ncurses-static ncurses-terminfo-base ncurses-terminfo \
        && $unpack && cd $what-$version \
        && $build LDFLAGS=-static \
        && make -s -j\$(nproc) >/dev/null \
        && mkdir -p /w/$d/bin /w/$d/share/terminfo && cp $what /w/$d/bin/ && strip /w/$d/bin/$what \
        && for t in $terms; do f=\$(find /usr/share/terminfo /etc/terminfo -name \"\$t\" 2>/dev/null | head -1); \
             [ -n \"\$f\" ] || { echo \"no terminfo for \$t\" >&2; exit 1; }; \
             mkdir -p /w/$d/share/terminfo/\$(basename \$(dirname \$f)); cp \"\$f\" /w/$d/share/terminfo/\$(basename \$(dirname \$f))/; done"
    static_only "$work/$d/bin/$what"
    "$work/$d/bin/$what" -V 2>&1 | grep -q "$version" || die "$what does not report $version"
    [[ -f "$work/$d/share/terminfo/x/xterm-256color" ]] || die "no xterm-256color terminfo"
    provenance "$d" "$what $version (github.com, sha256 $(input $what "$version")); static (ncursesw$([[ $what == tmux ]] && echo ', libevent')), terminfo for: $terms; Alpine 3.20 (musl)"
    pack "$d" ;;
procps-ng)
    # The process tools a system's userland expects in full (xlings design
    # 2026-10-19 §20): BusyBox's ps has no -C, -o of most fields, no top
    # sort keys. Static like htop and tmux (musl; ncursesw for top and watch)
    # so it needs nothing of the glibc a root has; the terminfo of the
    # terminals it meets in share/terminfo, which the recipe names.
    source_of procps-ng "$version" "https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-$version.tar.xz/download" "$work/src.tar.xz"
    d="procps-ng-$version-linux-$arch"
    progs="ps top free pgrep pkill pidof uptime vmstat watch"
    terms="xterm xterm-256color screen screen-256color tmux tmux-256color foot foot-direct linux vt100 vt220 dumb"
    alpine "apk add -q $APK_STATIC xz ncurses-dev ncurses-static ncurses-terminfo-base ncurses-terminfo \
        && tar -xJf src.tar.xz && cd procps-ng-$version \
        && ./configure -q --prefix=/usr --disable-shared --enable-static --disable-nls --without-systemd \
             --without-elogind --disable-kill --disable-w --enable-watch8bit >/dev/null \
        && make -s -j\$(nproc) LDFLAGS=-all-static >/dev/null \
        && make -s install DESTDIR=/w/stage LDFLAGS=-all-static >/dev/null \
        && mkdir -p /w/$d/bin /w/$d/share/terminfo \
        && for p in $progs; do f=\$(ls /w/stage/usr/bin/\$p /w/stage/usr/sbin/\$p /w/stage/bin/\$p /w/stage/sbin/\$p 2>/dev/null | head -1); \
             [ -n \"\$f\" ] || { echo \"no \$p installed\" >&2; exit 1; }; cp \"\$f\" /w/$d/bin/; strip /w/$d/bin/\$p; done \
        && for t in $terms; do f=\$(find /usr/share/terminfo /etc/terminfo -name \"\$t\" 2>/dev/null | head -1); \
             [ -n \"\$f\" ] || { echo \"no terminfo for \$t\" >&2; exit 1; }; \
             mkdir -p /w/$d/share/terminfo/\$(basename \$(dirname \$f)); cp \"\$f\" /w/$d/share/terminfo/\$(basename \$(dirname \$f))/; done"
    for p in $progs; do static_only "$work/$d/bin/$p"; done
    "$work/$d/bin/ps" -V 2>&1 | grep -q "procps-ng $version" || die "ps does not report $version"
    "$work/$d/bin/ps" -C ps -o pid= >/dev/null 2>&1 || "$work/$d/bin/ps" -o pid= -p 1 >/dev/null || die "ps cannot list a process"
    "$work/$d/bin/free" -h >/dev/null || die "free does not run"
    TERMINFO_DIRS="$work/$d/share/terminfo" TERM=xterm-256color "$work/$d/bin/top" -b -n 1 >/dev/null || die "top -b does not run"
    [[ -f "$work/$d/share/terminfo/x/xterm-256color" ]] || die "no xterm-256color terminfo"
    provenance "$d" "procps-ng $version (sourceforge.net/projects/procps-ng, sha256 $(input procps-ng "$version")): $progs; static (ncursesw), terminfo for: $terms; Alpine 3.20 (musl)"
    pack "$d" ;;
sudo)
    # sudo for a Luban system (xlings design 2026-10-20 §4.5): static (musl),
    # no PAM -- it reads the system's /etc/shadow -- its sudoers policy built
    # in (no plugin to load), no mail, no log server, no noexec library.
    # The recipe makes bin/sudo setuid; a machine makes it root's at boot.
    source_of sudo "$version" "https://www.sudo.ws/dist/sudo-$version.tar.gz" "$work/src.tar.gz"
    d="sudo-$version-linux-$arch"
    alpine "apk add -q $APK_STATIC \
        && tar -xzf src.tar.gz && cd sudo-$version \
        && ./configure -q --prefix=/usr --sysconfdir=/etc --localstatedir=/var --runstatedir=/run \
             --without-pam --disable-shared --enable-static-sudoers --disable-nls --without-sendmail \
             --disable-root-mailer --with-rundir=/run/sudo --with-vardir=/var/db/sudo --with-env-editor \
             --disable-log-server --disable-log-client --without-ldap --without-noexec --disable-intercept \
             --with-timeout=15 --without-lecture --enable-tmpfiles.d=no --disable-pie >/dev/null \
        && make -s -j\$(nproc) LDFLAGS=-all-static >/dev/null && make -s install DESTDIR=/w/stage LDFLAGS=-all-static >/dev/null \
        && mkdir -p /w/$d/bin /w/$d/sbin \
        && cp /w/stage/usr/bin/sudo /w/$d/bin/sudo && strip /w/$d/bin/sudo && ln -s sudo /w/$d/bin/sudoedit \
        && cp /w/stage/usr/sbin/visudo /w/$d/sbin/visudo && strip /w/$d/sbin/visudo"
    static_only "$work/$d/bin/sudo" "$work/$d/sbin/visudo"
    grep -aq "$version" "$work/$d/bin/sudo" || die "bin/sudo does not carry $version"
    printf 'root ALL=(ALL:ALL) ALL\n%%wheel ALL=(ALL:ALL) ALL\n' > "$work/sudoers.check"
    "$work/$d/sbin/visudo" -c -q -f "$work/sudoers.check" || die "visudo does not accept a plain sudoers"
    provenance "$d" "sudo $version (www.sudo.ws, sha256 $(input sudo "$version")): static (musl), no PAM (shadow), sudoers built in; Alpine 3.20"
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
    # (`/` is not one), and r0 looked for its ROMs in /share/qemu. r2: virtfs
    # (9p, libattr static): what `luban enter <n> --mode machine` shares the
    # environment's own tree and the home with.
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
            gettext-dev util-linux-dev util-linux-static attr-dev attr-static \
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
             --disable-libiscsi --disable-seccomp --disable-cap-ng --enable-attr --enable-virtfs --disable-selinux \
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
        # r2: 9p, so a Luban machine boots the environment itself (its tree and
        # the home shared with the guest) rather than a copy of it.
        "$work/$d/bin/qemu-system-$q" -M none -device help | grep -q '"virtio-9p-pci"' || die "qemu-system-$q has no virtio-9p"
        # Its data directory is found beside it, wherever the payload is: a
        # ROM only share/qemu has, from a copy of the payload elsewhere.
        "$work/$d/bin/qemu-system-$q" -M none -L help | while read -r p; do [[ -d "$p" ]] && realpath "$p"; done \
            | grep -qx "$(realpath "$work/$d/share/qemu")" \
            || die "qemu-system-$q does not find its data beside it: $("$work/$d/bin/qemu-system-$q" -M none -L help | tr '\n' ' ')"
    done
    [[ -f "$work/$d/share/qemu/bios-256k.bin" && -f "$work/$d/share/qemu/edk2-aarch64-code.fd" && -f "$work/$d/share/qemu/edk2-x86_64-code.fd" ]] \
        || die "the firmware is not in share/qemu"
    provenance "$d" "qemu $v (download.qemu.org, sha256 $(input qemu "$v")) system emulators for x86_64 and aarch64, static (musl, Alpine 3.20), user networking from libslirp $sv, 9p (virtfs, libattr) and libfdt from dtc $dv, built static; firmware decompressed in share/qemu"
    pack "$d" ;;
qemu-system-gl)
    # xim:qemu-system-gl: qemu-system-x86_64 that draws a Luban machine's
    # graphics on the host's GPU (xlings design 2026-10-20 WuXian §7.5):
    # virtio-gpu-gl-pci, virglrenderer, the egl-headless display on a render
    # node. Linked dynamically -- EGL and GBM load the host's driver -- against
    # Debian 12's glibc, which an install patches onto the index's (elfpatch);
    # every library it needs is a package the recipe names (xim:graphics for
    # EGL/GBM, glib, pixman, zlib, libepoxy, libdrm), except virglrenderer,
    # built here and carried in lib/. User networking (libslirp) and libfdt
    # static as in qemu-system; its firmware in share/qemu.
    v="${version%%-r[0-9]*}"
    source_of qemu "$v" "https://download.qemu.org/qemu-$v.tar.xz" "$work/qemu.tar.xz"
    sv="$(input_version libslirp)"
    source_of libslirp "$sv" "https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v$sv/libslirp-v$sv.tar.gz" "$work/slirp.tar.gz"
    dv="$(input_version dtc)"
    source_of dtc "$dv" "https://mirrors.edge.kernel.org/pub/software/utils/dtc/dtc-$dv.tar.xz" "$work/dtc.tar.xz"
    gv="$(input_version virglrenderer)"
    source_of virglrenderer "$gv" "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/$gv/virglrenderer-$gv.tar.gz" "$work/virgl.tar.gz"
    d="qemu-system-gl-$version-linux-$arch"
    runtime="libglib2.0-0 libpixman-1-0 zlib1g libepoxy0 libdrm2 libgbm1"
    debian "apt-get -qq update && apt-get -qq install -y --no-install-recommends build-essential python3 python3-venv python3-yaml \
            ninja-build meson pkg-config flex bison bzip2 xz-utils ca-certificates file \
            libglib2.0-dev libpixman-1-dev zlib1g-dev libepoxy-dev libdrm-dev libgbm-dev > /w/apt.log 2>&1 \
        && dpkg-query -W -f '\${Package} \${Version}\n' > /w/installed \
        && tar -xzf slirp.tar.gz && cd libslirp-v$sv \
        && meson setup build --prefix=/opt/slirp --libdir=lib --default-library=static -Db_staticpic=true >/dev/null \
        && ninja -C build install >/dev/null \
        && cd /w && tar -xzf virgl.tar.gz && cd virglrenderer-$gv \
        && meson setup build --prefix=/usr --libdir=lib -Dplatforms=egl -Dvenus=false -Dvideo=false -Dtests=false > /w/virgl.log 2>&1 \
        && ninja -C build >> /w/virgl.log 2>&1 && ninja -C build install >> /w/virgl.log 2>&1 \
        && DESTDIR=/w/vstage ninja -C build install >> /w/virgl.log 2>&1 \
        && cd /w && tar -xJf qemu.tar.xz && tar -xJf dtc.tar.xz && mv dtc-$dv qemu-$v/subprojects/dtc \
        && mkdir qb && cd qb \
        && PKG_CONFIG_PATH=/opt/slirp/lib/pkgconfig ../qemu-$v/configure --prefix=/usr \
             --target-list=x86_64-softmmu --enable-slirp --enable-fdt=internal \
             --enable-opengl --enable-virglrenderer --disable-modules \
             --disable-docs --disable-tools --disable-guest-agent --disable-user --disable-linux-user --disable-bsd-user \
             --disable-vnc --disable-sdl --disable-gtk --disable-curses --disable-spice --disable-rutabaga-gfx \
             --disable-libssh --disable-curl --disable-gnutls --disable-nettle --disable-gcrypt \
             --disable-libusb --disable-usb-redir --disable-smartcard --disable-xkbcommon --disable-dbus-display \
             --disable-linux-io-uring --disable-libudev --disable-zstd --disable-pa --disable-alsa --disable-jack \
             --disable-oss --disable-pipewire --disable-sndio --audio-drv-list= --disable-capstone --disable-libdaxctl \
             --disable-blkio --disable-brlapi --disable-vde --disable-libnfs --disable-rbd --disable-glusterfs \
             --disable-libiscsi --disable-seccomp --disable-cap-ng --enable-attr --enable-virtfs --disable-selinux \
             --disable-bzip2 --disable-lzo --disable-snappy --disable-numa --disable-linux-aio --disable-libpmem \
             --disable-fuse --disable-lzfse --disable-libkeyutils --disable-png --disable-vte > /w/configure.log 2>&1 \
        && make -j\$(nproc) > /w/make.log 2>&1 && make install DESTDIR=/w/stage > /w/install.log 2>&1 \
        && mkdir -p /w/$d/bin /w/$d/lib /w/$d/share && cp /w/stage/usr/bin/qemu-system-x86_64 /w/$d/bin/ \
        && cp -P /w/vstage/usr/lib/libvirglrenderer.so.1* /w/$d/lib/ \
        && strip /w/$d/bin/* /w/$d/lib/libvirglrenderer.so.1.* && cp -a /w/stage/usr/share/qemu /w/$d/share/ \
        && find /w/$d/share/qemu -name '*.bz2' -exec bunzip2 -f {} +" \
      || { for f in apt virgl configure make install; do [[ -f "$work/$f.log" ]] && { log "--- $f.log"; tail -40 "$work/$f.log" >&2; }; done; die "qemu-system-gl build failed"; }
    # What it links is glibc's, the packages the recipe names, and its own
    # virglrenderer -- nothing a Luban machine's host would have to provide.
    GLIBC_ELFS="$work/$d/bin/qemu-system-x86_64 $(ls "$work/$d"/lib/libvirglrenderer.so.1.*)" \
        glibc_only libvirglrenderer.so.1 libglib-2.0.so.0 libgmodule-2.0.so.0 libgio-2.0.so.0 libgobject-2.0.so.0 \
                   libpixman-1.so.0 libz.so.1 libepoxy.so.0 libdrm.so.2 libgbm.so.1 libgcc_s.so.1
    # It has the GPU device and the display that draws it without a window;
    # user networking, 9p and its firmware beside it, as qemu-system.
    debian "apt-get -qq update && apt-get -qq install -y --no-install-recommends $runtime > /dev/null \
        && q=/w/$d/bin/qemu-system-x86_64 && export LD_LIBRARY_PATH=/w/$d/lib \
        && \$q --version > /w/version \
        && \$q -M none -device help > /w/devices && \$q -M none -display help > /w/displays \
        && \$q -M none -netdev help > /w/netdevs && \$q -M none -L help | xargs -n1 realpath -m > /w/datadirs"
    grep -q "version $v" "$work/version" || die "qemu-system-gl does not report $v: $(cat "$work/version")"
    grep -q '"virtio-gpu-gl-pci"' "$work/devices" || die "qemu-system-gl has no virtio-gpu-gl-pci"
    grep -q '"virtio-9p-pci"' "$work/devices" || die "qemu-system-gl has no virtio-9p"
    grep -qx 'egl-headless' "$work/displays" || die "qemu-system-gl has no egl-headless display: $(tr '\n' ' ' < "$work/displays")"
    grep -qx user "$work/netdevs" || die "qemu-system-gl has no user networking"
    grep -qx "/w/$d/share/qemu" "$work/datadirs" || die "qemu-system-gl does not find its data beside it: $(tr '\n' ' ' < "$work/datadirs")"
    [[ -f "$work/$d/share/qemu/bios-256k.bin" && -f "$work/$d/share/qemu/edk2-x86_64-code.fd" ]] || die "the firmware is not in share/qemu"
    provenance "$d" "qemu $v (download.qemu.org, sha256 $(input qemu "$v")) qemu-system-x86_64 with OpenGL: virglrenderer $gv (gitlab.freedesktop.org, $(input virglrenderer "$gv")) in lib/, virtio-gpu-gl-pci and the egl-headless display; built on Debian 12 against $(grep -E '^(libc6|libglib2.0-dev|libpixman-1-dev|libepoxy-dev|libdrm-dev|libgbm-dev) ' "$work/installed" | tr '\n' ' ')-- the libraries an install takes from the index; user networking from libslirp $sv and libfdt from dtc $dv, static; firmware decompressed in share/qemu"
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
labwc-desktop)
    # The traditional Luban desktop (xlings: Luban OS architecture design
    # §9.3): labwc and the session around it -- a panel (yambar), a launcher
    # (fuzzel), a terminal (foot), a background (swaybg), a screenshot tool
    # (grim), Xwayland for X11 programs, fonts with CJK -- as one relocatable tree. Alpine 3.20's builds
    # of them, with the musl loader and every library they need in lib/; each
    # bin/<program> runs the loader with --library-path, so the tree runs on a
    # glibc root, a musl one, or a root with neither. The configuration in
    # etc/xdg is the session's default (a user's ~/.config wins); the session
    # is declared in share/wayland-sessions/labwc-desktop.desktop.
    # <upstream>-rN: this index's Nth build of it. r1: the libraries and the
    # loader are private (libexec/lib) -- a root links a payload's lib/ into
    # its /usr/lib, and these are musl's, not the root's -- and no ELF names
    # a loader (PT_INTERP made PT_NULL): a root checks that every ELF's loader
    # is in its closure, and these are only ever run by the tree's own.
    v="${version%%-r[0-9]*}"
    d="labwc-desktop-$version-linux-$arch"
    progs="labwc foot fuzzel yambar swaybg grim Xwayland xkbcomp"
    loader="ld-musl-$arch.so.1"
    alpine "apk add -q labwc foot fuzzel yambar swaybg grim xwayland xkbcomp font-dejavu font-wqy-zenhei xkeyboard-config \
        && apk info -v 2>/dev/null | sort > /w/installed \
        && grep -E '^(labwc|foot|fuzzel|yambar|swaybg|grim|xwayland|xkbcomp|font-dejavu|font-wqy-zenhei|xkeyboard-config)-[0-9]' /w/installed > /w/versions \
        && mkdir -p /w/$d/bin /w/$d/libexec/lib /w/$d/share/X11 \
        && for p in $progs; do cp /usr/bin/\$p /w/$d/libexec/; done \
        && for p in $progs; do ldd /usr/bin/\$p | awk '/=>/ { print \$3 }'; done | sort -u > /w/libs \
        && while read -r l; do cp -L \"\$l\" /w/$d/libexec/lib/; done < /w/libs \
        && cp -L /lib/$loader /w/$d/libexec/lib/ \
        && cp -r /usr/share/X11/xkb /w/$d/share/X11/ && cp -r /usr/share/fonts /w/$d/share/ \
        && mkdir -p /w/$d/share/licenses && for p in labwc foot fuzzel yambar swaybg grim; do \
             [ -d /usr/share/licenses/\$p ] && cp -r /usr/share/licenses/\$p /w/$d/share/licenses/ || true; done"
    grep -q "^labwc-$v-r" "$work/versions" || die "Alpine 3.20's labwc is not $v: $(grep '^labwc-' "$work/versions")"
    [[ ! -e "$work/$d/lib" ]] || die "a lib/ in the tree: a root would link it into its /usr/lib"
    cp -r "$luban/labwc-desktop/etc" "$luban/labwc-desktop/share" "$work/$d/"
    # No ELF here names a loader outside the tree (the tree's own runs them).
    n="$(python3 "$luban/bundle/no-interp.py" "$work/$d/libexec")"
    [[ "$n" -ge 8 ]] || die "PT_INTERP left in place ($n changed)"
    for p in $progs; do
        # Xwayland's keymaps: the tree's data and its xkbcomp, not the system's paths.
        args=""; [[ "$p" == Xwayland ]] && args='-xkbdir "$here/share/X11/xkb"'
        sed -e "s/@PROG@/$p/g" -e "s/@LOADER@/$loader/g" -e "s|@ARGS@|$args|" "$luban/labwc-desktop/run.in" > "$work/$d/bin/$p"
        chmod 755 "$work/$d/bin/$p"
    done
    # It runs on a root that is not Alpine's: a headless session in Debian,
    # with nothing of the tree's system, draws its background and its panel.
    debian "cd /w/$d && export XDG_RUNTIME_DIR=/tmp/rt WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
        && mkdir -p -m 700 /tmp/rt && { ./bin/labwc >/w/session.log 2>&1 & } \
        && for i in \$(seq 1 50); do [ -S /tmp/rt/wayland-0 ] && break; sleep 0.2; done && sleep 6 \
        && WAYLAND_DISPLAY=wayland-0 ./bin/grim -t ppm /w/shot.ppm \
        && { cat /proc/[0-9]*/cmdline 2>/dev/null || true; } | tr \"\\\\000\" \" \" > /w/procs && grep -q libexec/[y]ambar /w/procs && grep -q libexec/[s]waybg /w/procs \
        && WAYLAND_DISPLAY=wayland-0 ./bin/foot --version > /w/foot.version" \
      || { log "--- session.log"; tail -40 "$work/session.log" >&2 || true; die "the session did not run"; }
    # A failed check keeps the picture and the log beside the build's output.
    shot_die() { cp "$work/shot.ppm" "$out/failed-shot.ppm" 2>/dev/null; cp "$work/session.log" "$out/failed-session.log" 2>/dev/null; die "$1"; }
    head -c 20 "$work/shot.ppm" | grep -aq '^1280 720$' || shot_die "the screenshot is not the 1280x720 headless output"
    px() { od -An -tx1 -j $((16 + ($2 * 1280 + $1) * 3)) -N 3 "$work/shot.ppm" | tr -d ' '; }
    log "pixels: (0,0) $(px 0 0), (640,100) $(px 640 100), (640,360) $(px 640 360), (600,710) $(px 600 710)"
    # The background is drawn (not black), and the panel is a band of its own at the bottom.
    [[ "$(px 640 360)" != 000000 ]] || shot_die "nothing is drawn"
    [[ "$(px 600 710)" == "$(px 900 710)" && "$(px 600 710)" != "$(px 600 680)" ]] || shot_die "the panel is not drawn"
    grep -q "foot version" "$work/foot.version" || die "foot does not run"
    rm -f "$work/shot.ppm"
    provenance "$d" "labwc-desktop $version: Alpine 3.20 packages $(tr '\n' ' ' < "$work/versions")-- repackaged with the musl loader and the libraries they link (libexec/lib, private), run through bin/<program>; configuration and the session file from xim-pkgindex tools/res/luban/labwc-desktop; a headless session in Debian 12 drew its background and panel"
    pack "$d" ;;
foot)
    # luban:foot: the terminal the desktops start through the default-terminal
    # convention (share/xdg-terminals; xdg-terminal-exec). It links no EGL,
    # so its tree is small. <upstream>-rN: this index's Nth build of it.
    v="${version%%-r[0-9]*}"; d="foot-$version-linux-$arch"
    bundle foot "$d" "/usr/bin/foot /usr/bin/footclient" "apk add -q foot foot-extra-terminfo"
    bundle_upstream foot "$v"
    mkdir -p "$work/$d/share/terminfo/f"
    ALPINE_IMAGE="$ALPINE_DESKTOP" alpine "apk add -q foot-extra-terminfo && cp /usr/share/terminfo/f/foot* /w/$d/share/terminfo/f/ \
        && cp -r /usr/share/licenses/foot /w/$d/share/licenses/ 2>/dev/null || true"
    headless "$d" "./bin/foot --version > /w/foot.version && ./bin/foot --check-config -c etc/xdg/foot/foot.ini > /w/foot.config 2>&1"
    grep -q "foot version: $v" "$work/foot.version" || die "foot does not run: $(cat "$work/foot.version")"
    provenance "$d" "luban:foot $version: Alpine 3.24 $(grep -E '^foot-[0-9]' "$work/installed" | tr '\n' ' ')-- with the musl loader and the libraries it links (libexec/foot, private), run through bin/<program>; defaults and the default-terminal entry from xim-pkgindex tools/res/luban/foot; it ran in Debian 12. Sources: https://codeberg.org/dnkl/foot and Alpine's aports (community/foot), unmodified"
    pack "$d" ;;
xwayland)
    # luban:xwayland: X11 programs on a Wayland desktop. Alpine's Xwayland
    # links glamor and GLX, and through them mesa and LLVM (248 MB); a Luban
    # machine has no GPU, so this one is built from the same source with
    # neither (Alpine's APKBUILD, -Dglamor=false -Ddri3=false -Dglx=false):
    # 16 libraries.
    v="${version%%-r[0-9]*}"; d="xwayland-$version-linux-$arch"
    source_of xwayland "$v" "https://xorg.freedesktop.org/archive/individual/xserver/xwayland-$v.tar.xz" "$work/xwayland.tar.xz"
    source_of xwayland-libtirpc-patch "$v" "https://raw.githubusercontent.com/alpinelinux/aports/3.24-stable/community/xwayland/use-libtirpc-nokrb.patch" "$work/libtirpc.patch"
    bundle xwayland "$d" "/w/build/xwayland-$v/output/hw/xwayland/Xwayland /usr/bin/xkbcomp" \
        "apk add -q build-base meson ninja dbus-dev font-util-dev libdrm-dev libtirpc-dev libmd-dev libxcvt-dev libxfont2-dev \
             libxkbfile-dev libxshmfence-dev pixman-dev wayland-dev wayland-protocols xorgproto xtrans xkbcomp xkeyboard-config xwayland \
         && mkdir -p /w/build && tar -xJf /w/xwayland.tar.xz -C /w/build && cd /w/build/xwayland-$v && patch -p1 < /w/libtirpc.patch \
         && meson setup output --prefix=/usr --buildtype=release -Dipv6=true -Dxvfb=false -Dxdmcp=false -Dxcsecurity=true \
              -Ddri3=false -Dglamor=false -Dglx=false -Dsha1=libmd -Dxkb_dir=/usr/share/X11/xkb -Dxkb_output_dir=/var/lib/xkb >/dev/null \
         && ninja -C output >/dev/null && cd /w"
    bundle_upstream xwayland "$v"
    ! grep -Eq 'libEGL|libGL|libgallium|libLLVM' "$work/libs" || die "Xwayland links GL: $(grep -E 'libEGL|libGL|libgallium|libLLVM' "$work/libs" | tr '\n' ' ')"
    rm -rf "$work/build"
    headless "$d" "./bin/Xwayland -version > /w/x.version 2>&1"
    grep -q "Xwayland Version $v" "$work/x.version" || die "Xwayland does not run: $(cat "$work/x.version")"
    provenance "$d" "luban:xwayland $version: Xwayland $v (xorg.freedesktop.org, sha256 $(input xwayland "$v")) with Alpine 3.24's use-libtirpc-nokrb.patch, configured as Alpine's APKBUILD but -Ddri3=false -Dglamor=false -Dglx=false; xkbcomp from Alpine 3.24 ($(grep -E '^xkbcomp-[0-9]' "$work/installed" | tr '\n' ' ')); the keymaps are xim:xkeyboard-config's; the musl loader and its libraries private (libexec/xwayland); it ran in Debian 12"
    pack "$d" ;;
labwc)
    # luban:labwc: labwc with a panel (yambar), a launcher (fuzzel), a
    # background (swaybg) and screenshots (grim); the terminal is
    # luban:foot's and X11 is luban:xwayland's, both found the way any
    # desktop finds them. Alpine's wlroots links EGL and gbm, and through mesa
    # LLVM (235 MB); a Luban machine renders with pixman, so wlroots is built
    # from the same source without GPU renderers or allocators (Alpine's
    # APKBUILD, -Drenderers= -Dallocators=), installed over Alpine's, and
    # labwc links it.
    v="${version%%-r[0-9]*}"; d="labwc-$version-linux-$arch"; wv="$(input_version wlroots)"
    source_of wlroots "$wv" "https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/$wv/wlroots-$wv.tar.gz" "$work/wlroots.tar.gz"
    bundle labwc "$d" "/usr/bin/labwc /usr/bin/yambar /usr/bin/fuzzel /usr/bin/swaybg /usr/bin/grim" \
        "apk add -q labwc yambar fuzzel swaybg grim build-base meson ninja eudev-dev hwdata-dev libcap-dev libdisplay-info-dev libinput-dev \
             libseat-dev libliftoff-dev libxcb-dev libxkbcommon-dev lcms2-dev pixman-dev wayland-dev wayland-protocols \
             xcb-util-image-dev xcb-util-renderutil-dev xcb-util-wm-dev xkeyboard-config-dev xwayland-dev libdrm-dev \
         && mkdir -p /w/build && tar -xzf /w/wlroots.tar.gz -C /w/build && cd /w/build/wlroots-$wv \
         && meson setup build --prefix=/usr --buildtype=release -Dexamples=false -Drenderers= -Dallocators= \
              -Dcolor-management=enabled -Dxwayland=enabled >/dev/null && ninja -C build >/dev/null && ninja -C build install >/dev/null && cd /w \
         && mkdir -p /w/$d/share/licenses && for p in labwc yambar fuzzel swaybg grim; do \
              [ -d /usr/share/licenses/\$p ] && cp -r /usr/share/licenses/\$p /w/$d/share/licenses/ || true; done"
    bundle_upstream labwc "$v"
    ! grep -Eq 'libEGL|libgbm|libgallium|libLLVM' "$work/libs" || die "labwc links GL: $(grep -E 'libEGL|libgbm|libgallium|libLLVM' "$work/libs" | tr '\n' ' ')"
    rm -rf "$work/build"
    install -m 755 "$luban/bundle/xdg-terminal-exec" "$work/$d/bin/xdg-terminal-exec"
    # A root has fonts and keymaps (the recipe depends on xim:luban-fonts and
    # xim:xkeyboard-config); labwc does not start without either.
    headless "$d" "apt-get -qq update && apt-get -qq install -y fonts-dejavu-core xkb-data >/dev/null \
        && { ./bin/labwc >/w/session.log 2>&1 & } \
        && for i in \$(seq 1 50); do [ -S /tmp/rt/wayland-0 ] && break; sleep 0.2; done && sleep 6 \
        && ./bin/grim -t ppm /w/shot.ppm \
        && { cat /proc/[0-9]*/cmdline 2>/dev/null || true; } | tr \"\\\\000\" \" \" > /w/procs && grep -q labwc/bin/[y]ambar /w/procs && grep -q labwc/bin/[s]waybg /w/procs"
    shot_die() { cp "$work/shot.ppm" "$out/failed-shot.ppm" 2>/dev/null; cp "$work/session.log" "$out/failed-session.log" 2>/dev/null; die "$1"; }
    head -c 20 "$work/shot.ppm" | grep -aq '^1280 720$' || shot_die "the screenshot is not the 1280x720 headless output"
    px() { od -An -tx1 -j $((16 + ($2 * 1280 + $1) * 3)) -N 3 "$work/shot.ppm" | tr -d ' '; }
    log "pixels: (640,360) $(px 640 360), (600,710) $(px 600 710), (600,680) $(px 600 680)"
    [[ "$(px 640 360)" == 2e3440 ]] || shot_die "the background is not drawn"
    [[ "$(px 600 710)" == "$(px 900 710)" && "$(px 600 710)" != "$(px 600 680)" ]] || shot_die "the panel is not drawn"
    rm -f "$work/shot.ppm"
    provenance "$d" "luban:labwc $version: Alpine 3.24 $(grep -E '^(labwc|yambar|fuzzel|swaybg|grim)-[0-9]' "$work/installed" | tr '\n' ' ')-- with wlroots $wv (gitlab.freedesktop.org, sha256 $(input wlroots "$wv")) configured as Alpine's APKBUILD but -Drenderers= -Dallocators= (pixman only); the musl loader and the libraries they link private (libexec/labwc), run through bin/<program>; configuration, the session and xdg-terminal-exec from xim-pkgindex tools/res/luban/labwc and tools/res/luban/bundle; a headless session in Debian 12 drew its background and panel"
    pack "$d" ;;
audio)
    # luban:audio: a Luban desktop's sound (xlings design 2026-10-20 §20.1)
    # -- PipeWire, WirePlumber and pipewire-pulse, as Alpine lays them out
    # under /usr (lib/pipewire-0.3, lib/spa-0.2, lib/wireplumber-0.5,
    # share/pipewire, share/wireplumber: a root projects lib/<dir> and share
    # where the programs look), the programs' libraries and the musl loader
    # private (libexec/audio). Its own: the `luban` sink (share/pipewire/
    # pipewire.conf.d/luban.conf: a pipe-tunnel into /tmp/luban-audio.pcm,
    # 48 kHz stereo, the default output), which `luban __audio` reads and the
    # Luban OS window plays; bin/luban-audio, which starts the three for a
    # session (a Luban desktop's session runs it: opensal-wlr's run_session).
    # What a machine's sound never uses is left out: video (Vulkan, cameras,
    # V4L2), Bluetooth, JACK and the network streams -- Vulkan alone brought
    # Mesa and LLVM (235 MB).
    v="${version%%-r[0-9]*}"; d="audio-$version-linux-$arch"
    progs="/usr/bin/pipewire /usr/bin/pipewire-pulse /usr/bin/wireplumber /usr/bin/pw-cat /usr/bin/pw-cli /usr/bin/wpctl /usr/bin/pactl"
    bundle audio "$d" "$progs" \
        "apk add -q pipewire pipewire-pulse wireplumber pipewire-tools pulseaudio-utils \
         && rm -rf /usr/lib/spa-0.2/vulkan /usr/lib/spa-0.2/libcamera /usr/lib/spa-0.2/v4l2 /usr/lib/spa-0.2/bluez5 \
                   /usr/lib/spa-0.2/jack /usr/lib/spa-0.2/avb /usr/lib/spa-0.2/videoconvert /usr/lib/spa-0.2/videotestsrc \
                   /usr/lib/spa-0.2/ffmpeg /usr/lib/spa-0.2/aec \
         && cd /usr/lib/pipewire-0.3 && rm -f libpipewire-module-roc-* libpipewire-module-x11-bell.so libpipewire-module-jack* \
                   libpipewire-module-raop-* libpipewire-module-zeroconf-* libpipewire-module-avb.so libpipewire-module-rtp-* \
                   libpipewire-module-vban-* libpipewire-module-echo-cancel.so libpipewire-module-snapcast-* \
                   libpipewire-module-netjack2-* libpipewire-module-ffado-* && cd / \
         && mkdir -p /w/extra/lib /w/extra/share /w/extra/licenses \
         && cp -a /usr/lib/pipewire-0.3 /usr/lib/spa-0.2 /usr/lib/wireplumber-0.5 /w/extra/lib/ \
         && cp -a /usr/share/pipewire /usr/share/wireplumber /w/extra/share/ \
         && { [ ! -d /usr/share/spa-0.2 ] || cp -a /usr/share/spa-0.2 /w/extra/share/; } \
         && for p in pipewire wireplumber pulseaudio-utils; do [ -d /usr/share/licenses/\$p ] && cp -r /usr/share/licenses/\$p /w/extra/licenses/ || true; done" \
        "\$(find /usr/lib/pipewire-0.3 /usr/lib/spa-0.2 /usr/lib/wireplumber-0.5 -name '*.so')"
    bundle_upstream pipewire "$v"
    mkdir -p "$work/$d/lib" "$work/$d/share"
    cp -a "$work/extra/lib/." "$work/$d/lib/"
    cp -a "$work/extra/share/." "$work/$d/share/"
    cp -a "$work/extra/licenses/." "$work/$d/share/licenses/"
    rm -rf "$work/extra"
    # The modules name no loader and no search path of their own (a root
    # checks every ELF it holds: Alpine's say /usr/lib/pipewire-0.3); they
    # find their libraries through the program's.
    python3 "$luban/bundle/no-interp.py" "$work/$d/lib" >/dev/null
    ALPINE_IMAGE="$ALPINE_DESKTOP" alpine "apk add -q patchelf && sh /w/strip-rpath.sh /w/$d/lib"
    # It plays into the `luban` sink, the default: what is played comes out of the pipe.
    headless "$d" "head -c 192000 /dev/urandom > /w/noise.raw \
        && { ./bin/luban-audio >/w/session.log 2>&1 & } \
        && for i in \$(seq 1 50); do [ -S /tmp/rt/pulse/native ] && break; sleep 0.2; done \
        && for i in \$(seq 1 25); do [ -p /tmp/luban-audio.pcm ] && break; sleep 0.2; done \
        && { cat /tmp/luban-audio.pcm > /w/got.pcm & } && sleep 1 \
        && ./bin/pactl get-default-sink > /w/default-sink 2>&1 \
        && timeout 10 ./bin/pw-cat -p --raw --format s16 --rate 48000 --channels 2 /w/noise.raw \
        && sleep 1 && wc -c < /w/got.pcm > /w/got-size"
    grep -qx luban "$work/default-sink" || die "the default output is not the luban sink: $(cat "$work/default-sink")"
    [[ "$(cat "$work/got-size")" -ge 96000 ]] || die "the luban sink's pipe had $(cat "$work/got-size") bytes of 192000 played"
    ! find "$work/$d/lib" -name '*.so' -exec sh -c 'readelf -d "$1" | grep -Eq "R(UN)?PATH"' _ {} \; -print | grep -q . \
        || die "a module still names a search path"
    ! grep -Eq 'libLLVM|libgallium|libvulkan' "$work/libs" || die "luban:audio links GL or Vulkan: $(grep -E 'libLLVM|libgallium|libvulkan' "$work/libs" | tr '\n' ' ')"
    rm -f "$work/noise.raw" "$work/got.pcm"
    provenance "$d" "luban:audio $version: Alpine 3.24 $(grep -E '^(pipewire|pipewire-pulse|wireplumber|pipewire-tools|pulseaudio-utils)-[0-9]' "$work/installed" | tr '\n' ' ')-- the musl loader and the libraries they link private (libexec/audio), run through bin/<program>; lib/pipewire-0.3, lib/spa-0.2, lib/wireplumber-0.5 and share/ as Alpine has them; the luban sink and luban-audio from xim-pkgindex tools/res/luban/audio; in Debian 12 noise played into the default sink came out of its pipe"
    pack "$d" ;;
terminfo)
    # The terminal descriptions a root has (xlings design 2026-10-16 L §10):
    # ncurses' terminfo.src at a snapshot, compiled whole with tic, plus the
    # names kitty and Ghostty set in $TERM (xterm-kitty, xterm-ghostty) for
    # the entries ncurses calls kitty and ghostty. share/terminfo/<letter>/.
    tag="v${version%.*}_${version##*.}"; tag="${tag//./_}"
    source_of ncurses-terminfo.src "$version" \
        "https://raw.githubusercontent.com/ThomasDickey/ncurses-snapshots/$tag/misc/terminfo.src" "$work/terminfo.src"
    printf '%s\n' "xterm-kitty|the name kitty sets in TERM," "	use=kitty," \
                  "xterm-ghostty|the name Ghostty sets in TERM," "	use=ghostty," > "$work/names.src"
    d="terminfo-$version"
    alpine "apk add -q ncurses && mkdir -p /w/$d/share/terminfo \
        && cat terminfo.src names.src > all.src && tic -x -o /w/$d/share/terminfo all.src"
    for t in x/xterm x/xterm-256color s/screen-256color t/tmux-256color l/linux v/vt100 d/dumb \
             a/alacritty k/kitty x/xterm-kitty f/foot w/wezterm g/ghostty x/xterm-ghostty; do
        [[ -f "$work/$d/share/terminfo/$t" ]] || die "no terminfo for ${t#*/}"
    done
    mkdir -p "$work/$d/share/licenses/terminfo"
    # Its terms are the file's own header (the MIT-style ncurses license).
    head -60 "$work/terminfo.src" > "$work/$d/share/licenses/terminfo/COPYING"
    provenance "$d" "terminfo $version: ncurses-snapshots $tag misc/terminfo.src (sha256 $(input ncurses-terminfo.src "$version")) and xterm-kitty, xterm-ghostty naming kitty and ghostty; compiled with tic -x (Alpine 3.20's ncurses)"
    pack_data "$d" ;;
adwaita-cursors)
    # The cursor theme a desktop root has (L §10): the Xcursor files of GNOME's
    # Adwaita icon theme (24 to 96 pixels), the X11 names an X client asks for
    # as links to the CSS names it ships, and the `default` theme inheriting
    # it -- what a client that names no theme gets. Windows' .cur and .ani
    # are left out.
    source_of adwaita-icon-theme "$version" \
        "https://download.gnome.org/sources/adwaita-icon-theme/${version%%.*}/adwaita-icon-theme-$version.tar.xz" "$work/src.tar.xz"
    d="adwaita-cursors-$version"; c="$work/$d/share/icons/Adwaita/cursors"
    mkdir -p "$c" "$work/$d/share/icons/default" "$work/$d/share/licenses/adwaita-cursors"
    tar -xJf "$work/src.tar.xz" -C "$work"
    src="$work/adwaita-icon-theme-$version"
    find "$src/Adwaita/cursors" -maxdepth 1 -type f ! -name '*.cur' ! -name '*.ani' -exec cp {} "$c/" \;
    while read -r legacy css; do
        [[ -e "$c/$css" ]] || die "no $css cursor for $legacy"
        [[ -e "$c/$legacy" ]] || ln -s "$css" "$c/$legacy"
    done <<'NAMES'
left_ptr default
arrow default
top_left_arrow default
xterm text
ibeam text
hand1 pointer
hand2 pointer
pointing_hand pointer
watch wait
left_ptr_watch progress
half-busy progress
question_arrow help
whats_this help
crossed_circle not-allowed
circle not-allowed
forbidden not-allowed
fleur all-scroll
move grabbing
size_all all-scroll
openhand grab
closedhand grabbing
dnd-move grabbing
dnd-copy copy
dnd-link alias
dnd-none no-drop
cross crosshair
tcross crosshair
plus cell
sb_h_double_arrow ew-resize
sb_v_double_arrow ns-resize
h_double_arrow ew-resize
v_double_arrow ns-resize
size_hor ew-resize
size_ver ns-resize
size_fdiag nwse-resize
size_bdiag nesw-resize
fd_double_arrow nwse-resize
bd_double_arrow nesw-resize
split_h col-resize
split_v row-resize
top_left_corner nw-resize
top_right_corner ne-resize
bottom_left_corner sw-resize
bottom_right_corner se-resize
top_side n-resize
bottom_side s-resize
left_side w-resize
right_side e-resize
NAMES
    printf '%s\n' "[Icon Theme]" "Name=Adwaita" "Comment=The Adwaita cursors" > "$work/$d/share/icons/Adwaita/cursor.theme"
    printf '%s\n' "[Icon Theme]" "Name=Default" "Comment=The cursor theme of a client that names none" "Inherits=Adwaita" \
        > "$work/$d/share/icons/default/index.theme"
    cp "$src/COPYING" "$src/COPYING_LGPL" "$src/COPYING_CCBYSA3" "$work/$d/share/licenses/adwaita-cursors/"
    for n in default text pointer wait progress; do
        file -L "$c/$n" | grep -q "X11 cursor" || die "$n is not an Xcursor file"
    done
    provenance "$d" "Adwaita cursors $version: download.gnome.org adwaita-icon-theme-$version.tar.xz (sha256 $(input adwaita-icon-theme "$version")), Adwaita/cursors without .cur/.ani; X11 names linked to the CSS names; icons/default inherits Adwaita"
    pack_data "$d" ;;
sample-music)
    # luban:sample-music (xlings design 2026-10-21 §6.3, E12): what a desktop
    # plays to show its sound works -- the Aria of the Open Goldberg
    # Variations (J.S. Bach, BWV 988; Kimiko Ishizaka, piano), whose
    # recording is CC0 1.0 and composition public domain. share/luban/samples/music.
    d="sample-music-$version"; m="$work/$d/share/luban/samples/music"; l="$work/$d/share/licenses/sample-music"
    mkdir -p "$m" "$l"
    source_of open-goldberg-aria 2012.05.28 "https://archive.org/download/OpenGoldbergVariations/Kimiko%20Ishizaka%20-%20J.S.%20Bach-%20-Open-%20Goldberg%20Variations%2C%20BWV%20988%20%28Piano%29%20-%2001%20Aria.ogg" "$m/aria.ogg"
    cat > "$l/aria.txt" <<'TXT'
Aria, from the Goldberg Variations, BWV 988 -- Johann Sebastian Bach.
Performed by Kimiko Ishizaka, The Open Goldberg Variations (2012),
https://opengoldbergvariations.org, https://archive.org/details/OpenGoldbergVariations
The recording: CC0 1.0 Universal (https://creativecommons.org/publicdomain/zero/1.0/).
The composition: public domain.
TXT
    provenance "$d" "luban:sample-music $version: share/luban/samples/music/aria.ogg is archive.org's OpenGoldbergVariations '01 Aria.ogg' (Ogg Vorbis), unmodified; CC0 1.0 (the recording), public domain (the composition)"
    file="$out/sample-music-$version.tar.gz"
    tar --owner=0 --group=0 --numeric-owner --hard-dereference -czf "$file" -C "$work" "$d"
    seal "$file" ;;
luban-fonts)
    # The fonts the Luban OS window ships with (L §13): the console's
    # monospace (JetBrains Mono; Sarasa Mono SC for CJK, two cells wide), the
    # text's sans (Inter; Noto Sans SC for CJK) and the titles' pixel font
    # (Fusion Pixel 12px, Simplified Chinese). share/fonts/luban, every one
    # under the SIL Open Font License 1.1.
    d="luban-fonts-$version"; f="$work/$d/share/fonts/luban"; l="$work/$d/share/licenses/luban-fonts"
    mkdir -p "$f" "$l"
    source_of jetbrains-mono 2.304 "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" "$work/jb.zip"
    source_of inter 4.1 "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip" "$work/inter.zip"
    source_of sarasa-mono-sc 1.0.42 "https://github.com/be5invis/Sarasa-Gothic/releases/download/v1.0.42/SarasaMonoSC-TTF-1.0.42.7z" "$work/sarasa.7z"
    source_of sarasa-license 1.0.42 "https://raw.githubusercontent.com/be5invis/Sarasa-Gothic/v1.0.42/LICENSE" "$work/sarasa.LICENSE"
    source_of noto-sans-sc 2.004 "https://raw.githubusercontent.com/notofonts/noto-cjk/Sans2.004/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf" "$work/NotoSansSC-Regular.otf"
    source_of noto-license 2.004 "https://raw.githubusercontent.com/notofonts/noto-cjk/Sans2.004/LICENSE" "$work/noto.LICENSE"
    source_of fusion-pixel-font 2026.09.25 "https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.09.25/fusion-pixel-font-12px-proportional-ttf-v2026.09.25.zip" "$work/fusion.zip"
    alpine "apk add -q 7zip unzip \
        && unzip -q -j jb.zip fonts/ttf/JetBrainsMono-Regular.ttf fonts/ttf/JetBrainsMono-Bold.ttf OFL.txt -d jb \
        && unzip -q -j inter.zip extras/ttf/Inter-Regular.ttf LICENSE.txt -d inter \
        && unzip -q -j fusion.zip fusion-pixel-12px-proportional-zh_hans.ttf OFL.txt -d fusion \
        && 7z e -bd -y -osarasa sarasa.7z SarasaMonoSC-Regular.ttf SarasaMonoSC-Bold.ttf >/dev/null"
    cp "$work/jb/JetBrainsMono-Regular.ttf" "$work/jb/JetBrainsMono-Bold.ttf" "$work/inter/Inter-Regular.ttf" \
       "$work/fusion/fusion-pixel-12px-proportional-zh_hans.ttf" "$work/sarasa/SarasaMonoSC-Regular.ttf" \
       "$work/sarasa/SarasaMonoSC-Bold.ttf" "$work/NotoSansSC-Regular.otf" "$f/"
    cp "$work/jb/OFL.txt" "$l/JetBrainsMono-OFL.txt"; cp "$work/inter/LICENSE.txt" "$l/Inter-OFL.txt"
    cp "$work/fusion/OFL.txt" "$l/FusionPixel-OFL.txt"; cp "$work/sarasa.LICENSE" "$l/SarasaGothic-OFL.txt"
    cp "$work/noto.LICENSE" "$l/NotoSansCJK-OFL.txt"
    for x in "$f"/*; do file -b "$x" | grep -Eq "TrueType|OpenType" || die "$(basename "$x") is not a font: $(file -b "$x")"; done
    provenance "$d" "luban-fonts $version: JetBrains Mono 2.304 (Regular, Bold), Inter 4.1 (Regular), Sarasa Mono SC 1.0.42 (Regular, Bold), Noto Sans SC 2.004 (Regular, subset OTF), Fusion Pixel 12px proportional zh_hans 2026.09.25 -- from their GitHub releases, digests in tools/res/inputs.txt; licenses in share/licenses/luban-fonts"
    pack_data "$d" ;;
qt-runtime)
    # luban:qt-runtime: what LXQt and KDE share (design 2026-10-18 §13.5) --
    # Qt 6 (base, wayland, svg, declarative), the mesa its GUI links (EGL and
    # GL; llvmpipe where there is no GPU) and every library they need, the
    # musl loader; libexec/qt-runtime/{lib,plugins,qml}. No programs: a
    # desktop's wrapper runs its programs with this lib/ after its own.
    v="${version%%-r[0-9]*}"; d="qt-runtime-$version-linux-$arch"
    [[ "$version" == "$QT_RUNTIME" ]] || die "build.sh names the Qt runtime $QT_RUNTIME, not $version"
    cp "$luban/qt-runtime/tree.sh" "$luban/bundle/strip-rpath.sh" "$work/"
    ALPINE_IMAGE="$ALPINE_DESKTOP" alpine "apk add -q $QT_RUNTIME_APKS qt6-qtbase-dev && apk info -v 2>/dev/null | sort > /w/installed \
        && sh /w/tree.sh /w/$d/libexec/qt-runtime $QT_RUNTIME_APKS && mkdir -p /w/$d/share/licenses \
        && apk add -q patchelf && sh /w/strip-rpath.sh /w/$d/libexec/qt-runtime \
        && for p in qt6-qtbase mesa; do [ -d /usr/share/licenses/\$p ] && cp -r /usr/share/licenses/\$p /w/$d/share/licenses/ || true; done \
        && cp -L /usr/lib/qt6/bin/qtpaths6 /w/qtpaths6"
    bundle_upstream qt6-qtbase "$v"
    [[ ! -e "$work/$d/lib" ]] || die "a lib/ in the tree"
    n="$(python3 "$luban/bundle/no-interp.py" "$work/$d/libexec/qt-runtime" "$work/qtpaths6")"
    log "qt-runtime: $(ls "$work/$d/libexec/qt-runtime/lib" | wc -l) libraries, $(du -sh "$work/$d" | cut -f1); PT_INTERP cleared in $n"
    # It loads: a Qt program runs against it in Debian, by its loader.
    debian "cd /w/$d && ./libexec/qt-runtime/lib/ld-musl-$arch.so.1 --library-path ./libexec/qt-runtime/lib /w/qtpaths6 --qt-version > /w/qt.version"
    grep -q "^$v" "$work/qt.version" || die "the runtime does not run Qt $v: $(cat "$work/qt.version")"
    provenance "$d" "luban:qt-runtime $version: Alpine 3.24 $(grep -E '^(qt6-qtbase|qt6-qtwayland|qt6-qtsvg|qt6-qtdeclarative|mesa)-[0-9]' "$work/installed" | tr '\n' ' ')-- their libraries, plugins and QML modules and every library they link, with the musl loader (libexec/qt-runtime); a Qt program ran against it in Debian 12. Sources: https://download.qt.io and Alpine's aports, unmodified"
    pack "$d" ;;
lxqt)
    # luban:lxqt: LXQt 2 on Wayland -- its session on luban:labwc (the
    # compositor; `labwc -S lxqt-session`, as upstream's lxqt-wayland-session
    # starts it), its panel, desktop and file manager (pcmanfm-qt), runner,
    # notifications and settings, D-Bus for its session, the breeze icons.
    # Its libraries are those beyond luban:qt-runtime's ($QT_RUNTIME, checked
    # the same Qt); lxqt-panel's plugins in lib/lxqt-panel, where a Luban
    # system's /usr/lib has them (its compiled-in path).
    v="${version%%-r[0-9]*}"; d="lxqt-$version-linux-$arch"
    progs="/usr/bin/lxqt-session /usr/bin/lxqt-panel /usr/bin/lxqt-runner /usr/bin/lxqt-config /usr/bin/lxqt-config-appearance \
        /usr/bin/lxqt-config-session /usr/bin/lxqt-config-input /usr/bin/lxqt-config-monitor /usr/bin/lxqt-notificationd \
        /usr/bin/lxqt-about /usr/bin/lxqt-leave /usr/bin/pcmanfm-qt /usr/bin/dbus-daemon /usr/bin/dbus-run-session \
        /usr/bin/dbus-update-activation-environment /usr/bin/xdg-user-dirs-update /usr/bin/qterminal"
    cp "$luban/qt-runtime/tree.sh" "$luban/qt-runtime/desktop.sh" "$luban/bundle/strip-rpath.sh" "$work/"
    carried="lxqt-session lxqt-panel lxqt-runner lxqt-config lxqt-notificationd lxqt-about lxqt-qtplugin lxqt-themes lxqt-menu-data \
        liblxqt libqtxdg libfm-qt pcmanfm-qt breeze-icons hicolor-icon-theme dbus xdg-user-dirs qterminal qtermwidget"
    ALPINE_IMAGE="$ALPINE_DESKTOP" alpine "apk add -q $QT_RUNTIME_APKS $carried layer-shell-qt \
        && apk info -v 2>/dev/null | sort > /w/installed \
        && mkdir -p /w/$d/lib && cp -a /usr/lib/lxqt-panel /w/$d/lib/ \
        && sh /w/desktop.sh /w/$d lxqt \"$QT_RUNTIME_APKS\" \"$progs\" \"$carried\" \
        && apk add -q patchelf && sh /w/strip-rpath.sh /w/$d/libexec/lxqt /w/$d/lib /w/rt-root/libexec/qt-runtime \
        && cd /w/$d/etc/xdg/autostart && for a in at-spi-dbus-bus lxqt-xscreensaver-autostart lxqt-globalkeyshortcuts; do \
             [ ! -e \$a.desktop ] || mv \$a.desktop /w/dropped-\$a.desktop; done"
    bundle_upstream lxqt-session "$v"
    bundle_upstream qt6-qtbase "${QT_RUNTIME%%-r[0-9]*}"
    cp -r "$luban/lxqt/." "$work/$d/"
    mv "$work/$d/env" "$work/$d/libexec/lxqt/env"
    # Its defaults for a Luban system (xlings design 2026-10-20 G24-G26): the
    # desktop shows Home and Trash (Computer and Network need gvfs, which a
    # system has not); the panel's quick launch holds the terminal, the file
    # manager and the browser instead of "Drop application icons here"; the
    # terminal everything opens is qterminal, carried (the desktop's menu
    # named it, and it was not there).
    python3 - "$work/$d" <<'PY'
import re, sys
from pathlib import Path
tree = Path(sys.argv[1])
fm = tree / "share/pcmanfm-qt/lxqt/settings.conf"
text = fm.read_text()
text = re.sub(r"(?m)^DesktopShortcuts=.*$", "DesktopShortcuts=Home, Trash", text)
assert "DesktopShortcuts=Home, Trash" in text and "Terminal=qterminal" in text, "pcmanfm-qt's settings changed shape"
fm.write_text(text)
panel = tree / "etc/xdg/lxqt/panel.conf"
text = panel.read_text()
apps = ["qterminal.desktop", "pcmanfm-qt.desktop", "org.kde.falkon.desktop"]
entries = "".join(f"apps\\{k}\\desktop=/usr/share/applications/{a}\n" for k, a in enumerate(apps, 1)) + f"apps\\size={len(apps)}\n"
assert text.count("[quicklaunch]\n") == 1, "lxqt-panel's panel.conf has no [quicklaunch]"
text = text.replace("[quicklaunch]\n", "[quicklaunch]\n" + entries)
panel.write_text(text)
PY
    # Its programs keep their interpreter: the recipe's config() names this
    # tree's loader and library directories in them where it is installed (a
    # Qt program reads /proc/self/exe; LXQt's panel takes no theme run by a
    # loader). Its libraries and plugins name none.
    n="$(python3 "$luban/bundle/no-interp.py" "$work/$d/libexec/lxqt/lib" "$work/$d/libexec/lxqt/plugins" "$work/$d/lib")"
    for p in $progs; do
        p="$(basename "$p")"
        sed -e "s/@NAME@/lxqt/g" -e "s/@PROG@/$p/g" "$luban/bundle/run-direct.in" > "$work/$d/bin/$p"
        chmod 755 "$work/$d/bin/$p"
    done
    log "lxqt: $(ls "$work/$d/libexec/lxqt/lib" | wc -l) libraries of its own, $(du -sh "$work/$d" | cut -f1)"
    # A headless session in Debian: luban:labwc (published) as its compositor,
    # the runtime this build made where the recipe's config() names it; the
    # panel and the desktop draw.
    lv="$(input_version luban-labwc-$arch)"
    source_of "luban-labwc-$arch" "$lv" "https://github.com/xlings-res/labwc/releases/download/$lv/labwc-$lv-linux-$arch.tar.gz" "$work/labwc.tar.gz"
    mkdir -p "$work/test" && tar -xzf "$work/labwc.tar.gz" -C "$work/test"
    python3 "$luban/bundle/no-interp.py" "$work/rt-root" >/dev/null
    # Installed as the recipe's config() installs it, in a copy.
    cp -a "$work/$d" "$work/test/$d"
    echo "/w/rt-root" > "$work/test/$d/libexec/lxqt/qt-runtime"
    headless "test/$d" "apt-get -qq update && apt-get -qq install -y fonts-dejavu-core xkb-data patchelf >/dev/null \
        && for p in libexec/lxqt/bin/*; do patchelf --set-interpreter \$PWD/libexec/lxqt/lib/ld-musl-$arch.so.1 \
             --set-rpath \$PWD/libexec/lxqt/lib:/w/rt-root/libexec/qt-runtime/lib \$p; done \
        && mkdir -p /usr/lib /usr/share && ln -s \$PWD/lib/lxqt-panel /usr/lib/lxqt-panel \
        && for s in share/*; do [ -e /usr/\$s ] || ln -s \$PWD/\$s /usr/\$s; done \
        && export PATH=/w/test/labwc-$lv-linux-$arch/bin:\$PWD/bin:\$PATH \
        && { ./bin/luban-lxqt >/w/session.log 2>&1 & } \
        && for i in \$(seq 1 50); do [ -S /tmp/rt/wayland-0 ] && break; sleep 0.2; done && sleep 15 \
        && grim -t ppm /w/shot.ppm \
        && { cat /proc/[0-9]*/cmdline 2>/dev/null || true; } | tr \"\\\\000\" \" \" > /w/procs && grep -q lxqt/bin/[l]xqt-panel /w/procs && grep -q lxqt/bin/[p]cmanfm-qt /w/procs"
    shot_die() { cp "$work/shot.ppm" "$out/failed-shot.ppm" 2>/dev/null; cp "$work/session.log" "$out/failed-session.log" 2>/dev/null; die "$1"; }
    head -c 20 "$work/shot.ppm" | grep -aq '^1280 720$' || shot_die "the screenshot is not the 1280x720 headless output"
    px() { od -An -tx1 -j $((16 + ($2 * 1280 + $1) * 3)) -N 3 "$work/shot.ppm" | tr -d ' '; }
    log "pixels: (640,360) $(px 640 360), (600,710) $(px 600 710), (600,680) $(px 600 680)"
    [[ "$(px 600 710)" != "$(px 600 680)" ]] || shot_die "the panel is not drawn"
    provenance "$d" "luban:lxqt $version: Alpine 3.24 $(grep -E '^(lxqt-session|lxqt-panel|pcmanfm-qt|liblxqt|layer-shell-qt|breeze-icons|dbus)-[0-9]' "$work/installed" | tr '\n' ' ')-- on luban:qt-runtime $QT_RUNTIME (the same Qt, checked); the libraries beyond the runtime's and the musl loader private (libexec/lxqt), lxqt-panel's plugins in lib/lxqt-panel; the session, defaults and checks from xim-pkgindex tools/res/luban/lxqt; a headless session on luban:labwc in Debian 12 drew its panel. Sources: https://github.com/lxqt and Alpine's aports, unmodified"
    pack "$d" ;;
audacious)
    # luban:audacious: the desktops' music player (xlings design 2026-10-21
    # §6.3, E11): Alpine 3.24's Audacious and its plugins on luban:qt-runtime
    # ($QT_RUNTIME), as luban:falkon is. Its plugins and skins where it looks
    # for them from its own path (libexec/audacious/lib/audacious,
    # libexec/audacious/share/audacious); the libraries they link beyond the
    # runtime's private in libexec/audacious/lib. No FFmpeg plugin (its
    # libraries are most of the size; Vorbis, Opus, FLAC, MP3 and WAV are
    # Audacious' own plugins); no PipeWire, JACK or SDL output (their clients
    # load modules from the system's /usr/lib, glibc's in a Luban system):
    # it plays through PulseAudio, which a Luban desktop's luban:audio serves.
    v="${version%%-r[0-9]*}"; d="audacious-$version-linux-$arch"
    progs="/usr/bin/audacious"
    carried="audacious audacious-plugins"
    cp "$luban/qt-runtime/tree.sh" "$luban/qt-runtime/desktop.sh" "$luban/bundle/strip-rpath.sh" "$work/"
    ALPINE_IMAGE="$ALPINE_DESKTOP" alpine "apk add -q $QT_RUNTIME_APKS $carried \
        && apk info -v 2>/dev/null | sort > /w/installed \
        && mkdir -p /w/$d/lib && cp -r /usr/lib/audacious /w/$d/lib/ && rm -f /w/$d/lib/audacious/Input/ffaudio.so /w/$d/lib/audacious/Output/pipewire*.so /w/$d/lib/audacious/Output/jack*.so /w/$d/lib/audacious/Output/sdlout.so \
        && sh /w/desktop.sh /w/$d audacious \"$QT_RUNTIME_APKS\" \"$progs\" \"$carried\" \
        && mv /w/$d/lib/audacious /w/$d/libexec/audacious/lib/ && rmdir /w/$d/lib \
        && mkdir -p /w/$d/libexec/audacious/share && mv /w/$d/share/audacious /w/$d/libexec/audacious/share/ \
        && apk add -q patchelf && sh /w/strip-rpath.sh /w/$d/libexec/audacious /w/rt-root/libexec/qt-runtime"
    bundle_upstream audacious "$v"
    bundle_upstream qt6-qtbase "${QT_RUNTIME%%-r[0-9]*}"
    cp -r "$luban/audacious/." "$work/$d/"
    mv "$work/$d/env" "$work/$d/libexec/audacious/env"
    for p in Input/vorbis.so Output/pulse_audio.so General/qtui.so; do
        [[ -f "$work/$d/libexec/audacious/lib/audacious/$p" ]] || die "audacious: no $p"
    done
    python3 "$luban/bundle/no-interp.py" "$work/$d/libexec/audacious/lib" "$work/$d/libexec/audacious/plugins" >/dev/null
    sed -e "s/@NAME@/audacious/g" -e "s/@PROG@/audacious/g" "$luban/bundle/run-direct.in" > "$work/$d/bin/audacious"
    chmod 755 "$work/$d/bin/audacious"
    log "audacious: $(ls "$work/$d/libexec/audacious/lib" | wc -l) libraries of its own, $(du -sh "$work/$d" | cut -f1)"
    # It starts, says its version and finds its plugins, on the runtime this build made.
    python3 "$luban/bundle/no-interp.py" "$work/rt-root" >/dev/null
    mkdir -p "$work/test" && cp -a "$work/$d" "$work/test/$d"
    echo "/w/rt-root" > "$work/test/$d/libexec/audacious/qt-runtime"
    headless "test/$d" "apt-get -qq update && apt-get -qq install -y patchelf >/dev/null \
        && for p in libexec/audacious/bin/*; do patchelf --set-interpreter \$PWD/libexec/audacious/lib/ld-musl-$arch.so.1 \
             --set-rpath \$PWD/libexec/audacious/lib:/w/rt-root/libexec/qt-runtime/lib \$p; done \
        && QT_QPA_PLATFORM=offscreen ./bin/audacious --version > /w/audacious.version 2>&1"
    grep -qi "^audacious [0-9]" "$work/audacious.version" || die "audacious does not start: $(cat "$work/audacious.version")"
    provenance "$d" "luban:audacious $version: Alpine 3.24 $(grep -E '^(audacious|audacious-plugins)-[0-9]' "$work/installed" | tr '\n' ' ')-- on luban:qt-runtime $QT_RUNTIME (the same Qt); the libraries beyond the runtime's, its plugins and the musl loader private (libexec/audacious), without the FFmpeg plugin. Sources: https://audacious-media-player.org and Alpine's aports, unmodified"
    pack "$d" ;;
falkon)
    # luban:falkon: the browser every Luban desktop carries (xlings design
    # 2026-10-20 §20.2): KDE's Falkon on QtWebEngine, on luban:qt-runtime
    # ($QT_RUNTIME) as the Qt desktops are, the libraries beyond the
    # runtime's (QtWebEngine's Chromium, nss) private in libexec/falkon.
    # QtWebEngineProcess beside the program; its resources and locales in
    # share/qt6, which libexec/falkon/env names (QTWEBENGINE_*).
    v="${version%%-r[0-9]*}"; d="falkon-$version-linux-$arch"
    progs="/usr/bin/falkon /usr/lib/qt6/libexec/QtWebEngineProcess"
    carried="falkon qt6-qtwebengine"
    # What QtWebEngine's NSS opens by name (J59): its recipe declares them.
    opened="$(python3 "$luban/bundle/dlopen.py" declared pkgs/luban/falkon.lua | tr '\n' ' ')"
    [[ -n "$opened" ]] || die "falkon: its recipe declares no dlopen libraries (NSS's modules)"
    cp "$luban/qt-runtime/tree.sh" "$luban/qt-runtime/desktop.sh" "$luban/bundle/strip-rpath.sh" "$work/"
    # ICU's whole data (icu-data-full): Blink's line breaker needs it -- the
    # runtime's libicudata is Alpine's stub, and a page's renderer crashed on
    # an empty break iterator (xlings design 2026-10-20 WuXian §14, H23).
    ALPINE_IMAGE="$ALPINE_DESKTOP" alpine "apk add -q $QT_RUNTIME_APKS $carried icu-data-full \
        && apk info -v 2>/dev/null | sort > /w/installed \
        && sh /w/desktop.sh /w/$d falkon \"$QT_RUNTIME_APKS\" \"$progs\" \"$carried\" \"$opened\" \
        && mkdir -p /w/$d/libexec/falkon/share && cp -r /usr/share/icu /w/$d/libexec/falkon/share/ \
        && apk add -q patchelf && sh /w/strip-rpath.sh /w/$d/libexec/falkon /w/$d/lib /w/rt-root/libexec/qt-runtime"
    bundle_upstream falkon "$v"
    bundle_upstream qt6-qtbase "${QT_RUNTIME%%-r[0-9]*}"
    cp -r "$luban/falkon/." "$work/$d/"
    mv "$work/$d/env" "$work/$d/libexec/falkon/env"
    [[ -d "$work/$d/share/qt6/resources" ]] || die "falkon: no QtWebEngine resources in share/qt6/resources"
    icu="$(find "$work/$d/libexec/falkon/share/icu" -name 'icudt*l.dat' -size +20M | head -1)"
    [[ -n "$icu" ]] || die "falkon: no whole ICU data in libexec/falkon/share/icu"
    python3 "$luban/bundle/no-interp.py" "$work/$d/libexec/falkon/lib" "$work/$d/libexec/falkon/plugins" >/dev/null
    # shellcheck disable=SC2086
    python3 "$luban/bundle/dlopen.py" check "$work/$d/libexec/falkon/lib" "$work/$d" $opened || die "falkon: a declared dlopen library is missing"
    sed -e "s/@NAME@/falkon/g" -e "s/@PROG@/falkon/g" "$luban/bundle/run-direct.in" > "$work/$d/bin/falkon"
    chmod 755 "$work/$d/bin/falkon"
    log "falkon: $(ls "$work/$d/libexec/falkon/lib" | wc -l) libraries of its own, $(du -sh "$work/$d" | cut -f1)"
    # It starts and says its version, on the runtime this build made.
    python3 "$luban/bundle/no-interp.py" "$work/rt-root" >/dev/null
    mkdir -p "$work/test" && cp -a "$work/$d" "$work/test/$d"
    echo "/w/rt-root" > "$work/test/$d/libexec/falkon/qt-runtime"
    headless "test/$d" "apt-get -qq update && apt-get -qq install -y patchelf >/dev/null \
        && for p in libexec/falkon/bin/*; do patchelf --set-interpreter \$PWD/libexec/falkon/lib/ld-musl-$arch.so.1 \
             --set-rpath \$PWD/libexec/falkon/lib:/w/rt-root/libexec/qt-runtime/lib \$p; done \
        && QT_QPA_PLATFORM=offscreen ./bin/falkon --version > /w/falkon.version 2>&1 \
        && apt-get -qq install -y python3 openssl >/dev/null \
        && openssl req -x509 -newkey rsa:2048 -nodes -subj /CN=127.0.0.1 -keyout /tmp/k.pem -out /tmp/c.pem -days 1 2>/dev/null \
        && (cd /tmp && python3 -c \"import http.server, ssl; s = http.server.HTTPServer(('127.0.0.1', 8443), http.server.SimpleHTTPRequestHandler); c = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); c.load_cert_chain('/tmp/c.pem', '/tmp/k.pem'); s.socket = c.wrap_socket(s.socket, server_side=True); s.serve_forever()\" > /w/https.log 2>&1 &) \
        && sleep 1 && rc=0 && QT_QPA_PLATFORM=offscreen QTWEBENGINE_CHROMIUM_FLAGS=\"--disable-gpu --ignore-certificate-errors\" timeout 40 ./bin/falkon --private-browsing https://127.0.0.1:8443/ > /w/falkon-https.log 2>&1 || rc=\$? ; echo \$rc > /w/falkon-https.rc"
    grep -qi "^falkon [0-9]" "$work/falkon.version" || die "falkon does not start: $(cat "$work/falkon.version")"
    # An https page (NSS's first use) does not end it (J59): still running when the time is up.
    [[ "$(cat "$work/falkon-https.rc")" == 124 ]] || die "falkon ended on an https page ($(cat "$work/falkon-https.rc")): $(tail -20 "$work/falkon-https.log")"
    grep -q "GET / " "$work/https.log" || die "falkon did not ask for the https page: $(tail -5 "$work/https.log")"
    provenance "$d" "luban:falkon $version: Alpine 3.24 $(grep -E '^(falkon|qt6-qtwebengine)-[0-9]' "$work/installed" | tr '\n' ' ')-- on luban:qt-runtime $QT_RUNTIME (the same Qt); the libraries beyond the runtime's and the musl loader private (libexec/falkon); the defaults from xim-pkgindex tools/res/luban/falkon. Sources: https://invent.kde.org/network/falkon, https://code.qt.io/qt/qtwebengine and Alpine's aports, unmodified"
    pack "$d" ;;
kde)
    # luban:kde (preview): KDE Plasma 6 -- KWin, Plasma's shell, Dolphin,
    # Konsole, System Settings -- on luban:qt-runtime ($QT_RUNTIME), KWin a
    # window of luban:labwc filling its output (design 2026-10-18 §13.3 (a):
    # the bridge shows labwc; a KDE-native adapter is the next form). Every
    # package Plasma brings beyond the runtime's, laid out as Alpine lays it
    # out under /usr (qt-runtime/desktop-auto.sh): a Luban system's /usr has
    # its helpers where they were built to be.
    v="${version%%-r[0-9]*}"; d="kde-$version-linux-$arch"
    apks="kwin plasma-workspace plasma-desktop breeze breeze-icons konsole dolphin systemsettings kde-cli-tools"
    cp "$luban/qt-runtime/tree.sh" "$luban/qt-runtime/desktop-auto.sh" "$luban/bundle/strip-rpath.sh" "$work/"
    ALPINE_IMAGE="$ALPINE_DESKTOP" alpine "sh /w/desktop-auto.sh /w/$d kde \"$QT_RUNTIME_APKS\" \"$apks\" \
        && apk info -v 2>/dev/null | sort > /w/installed \
        && apk add -q patchelf && sh /w/strip-rpath.sh /w/$d/libexec/kde /w/$d/lib /w/rt-root/libexec/qt-runtime"
    bundle_upstream plasma-workspace "$v"
    bundle_upstream qt6-qtbase "${QT_RUNTIME%%-r[0-9]*}"
    # Plasma's own sessions start KWin as a compositor of its own, which the
    # bridge cannot show; this package's session is the one.
    mkdir -p "$work/dropped"
    for f in "$work/$d"/share/wayland-sessions/* "$work/$d"/share/xsessions/*; do [[ -e "$f" ]] && mv "$f" "$work/dropped/"; done
    cp -r "$luban/kde/." "$work/$d/"
    mv "$work/$d/env" "$work/$d/libexec/kde/env"
    # The camera indicator needs kpipewire's QML module, and a system has no
    # camera to show (xlings design 2026-10-20 G30): not in its tray.
    rm -rf "$work/$d/share/plasma/plasmoids/org.kde.plasma.cameraindicator"
    # Its programs keep their interpreter (config() names its loader in
    # them); its libraries and plugins name none.
    python3 "$luban/bundle/no-interp.py" "$work/$d/libexec/kde/lib" "$work/$d/libexec/kde/plugins" "$work/$d/libexec/kde/qml" >/dev/null
    while read -r p; do
        sed -e "s/@NAME@/kde/g" -e "s/@PROG@/$p/g" "$luban/bundle/run-direct.in" > "$work/$d/bin/$p"
        chmod 755 "$work/$d/bin/$p"
    done < "$work/programs"
    # What config() points at this tree's loader: every ELF naming one.
    python3 "$luban/bundle/programs.py" "$work/$d" > "$work/$d/libexec/kde/programs"
    log "kde: $(wc -l < "$work/programs") programs ($(wc -l < "$work/$d/libexec/kde/programs") ELF with a loader), $(ls "$work/$d/libexec/kde/lib" | wc -l) libraries of its own, $(du -sh "$work/$d" | cut -f1)"
    # A headless session in Debian: luban:labwc (published) as the host
    # compositor, the runtime this build made; Plasma's panel draws.
    lv="$(input_version luban-labwc-$arch)"
    source_of "luban-labwc-$arch" "$lv" "https://github.com/xlings-res/labwc/releases/download/$lv/labwc-$lv-linux-$arch.tar.gz" "$work/labwc.tar.gz"
    mkdir -p "$work/test" && tar -xzf "$work/labwc.tar.gz" -C "$work/test"
    python3 "$luban/bundle/no-interp.py" "$work/rt-root" >/dev/null
    cp -a "$work/$d" "$work/test/$d"
    echo "/w/rt-root" > "$work/test/$d/libexec/kde/qt-runtime"
    headless "test/$d" "apt-get -qq update && apt-get -qq install -y fonts-dejavu-core xkb-data patchelf >/dev/null \
        && find . -type f ! -name '*.so*' -perm -u+x | while read -r p; do patchelf --print-interpreter \$p 2>/dev/null | grep -q '^/lib/ld-musl' || continue; \
             patchelf --set-interpreter \$PWD/libexec/kde/lib/ld-musl-$arch.so.1 --set-rpath \$PWD/libexec/kde/lib:/w/rt-root/libexec/qt-runtime/lib \$p; done \
        && for s in share/*; do [ -e /usr/\$s ] || ln -s \$PWD/\$s /usr/\$s; done \
        && mkdir -p /usr/lib && for l in lib/*; do [ -e /usr/\$l ] || ln -s \$PWD/\$l /usr/\$l; done \
        && for b in bin/*; do [ -e /usr/\$b ] || ln -s \$PWD/\$b /usr/\$b; done \
        && for l in libexec/*; do [ \$l = libexec/kde ] || [ -e /usr/\$l ] || ln -s \$PWD/\$l /usr/\$l; done \
        && export PATH=/w/test/labwc-$lv-linux-$arch/bin:\$PWD/bin:\$PATH \
        && { ./bin/luban-kde >/w/session.log 2>&1 & } \
        && for i in \$(seq 1 50); do [ -S /tmp/rt/wayland-0 ] && break; sleep 0.2; done && sleep 60 \
        && grim -t ppm /w/shot.ppm \
        && { cat /proc/[0-9]*/cmdline 2>/dev/null || true; } | tr \"\\\\000\" \" \" > /w/procs && grep -q kde/bin/[k]win_wayland /w/procs && grep -q kde/bin/[p]lasmashell /w/procs"
    shot_die() { cp "$work/shot.ppm" "$out/failed-shot.ppm" 2>/dev/null; cp "$work/session.log" "$out/failed-session.log" 2>/dev/null; die "$1"; }
    head -c 20 "$work/shot.ppm" | grep -aq '^1280 720$' || shot_die "the screenshot is not the 1280x720 headless output"
    px() { od -An -tx1 -j $((16 + ($2 * 1280 + $1) * 3)) -N 3 "$work/shot.ppm" | tr -d ' '; }
    log "pixels: (640,360) $(px 640 360), (600,700) $(px 600 700), (600,640) $(px 600 640)"
    [[ "$(px 640 360)" != 000000 && "$(px 600 700)" != "$(px 600 640)" ]] || shot_die "Plasma's desktop and panel are not drawn"
    provenance "$d" "luban:kde $version: Alpine 3.24 $(grep -E '^(plasma-workspace|kwin|plasma-desktop|konsole|dolphin|systemsettings|breeze)-[0-9]' "$work/installed" | tr '\n' ' ')-- on luban:qt-runtime $QT_RUNTIME (the same Qt, checked); every package Plasma brings beyond the runtime's as Alpine lays it out under /usr, the libraries private (libexec/kde) with the musl loader; the session from xim-pkgindex tools/res/luban/kde; a headless session nested in luban:labwc in Debian 12 drew Plasma's desktop and panel. Sources: https://invent.kde.org and Alpine's aports, unmodified"
    pack "$d" ;;
*)
    die "unknown resource: $what" ;;
esac
