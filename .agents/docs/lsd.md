# lsd

The next gen `ls` command (`lsd`, `status = "stable"`).

- Upstream: https://github.com/lsd-rs/lsd (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream does not publish an `aarch64-pc-windows-msvc` archive and `xim:vcruntime` currently covers `x86_64` only.

## Source

- Tier: upstream release (`lsd-rs/lsd`)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-x86_64-unknown-linux-musl.tar.gz`
  - `linux/aarch64`: `https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-aarch64-unknown-linux-musl.tar.gz`
  - `macosx/x86_64`: `https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-x86_64-apple-darwin.tar.gz`
  - `macosx/aarch64`: `https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-aarch64-apple-darwin.tar.gz`
  - `windows/x86_64`: `https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-x86_64-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`; CI will mirror GLOBAL assets to `xlings-res`)
- Checksums: local `sha256sum` verified across all 5 downloaded archives at `v1.2.0`
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/lsd-rs/lsd/releases`, `GLOBAL` only)

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -l`: no `PT_INTERP`; `ldd`: `statically linked`). No runtime deps needed.
- `linux/aarch64`: static musl ELF (`readelf -l`: no `PT_INTERP`; `readelf -d`: no dynamic section). No runtime deps needed.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit executables.
- `windows/x86_64`: PE32+ console x86-64 binary importing `VCRUNTIME140.dll`, UCRT API sets (`api-ms-win-crt-*.dll`), `kernel32.dll`, `advapi32.dll`, `ntdll.dll`, `ole32.dll`, `bcryptprimitives.dll`, `Secur32.dll`, `shell32.dll`, and `ws2_32.dll`; declares `xim:vcruntime` runtime dep and copies CRT DLLs app-local beside `lsd.exe`.

## What the hooks do

- `installed()`: `payload.present({ "lsd" }) or payload.present({ "lsd.exe" })`.
- `install()`: archives extract into `lsd-v<ver>-<target>/`. Calls `payload.unpack{ extracted = stem, strip = 1 }`, copies `xim:vcruntime` DLLs beside `lsd.exe` on Windows, and verifies the binary with `payload.require`.
- `config()`: registers `lsd` (`bindir = pkginfo.install_dir()`) with `xvm`.
- `uninstall()`: removes `lsd` from `xvm`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`/tmp/xlings-lsd`): `xlings config --add-xpkg`, `xlings search`, `xlings install local:lsd@1.2.0 -y`, `lsd --version`, directory listing, `xlings remove`, and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` installs (no local ARM64/macOS/Windows hosts; all 5 archives were downloaded, SHA256s verified, and ELF/PE/Mach-O headers inspected).

## Revision log

- 2026-11-26 — added at `1.2.0`.
