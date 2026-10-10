#!/usr/bin/env bash
# Build an xlings-res resource this index publishes, reproducibly, on the
# architecture it is for (xlings: Luban OS design part 2 §4.2).
#
#   tools/res/build.sh limine      <version> <out>   # boot files + a static `limine` tool
#   tools/res/build.sh kernel-virt <version> <out>   # a virt kernel: virtio, ext4, console built in
#   tools/res/build.sh busybox     <version> <out>   # a static busybox (musl)
#
# Runs on the machine of the target architecture (CI: ubuntu-24.04 and
# ubuntu-24.04-arm); static builds run in an Alpine container (musl). Each
# writes <out>/<package>-<version>-linux-<arch>.tar.gz (or the raw ELF for
# busybox) and a .sha256 beside it. Inputs are checked against upstream's
# published digests; the build configuration is in this directory.
set -euo pipefail

what="$1"; version="$2"; out="$(mkdir -p "$3" && cd "$3" && pwd)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
arch="$(uname -m)"; [[ "$arch" == arm64 ]] && arch=aarch64
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
log() { printf '[res] %s\n' "$*" >&2; }

fetch() {   # url, expected sha256, file
    curl -fsSL --retry 3 -o "$3" "$1"
    echo "$2  $3" | sha256sum -c - >/dev/null || { log "sha256 mismatch: $1"; exit 1; }
}

alpine() {  # a command in an Alpine container, $work mounted at /w; what it makes is ours after
    docker run --rm -v "$work:/w" -w /w alpine:3.20 sh -euc "$1; chown -R $(id -u):$(id -g) /w"
}

seal() {    # file -> file.sha256
    (cd "$(dirname "$1")" && sha256sum "$(basename "$1")" > "$(basename "$1").sha256")
    log "$(cat "$1.sha256")"
}

case "$what" in
limine)
    sha="$(grep "^limine-binary $version " "$here/inputs.txt" | cut -d' ' -f3)"
    [[ -n "$sha" ]] || { log "no input digest for limine $version"; exit 1; }
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
    tar --owner=0 --group=0 --numeric-owner -czf "$file" -C "$work" "limine-$version"
    seal "$file" ;;
kernel-virt)
    sums="$work/sha256sums.asc"
    curl -fsSL --retry 3 -o "$sums" "https://cdn.kernel.org/pub/linux/kernel/v${version%%.*}.x/sha256sums.asc"
    sha="$(grep " linux-$version.tar.xz\$" "$sums" | cut -d' ' -f1)"
    [[ -n "$sha" ]] || { log "kernel.org lists no linux-$version.tar.xz"; exit 1; }
    fetch "https://cdn.kernel.org/pub/linux/kernel/v${version%%.*}.x/linux-$version.tar.xz" "$sha" "$work/linux.tar.xz"
    tar -xJf "$work/linux.tar.xz" -C "$work"
    src="$work/linux-$version"
    karch=x86; image=arch/x86/boot/bzImage
    [[ "$arch" == aarch64 ]] && { karch=arm64; image=arch/arm64/boot/Image; }
    make -s -C "$src" ARCH="$karch" defconfig
    make -s -C "$src" ARCH="$karch" kvm_guest.config
    "$src/scripts/kconfig/merge_config.sh" -m -O "$src" "$src/.config" "$here/kernel-virt.config" >/dev/null
    make -s -C "$src" ARCH="$karch" olddefconfig
    for opt in VIRTIO_BLK VIRTIO_NET VIRTIO_PCI VIRTIO_CONSOLE EXT4_FS BLK_DEV_INITRD RD_GZIP DEVTMPFS DEVTMPFS_MOUNT EFI_STUB; do
        grep -q "^CONFIG_$opt=y" "$src/.config" || { log "CONFIG_$opt is not built in"; exit 1; }
    done
    make -s -C "$src" ARCH="$karch" -j"$(nproc)" LOCALVERSION=-virt "$(basename "$image")"
    release="$(make -s -C "$src" ARCH="$karch" LOCALVERSION=-virt kernelrelease)"
    root="$work/linux-kernel-virt-$version"
    mkdir -p "$root/lib/modules/$release"
    cp "$src/$image" "$root/lib/modules/$release/vmlinuz"
    cp "$src/.config" "$root/lib/modules/$release/config"
    printf 'linux %s (kernel.org, sha256 %s), %s defconfig + kvm_guest.config + kernel-virt.config; no modules: what a virtual machine needs is built in\n' \
        "$version" "$sha" "$karch" > "$root/README.provenance"
    file="$out/linux-kernel-virt-$version-linux-$arch.tar.gz"
    tar --owner=0 --group=0 --numeric-owner -czf "$file" -C "$work" "linux-kernel-virt-$version"
    seal "$file" ;;
busybox)
    sha="$(grep "^busybox $version " "$here/inputs.txt" | cut -d' ' -f3)"
    [[ -n "$sha" ]] || { log "no input digest for busybox $version"; exit 1; }
    fetch "https://busybox.net/downloads/busybox-$version.tar.bz2" "$sha" "$work/busybox.tar.bz2"
    alpine "apk add -q build-base linux-headers perl && tar -xjf busybox.tar.bz2 && cd busybox-$version \
        && make -s defconfig >/dev/null && sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/; s/^CONFIG_TC=y/# CONFIG_TC is not set/' .config \
        && make -s oldconfig </dev/null >/dev/null && make -s -j\$(nproc) busybox && strip busybox && cp busybox /w/busybox.out"
    file="$out/busybox-$version-linux-$arch"
    cp "$work/busybox.out" "$file"
    seal "$file" ;;
*)
    log "unknown resource: $what"; exit 2 ;;
esac
