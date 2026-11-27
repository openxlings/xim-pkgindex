# libstdcxx-newlib-arm-none-eabi

libstdc++ and libsupc++ of GCC 14.2.0 (full and `_nano`) for every multilib of
`ZheFeng7110:arm-none-eabi-gcc`, built against newlib 4.5.0.20241231, **in one complete sysroot
that also carries that newlib** (`--sysroot=<prefix>/arm-none-eabi`). No commands. Status: dev.

- Upstream: https://gcc.gnu.org/onlinedocs/libstdc++/ (GPL-3.0-or-later WITH GCC-exception-3.1)
  and newlib's licenses
- Namespace: `ZheFeng7110` (unofficial, see "Provenance")
- Platforms: one host-independent archive, declared for linux, macosx and windows.

## Naming

The name carries the C library (`newlib`) and the version is the compiler's (14.2.0): libstdc++ is
part of GCC and is built against one libc's headers. A picolibc variant would be
`libstdcxx-picolibc-arm-none-eabi`.

## Source

- Release `libstdcxx-newlib-arm-none-eabi-14.2.0` of
  https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc. CN: none (`ci = { mirror = true }`).
- Checksum: release `.sha256`, GitHub's digest and the downloaded bytes agree (`ead19549…aae4`).

## Layout

newlib-arm-none-eabi whole, plus `include/c++/14.2.0/` (per-multilib `bits/c++config.h`) and per
multilib `libstdc++.a libsupc++.a libstdc++_nano.a libsupc++_nano.a`. `nano.specs` maps
`-lstdc++` to `-lstdc++_nano`. Unlike Arm's build, `std::filesystem` works when the project
provides the POSIX calls (mkdir, getcwd, ...); without them it is a link error, not ENOSYS.

Needs arm-none-eabi-gcc 14.2.0 revision 1 or later (C++ headers looked for in the sysroot).

## What the hooks do

- install: move into place; assert every multilib row (C and C++ libraries, `c++config.h`) and
  the specs and headers.
- config / uninstall: umbrella xvm node only; nothing enters the SubOS include/lib path.

## Provenance

gcc-14.2.0.tar.xz (`a7b39bc6…3cc9`) and the newlib above, at 3fa7932 (run 45975474963):
`tools/fromsource.sh --data libstdcxx-newlib-arm-none-eabi 14.2.0 out`.

## Verification

linux x86_64, isolated home: `--specs=nano.specs` C++ link takes
`thumb/v7e-m+fp/hard/libstdc++_nano.a`, without it `libstdc++.a`; vector/string/sort programs run
under qemu mps2-an386 (nano) and mps2-an385 (full). Not run: other hosts.

## Revision log

- 2026-11-27 — added at 14.2.0.
