# agg

Command-line tool for generating animated GIF files from asciinema recordings (`status = "stable"`).

- Upstream: https://github.com/asciinema/agg (GPL-3.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream does not publish a Windows ARM64 binary (and `xim:vcruntime` covers `x86_64` only).

## Source

- Tier: official repository release (`asciinema/agg` GitHub Releases)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/asciinema/agg/releases/download/v${version}/agg-x86_64-unknown-linux-musl`
  - `linux/aarch64`: `https://github.com/asciinema/agg/releases/download/v${version}/agg-aarch64-unknown-linux-gnu`
  - `macosx`: `https://github.com/asciinema/agg/releases/download/v${version}/agg-${arch}-apple-darwin`
  - `windows`: `https://github.com/asciinema/agg/releases/download/v${version}/agg-${arch}-pc-windows-msvc.exe`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against locally computed `sha256sum` across all five downloaded `v1.9.0` binaries.
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/asciinema/agg/releases`, `GLOBAL` only).

## Linking

- `linux/x86_64`: static-pie linked musl ELF (`readelf -d` shows no `PT_INTERP` and no `DT_NEEDED`).
- `linux/aarch64`: dynamic GNU ELF (upstream publishes no `aarch64-unknown-linux-musl` binary). `readelf -d` and `readelf -V` show `INTERP /lib/ld-linux-aarch64.so.1` and `NEEDED`: `libgcc_s.so.1`, `libpthread.so.0`, `libm.so.6`, `libdl.so.2`, `libc.so.6` (`GLIBC_2.17`/`2.18`, `GCC_3.0`/`3.3`/`4.2.0`). `xpm.linux.deps.runtime` declares `xim:glibc@>=2.39` and `xim:gcc-runtime@15.1.0`.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit executables.
- `windows/x86_64`: PE32+ x86-64 executable importing `VCRUNTIME140.dll` and UCRT API sets (`api-ms-win-crt-*.dll`), `api-ms-win-core-synch-l1-2-0.dll`, `bcryptprimitives.dll`, `KERNEL32.dll`, `WS2_32.dll`, `shell32.dll`, `combase.dll`, `crypt32.dll`, `ntdll.dll`. Declares `xim:vcruntime` runtime dependency and copies CRT DLLs app-local beside `agg.exe`.

## What the hooks do

- `installed()`: checks `agg` or `agg.exe` in `pkginfo.install_dir()`.
- `install()`: moves the downloaded raw binary `pkginfo.install_file()` to `<install_dir>/agg` (or `agg.exe` on Windows), runs `chmod +x` on Unix, copies `xim:vcruntime` DLLs beside `agg.exe` on Windows, and verifies the target file exists.
- `config()`: registers `agg` with `xvm.add("agg", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `agg` via `xvm.remove("agg")`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`local:agg@1.9.0`): `agg --version`, cast-to-GIF conversion, `dep-closure-check.sh`, `xlings remove`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect --only agg`, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` native installs (binaries downloaded, SHA256s verified, ELF/PE headers inspected, and Windows hook logic tested in Lua sandbox; CI exercises `linux`, `macosx/aarch64`, and `windows/x86_64`).

## Revision log

- 2026-11-26 — added at `1.9.0`.
