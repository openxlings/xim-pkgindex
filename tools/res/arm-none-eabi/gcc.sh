#!/usr/bin/env bash
# arm-none-eabi-gcc: binutils + GCC (C, C++) for arm-none-eabi, WITHOUT a C
# library -- libgcc is the only target library in the payload. The C library
# is a package of its own (newlib-arm-none-eabi, picolibc-arm-none-eabi), and
# so is libstdc++ (libstdcxx-<libc>-arm-none-eabi@<this gcc's version>),
# because libstdc++ is built against a C library's headers.
#
#   gcc.sh <gcc-version> <binutils-version> <sources> <prefix> <work>
#
# <sources> holds gcc-<v>.tar.xz and binutils-<v>.tar.xz, already checked
# against tools/res/inputs.txt. Run by `tools/res/build.sh arm-none-eabi-gcc`
# in its Debian container; it runs the same on a bare Linux host.
#
# What the configure decides, and why:
#
#   --with-multilib-list=rmprofile   the Cortex-M/R multilibs, the set Arm's
#       own toolchain carries for them (thumb/v6-m/nofp ... thumb/v8-m.main+fp/
#       hard). A C library package is built by THIS compiler, from its own
#       `-print-multi-lib`, so the two always agree; a compiler with another
#       list is a new package version, never a rebuild of this one.
#
#   --with-sysroot=<prefix>/arm-none-eabi --with-native-system-header-dir=/include
#       the sysroot is laid out as newlib installs itself (include/,
#       lib/<multilib>/), and it is under the prefix, so GCC and ld treat it as
#       RELOCATABLE: no build path is baked into the payload. A C library is
#       then selected with `--sysroot=<its package>/arm-none-eabi`; the
#       `=/include/newlib-nano` in nano.specs is relative to that sysroot.
#
#   --without-headers --with-newlib  there is no C library at build time;
#       libgcc is built with inhibit_libc, as Homebrew's arm-none-eabi-gcc is.
#       Consequence: no libgcov (`--coverage` does not link).
#
#   --with-static-standard-libraries, --without-zstd, in-tree gmp/mpfr/mpc,
#       binutils' bundled zlib: the host programs need glibc and nothing else.
set -euo pipefail

gv="$1"; bv="$2"; src="$(cd "$3" && pwd)"; prefix="$4"; w="$5"
target=arm-none-eabi
j="$(nproc)"
mkdir -p "$w" "$prefix"; prefix="$(cd "$prefix" && pwd)"; cd "$w"
export PATH="$prefix/bin:$PATH"

# Target libraries without debug info, each function in its own section (what
# --gc-sections in a firmware link needs to drop what is unused).
export CFLAGS_FOR_TARGET="-O2 -ffunction-sections -fdata-sections"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"

tar -xf "$src/binutils-$bv.tar.xz"
tar -xf "$src/gcc-$gv.tar.xz"
# gmp, mpfr, mpc in the tree (linked static), checked against the sha512 GCC
# itself ships (contrib/prerequisites.sha512). No isl: no Graphite.
(cd "gcc-$gv" && ./contrib/download_prerequisites --no-graphite >"$w/prereq.log" 2>&1)

common=(--target=$target --prefix="$prefix" --with-sysroot="$prefix/$target"
        --with-pkgversion=xlings --disable-nls --disable-werror --without-zstd MAKEINFO=true)

mkdir -p b-binutils && cd b-binutils
"../binutils-$bv/configure" "${common[@]}" \
    --enable-multilib --enable-interwork --enable-plugins --enable-deterministic-archives \
    --disable-gdb --disable-gdbserver --disable-sim --disable-gprofng \
    --disable-libdecnumber --disable-readline --without-debuginfod >"$w/binutils-configure.log" 2>&1
make -j"$j" MAKEINFO=true >"$w/binutils-make.log" 2>&1
make install-strip MAKEINFO=true >"$w/binutils-install.log" 2>&1
cd "$w"

mkdir -p b-gcc && cd b-gcc
"../gcc-$gv/configure" "${common[@]}" \
    --with-native-system-header-dir=/include --with-multilib-list=rmprofile \
    --enable-languages=c,c++ --without-headers --with-newlib \
    --disable-shared --disable-threads --disable-tls --disable-libssp \
    --disable-libgomp --disable-libquadmath --disable-libffi --disable-libstdcxx \
    --disable-decimal-float --enable-checking=release --without-isl \
    --with-static-standard-libraries --with-gnu-as --with-gnu-ld >"$w/gcc-configure.log" 2>&1
make -j"$j" MAKEINFO=true all-gcc all-target-libgcc >"$w/gcc-make.log" 2>&1
make MAKEINFO=true install-strip-gcc install-target-libgcc >"$w/gcc-install.log" 2>&1
cd "$w"

# What ships is only what was installed; info pages and man pages are not built
# (MAKEINFO=true), and the libtool archives name the build prefix.
rm -rf "$prefix/share/info" "$prefix/share/man"
find "$prefix" -name '*.la' -delete
