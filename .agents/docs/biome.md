# biome

Fast formatter and linter for web projects (`biomejs/biome`), providing the `biome` CLI (`status = "stable"`).

- Upstream: https://github.com/biomejs/biome (MIT OR Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`; Windows ARM64 install awaits `xim:vcruntime` ARM64 CRT support)

## Source

- Tier: official repository release (`biomejs/biome`, monorepo tag `@biomejs/biome@${version}`)
- GLOBAL: `https://github.com/biomejs/biome/releases/download/@biomejs/biome@${version}/biome-<target>`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: matched GitHub Release asset digests and SHA256 computed on all 8 downloaded release binaries at `@biomejs/biome@2.6.9`
- Auto-update: yes (`extensions.autoupdate` with `tag = "@biomejs/biome@${version}"` and `${tag}` URLs, filtering out sibling monorepo tags like `@biomejs/js-api@*`)

## Linking

- Linux (`x86_64`, `aarch64`): uses official `-musl` raw binaries (`biome-linux-x64-musl` static-pie ELF with no `PT_INTERP` or `DT_NEEDED`; `biome-linux-arm64-musl` statically linked ELF with no dynamic section). No `xim:glibc` or `xim:gcc-runtime` dependency required (the non-musl GNU binaries link `libgcc_s.so.1`, `libpthread.so.0`, `libm.so.6`, `libdl.so.2`, `libc.so.6`).
- macOS (`x86_64`, `aarch64`): Mach-O 64-bit executables.
- Windows (`x86_64`, `aarch64`): PE32+ executables importing `VCRUNTIME140.dll` and UCRT (`api-ms-win-crt-*`); declares `deps = { runtime = { "xim:vcruntime" } }` and copies CRT DLLs beside `biome.exe` during `install()`.

## What the hooks do

- install: moves `pkginfo.install_file()` to `<install_dir>/biome` (or `biome.exe`), copies `xim:vcruntime` DLLs on Windows, runs `chmod +x` on Unix, verifies target file exists.
- config: `xvm.add("biome", { bindir = pkginfo.install_dir() })`.
- uninstall: `xvm.remove("biome")`.
- System impact: none (isolated inside `pkginfo.install_dir()` and xvm shim).

## Verification

- Local Linux x86_64: static, isolation, index, lifecycle/verify (`biome --version`, `biome format --write`, `biome check`), repo-wide static checks, `autoupdate-ci.py audit`, `xpkg_ci.py inspect`.
- Not run locally: macOS (`x86_64`, `aarch64`), Linux `aarch64`, Windows (`x86_64`, `aarch64`) runtime installs (covered by PR CI runners for `linux`, `macosx`, `windows`).

## Revision log

- 2026-11-25 — added at `2.6.9`.
