# newlib-arm-none-eabi

newlib 4.5.0.20241231 and newlib-nano for every multilib of `zhefeng:arm-none-eabi-gcc`,
as a sysroot (`--sysroot=<prefix>/arm-none-eabi`). No commands; an umbrella xvm node. Status: dev.

- Upstream: https://sourceware.org/newlib/ (BSD-style collection; `COPYING.NEWLIB` and
  `COPYING.LIBGLOSS` in the payload are authoritative)
- Namespace: `zhefeng` (unofficial, see "Provenance"; lowercase letters only, as the index's install checks require)
- Platforms: one host-independent archive, declared for linux, macosx and windows.

## Source

- Built by https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc, release
  `newlib-arm-none-eabi-4.5.0.20241231`. CN: none (`ci = { mirror = true }`).
- Checksum: release `.sha256`, GitHub's digest and the downloaded bytes agree
  (`dc5fb473…bc19`).

## Layout

Arm GNU Toolchain's names and configure, so STM32CubeMX projects link unchanged:
`lib/{nano,nosys,rdimon}.specs`, `include/newlib-nano/newlib.h`, and per multilib `libc.a libm.a
libg.a libnosys.a librdimon.a crt0.o rdimon-crt0.o libc_nano.a libg_nano.a librdimon_nano.a`.
The multilib list must equal the compiler's (rmprofile, 29 rows): a library in the wrong row links
and is wrong only at run time. `install()` asserts every row.

Needs arm-none-eabi-gcc 14.2.0 revision 1 or later (limits.h reaching the C library's).

## What the hooks do

- install: move the archive's directory into place, assert every multilib row and the specs.
- config / uninstall: `xvm.add` / `xvm.remove` of the umbrella node only. Target headers never
  enter the SubOS include path (they would shadow the host libc).

## Provenance

newlib-4.5.0.20241231.tar.gz from sourceware.org (`33f12605…c852`), built by
fromsource:arm-none-eabi-gcc 14.2.0 at 3fa7932 (run 45975474963):
`tools/fromsource.sh --data newlib-arm-none-eabi 4.5.0.20241231 out`. The factory runs programs
under qemu mps2-an385/an386.

## Verification

linux x86_64, isolated home: install; CubeMX-style links take `thumb/v6-m/nofp/libc_nano.a` (m0)
and `thumb/v7e-m+fp/hard/libc_nano.a` (m4 hard, VFP-register ABI); printf/sqrt programs run under
qemu-system-arm mps2-an385 and mps2-an386 (nano + rdimon, full + rdimon). Not run: other hosts.

## Revision log

- 2026-11-27 — added at 4.5.0.20241231.
