# arm-none-eabi-gcc

GCC 14.2.0 (C, C++) and binutils 2.43.1 for bare-metal Arm (Cortex-M/R), **without a C
library** (libgcc only), as Homebrew's `arm-none-eabi-gcc`. Commands: the 27
`arm-none-eabi-*` programs. Status: dev.

- Upstream: https://gcc.gnu.org/, https://www.gnu.org/software/binutils (GPL-3.0-or-later,
  GCC runtime library exception)
- Namespace: `zhefeng` (unofficial, see "Provenance"; lowercase letters only, as the index's install checks require); id `zhefeng:arm-none-eabi-gcc@14.2.0`
- Platforms: linux x86_64/aarch64, windows x86_64, macosx aarch64. Not built: macosx x86_64,
  windows aarch64.
- Siblings (same pull request, designed together): `newlib-arm-none-eabi` (C) and
  `libstdcxx-newlib-arm-none-eabi` (C and C++), sysroots selected with `--sysroot`.
  Planned: `picolibc-arm-none-eabi`.

## Source

- Tier: GNU publishes no prebuilt; built from GNU's release tarballs by
  https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc and published on its releases
  (tag `arm-none-eabi-gcc-14.2.0-r1`). A maintainer suggested self-hosting first, moving later.
- GLOBAL: that release; CN: none (`ci = { mirror = true }` copies it to xlings-res after merge).
- Checksums: each asset's `.sha256` file in the release and GitHub's asset digest agree with
  the xpkg; the linux x86_64 bytes were also downloaded and hashed here (the others were not).
- Auto-update: no (a new version is a factory build).

## Linking

Linux host programs need `libc.so.6`, `libm.so.6` and the loader only (measured over every
ELF of the x86_64 payload); declared `xim:glibc@>=2.39`, `xim:patchelf` as build dep for
elfpatch. Windows: static, Windows DLLs only. macOS: system libraries, macOS 11+.

## What the hooks do

- install: moves the archive's single directory into the install dir; asserts `bin/arm-none-eabi-gcc`,
  `arm-none-eabi/bin/{as,ld}`, `cc1`, `cc1plus`.
- config: `xvm.add` for each program, bound to `arm-none-eabi-gcc@14.2.0`.
- uninstall: `xvm.remove` for each program.
- System impact: none. Nothing enters the SubOS include/lib path; the compiler's own sysroot
  `<prefix>/arm-none-eabi` is relocatable and empty.

## Provenance

- Inputs: gcc-14.2.0.tar.xz (sha256 `a7b39bc6…3cc9`), binutils-2.43.1.tar.xz (`13f74202…2dfd`),
  from ftpmirror.gnu.org.
- Recipe: `fromsource/pkgs/a/arm-none-eabi-gcc.lua` at 3fa7932, built by xlings 2026.11.16.1 in
  `debian:12@sha256:2c037a04…e858` (Linux), cross-built for Windows (Debian 13), Xcode clang on macOS.
  `README.provenance` in the payload records this.
- Rebuild: `tools/fromsource.sh --revision 1 arm-none-eabi-gcc 14.2.0 out` (build run 45975474963).
  Known limitation: the Windows payload is not yet byte-reproducible (design record 8.4).
- `--with-multilib-list=rmprofile` (29 rows) is part of the ABI with the C library packages.

## Verification

linux x86_64, isolated home, xlings 2026.11.16.1: install, `--version` (14.2.0 / ld 2.43.1),
29 multilibs, freestanding cortex-m0 link with `-lgcc`, C/C++ links and qemu runs with both
sibling sysroots, reinstall no-op, remove, remove again. Not run: aarch64, Windows, macOS.

## Revision log

- 2026-11-27 — added at 14.2.0 revision 1 (floor 1): revision 0 (no sysroot C++ headers,
  limits.h not reaching the C library's) existed only in the building repository's own index.
