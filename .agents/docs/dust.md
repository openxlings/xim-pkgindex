# dust

A more intuitive version of `du` written in Rust (`dust` CLI, `status = "stable"`).

- Upstream: https://github.com/bootandy/dust (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` (`dust-v1.2.8-aarch64-pc-windows-msvc.zip`) is omitted because its PE imports `VCRUNTIME140.dll` and `xim:vcruntime` currently covers `x86_64` only.

## Source

- Tier: upstream release (`bootandy/dust`)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-x86_64-unknown-linux-musl.tar.gz`
  - `linux/aarch64`: `https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-aarch64-unknown-linux-musl.tar.gz`
  - `macosx/x86_64`: `https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-x86_64-apple-darwin.tar.gz`
  - `macosx/aarch64`: `https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-aarch64-apple-darwin.tar.gz`
  - `windows/x86_64`: `https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-x86_64-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`; CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: GitHub release asset SHA256 digests matched local `sha256sum` across all downloaded archives at `v1.2.8`
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/bootandy/dust/releases`, `GLOBAL` only)

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -d`: zero `DT_NEEDED`, no `PT_INTERP`; `ldd`: `statically linked`). Declares zero runtime deps.
- `linux/aarch64`: statically linked musl ELF (`readelf -d`: no `.dynamic` section, zero `DT_NEEDED`; `ldd`: not a dynamic executable). Declares zero runtime deps.
- `windows/x86_64`: PE32+ x86-64 importing `VCRUNTIME140.dll`, UCRT API sets (`api-ms-win-crt-*-l1-1-0.dll`), `kernel32.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `ntdll.dll`, `bcryptprimitives.dll`, and `USERENV.dll`. Declares `xim:vcruntime` runtime dep and copies CRT DLLs app-local beside `dust.exe`.

## What the hooks do

- `installed()`: `payload.present({ "dust", "LICENSE" })` or `payload.present({ "dust.exe", "LICENSE" })`.
- `install()`: archives contain a single top-level directory `dust-v<ver>-<target>/`. Calls `payload.unpack{ extracted = stem, strip = 1 }`, copies `xim:vcruntime` DLLs into `pkginfo.install_dir()` on Windows, and verifies `dust` / `dust.exe` and `LICENSE` via `payload.require`.
- `config()`: registers `dust` (`bindir = pkginfo.install_dir()`) with `xvm`.
- `uninstall()`: removes `dust` from `xvm`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`local:dust@1.2.8`): `dust --version`, disk usage output on a test directory, `dep-closure-check.sh`, `xlings remove`, and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` installs (no local ARM64/macOS/Windows hosts; archives downloaded, SHA256s verified, and ELF/PE headers inspected).

## Revision log

- 2026-11-26 — added at `1.2.8`.
