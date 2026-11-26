# gitui

Blazing fast terminal UI for git written in Rust. Provides the `gitui` command (`status = "stable"`).

- Upstream: <https://github.com/gitui-org/gitui> (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64` via `gitui-mac-x86.tar.gz`, `aarch64` via `gitui-mac.tar.gz`), `windows` (`x86_64` via `gitui-win.tar.gz`). `windows/aarch64` is omitted because upstream publishes no Windows ARM64 asset and `xim:vcruntime` is `x86_64`-only.

## Source

- Tier: upstream release
- GLOBAL:
  - `https://github.com/gitui-org/gitui/releases/download/v${version}/gitui-linux-${arch}.tar.gz`
  - `https://github.com/gitui-org/gitui/releases/download/v${version}/gitui-${arch_alias}.tar.gz` (`mac-x86` / `mac` / `win`)
- CN: none yet (will be mirrored to `xlings-res` via `ci = { mirror = true }`)
- Checksums: verified against GitHub release asset digests for `v0.28.1` and local `sha256sum` computations on all five archives (`gitui-linux-x86_64.tar.gz`, `gitui-linux-aarch64.tar.gz`, `gitui-mac-x86.tar.gz`, `gitui-mac.tar.gz`, `gitui-win.tar.gz`).
- Auto-update: yes (`extensions.autoupdate` tracking `https://github.com/gitui-org/gitui/releases`)

## Linking

- `linux/x86_64`: `static-pie linked` musl ELF with no `PT_INTERP` and zero `DT_NEEDED` entries.
- `linux/aarch64`: dynamically linked ELF (`INTERP /lib/ld-linux-aarch64.so.1`) with `DT_NEEDED` `[libgcc_s.so.1, libpthread.so.0, libm.so.6, libdl.so.2, libc.so.6]` and max symbol versions `GCC_4.2.0` / `GLIBC_2.28`. `xpm.linux.deps.runtime` declares `{ "xim:glibc@>=2.39", "xim:gcc-runtime" }` so `linux/aarch64` has its full closure sealed via `elfpatch`.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit `x86_64` and `arm64` executables respectively (verified via `file`).
- `windows/x86_64`: PE32+ console x86-64 importing `VCRUNTIME140.dll`, UCRT API-set DLLs, and Windows system DLLs; `xpm.windows.deps.runtime` declares `{ "xim:vcruntime" }` and `install()` copies CRT DLLs app-local beside `gitui.exe`.
- CLI probe safety: `gitui /? </dev/null` exits immediately with code 2 (`error: unexpected argument '/?' found`) without entering the TUI.

## What the hooks do

- `install`: extracts the flat `.tar.gz` directly into `pkginfo.install_dir()` (`System32\tar.exe -xzf` on Windows, `tar -xzf` on POSIX) so flat files cannot mix in the shared `runtimedir`; falls back to moving a pre-extracted binary. On Windows copies `xim:vcruntime` DLLs beside `gitui.exe`; on POSIX sets `+x`. Asserts payload presence with `payload.require`.
- `config`: registers `gitui` via `xvm.add("gitui", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `gitui` via `xvm.remove("gitui")`.
- System impact: none outside `pkginfo.install_dir()` and the subos `xvm` shim.

## Verification

- Inspected all five `v0.28.1` release binaries locally (`sha256sum`, `file`, `readelf -d/-V/-l`, `objdump -p`, `gitui --version`, `gitui /?`, `gitui --help`).
- Verified in an isolated `XLINGS_HOME` on `linux/x86_64` (direct `xlings` install/run/remove, `dep-closure-check.sh`, `pytest`, repo lints, and `tools/xpkg_ci.py inspect --only gitui`).
- `linux/aarch64`, `macosx`, and `windows` runtime installs were not executed locally (no local hardware for those targets) and are verified by CI.

## Revision log

- 2026-11-26 — added at 0.28.1: initial spec-2 package covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
