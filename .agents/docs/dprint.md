# dprint

Pluggable and configurable code formatting platform that unifies all your formatters. Provides the `dprint` command (`status = "stable"`).

- Upstream: https://github.com/dprint/dprint (MIT)
- Homepage / Docs: https://dprint.dev / https://dprint.dev/overview/
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`)

## Source

- Tier: upstream release (`dprint/dprint`)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/dprint/dprint/releases/download/${tag}/dprint-x86_64-unknown-linux-musl.zip`
  - `linux/aarch64`: `https://github.com/dprint/dprint/releases/download/${tag}/dprint-aarch64-unknown-linux-musl.zip`
  - `macosx/x86_64`: `https://github.com/dprint/dprint/releases/download/${tag}/dprint-x86_64-apple-darwin.zip`
  - `macosx/aarch64`: `https://github.com/dprint/dprint/releases/download/${tag}/dprint-aarch64-apple-darwin.zip`
  - `windows/x86_64`: `https://github.com/dprint/dprint/releases/download/${tag}/dprint-x86_64-pc-windows-msvc.zip`
  - `windows/aarch64`: `https://github.com/dprint/dprint/releases/download/${tag}/dprint-aarch64-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`; CI will mirror GLOBAL assets to `xlings-res`)
- Checksums: all 6 SHA256 digests matched upstream `SHASUMS256.txt`, GitHub release asset digests, and locally downloaded `.zip` archives at `0.65.0`
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/dprint/dprint/releases`, `GLOBAL` only)

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -l`: no `PT_INTERP`; `readelf -d`: zero `DT_NEEDED`; `ldd`: `statically linked`). No `xim:glibc` or `xim:gcc-runtime` dependency needed.
- `linux/aarch64`: statically linked musl ELF (`readelf -l`: no `PT_INTERP`; `readelf -d`: no `.dynamic` section, zero `DT_NEEDED`). No `xim:glibc` or `xim:gcc-runtime` dependency needed.
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`, `windows/aarch64`: PE32+ executables statically linking the MSVC CRT; import table and delay-load import table contain only Windows OS system DLLs (`bcryptprimitives.dll`, `kernel32.dll`, `advapi32.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `shell32.dll`, `ntdll.dll`, `bcrypt.dll`, `USER32.dll`, plus delay-loaded `pdh.dll`, `powrprof.dll`, `psapi.dll`, `combase.dll`, `oleaut32.dll`, `crypt32.dll`, `ws2_32.dll`), with no `VCRUNTIME140.dll` or `MSVCP140.dll`. No `xim:vcruntime` dependency needed.

## What the hooks do

- `installed()`: checks `payload.present({ "dprint" })` or `payload.present({ "dprint.exe" })`.
- `install()`: upstream archives are flat `.zip` files containing a single `dprint` / `dprint.exe` binary. On Windows, unpacks directly into `pkginfo.install_dir()` via `payload.unpack{}` (`%SystemRoot%\System32\tar.exe`) with fallback move from the download directory. On POSIX (`linux`/`macosx`), unpacks directly into `pkginfo.install_dir()` via `shell.exec({ "unzip", "-q", "-o", archive, "-d", dir })` (with fallback move from the download directory) and sets executable permission with `chmod +x`. Asserts payload presence with `payload.require({ exe })`.
- `config()`: registers `dprint` (`bindir = pkginfo.install_dir()`) with `xvm`.
- `uninstall()`: removes `dprint` from `xvm`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`local:dprint@0.65.0`): `xlings search dprint`, `xlings install local:dprint@0.65.0 -y`, `dprint --version`, `dprint --help`, `dprint license`, `dprint /?` (exits cleanly with code 10 without blocking), `xlings list dprint`, idempotent re-install, `xlings remove dprint -y`, idempotent re-remove, `xlings config --remove-xpkg dprint`, and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows` (`x86_64`/`aarch64`) installs (no local ARM64/macOS/Windows hosts; all 6 archives downloaded, SHA256s verified, and ELF/Mach-O/PE headers inspected).

## Revision log

- 2026-11-26 — added at `0.65.0`.
