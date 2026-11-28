# trippy

A network diagnostic tool combining traceroute and ping (binary: `trip`, status: `stable`).

- Upstream: https://github.com/fujiapple852/trippy (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` (`trippy-0.13.0-aarch64-pc-windows-msvc.zip`) is omitted because its PE imports `VCRUNTIME140.dll` while `xim:vcruntime` currently ships `x86_64` only.

## Source

- Tier: official repository release (`fujiapple852/trippy`)
- GLOBAL:
  - `linux`: `https://github.com/fujiapple852/trippy/releases/download/${version}/trippy-${version}-${arch}-unknown-linux-musl.tar.gz`
  - `macosx`: `https://github.com/fujiapple852/trippy/releases/download/${version}/trippy-${version}-${arch}-apple-darwin.tar.gz`
  - `windows`: `https://github.com/fujiapple852/trippy/releases/download/${version}/trippy-${version}-${arch}-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL to `xlings-res` after merge)
- Checksums: computed locally from all downloaded `0.13.0` release archives (`sha256sum`)
- Auto-update: yes (`extensions.autoupdate`, bare semver `${tag}`)

## Linking

- `linux/x86_64` (`-musl`): static-pie ELF, zero `DT_NEEDED` entries, `ldd`: `statically linked`.
- `linux/aarch64` (`-musl`): statically linked ELF, no dynamic section or `PT_INTERP`. Zero runtime dependencies declared.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64` (`-msvc`): PE32+ executable importing `VCRUNTIME140.dll`, UCRT API sets, and Windows OS DLLs (`kernel32.dll`, `IPHLPAPI.DLL`, `ws2_32.dll`, `user32.dll`, `advapi32.dll`, `ntdll.dll`, `bcrypt.dll`, `bcryptprimitives.dll`, `shell32.dll`, `ole32.dll`); declares `xim:vcruntime` runtime dep and copies CRT DLLs app-local beside `trip.exe`.

## What the hooks do

- `installed()`: `payload.present({ "trip" })` or `payload.present({ "trip.exe" })`.
- `install()`: every upstream archive wraps its binary inside `<archive-stem>/`. On POSIX `.tar.gz`, extracts via `xim.pkgindex.shell` if not already pre-extracted, moves into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem, strip = 1 }`, and runs `chmod +x`. On Windows `.zip`, unpacks via `payload.unpack{ extracted = stem, strip = 1 }` (`%SystemRoot%\System32\tar.exe`) and copies `xim:vcruntime` DLLs beside `trip.exe`, then asserts `trip`/`trip.exe` via `payload.require`.
- `config()`: registers `trip` (`bindir = pkginfo.install_dir()`) and `trippy` (`type = "group"`).
- `uninstall()`: removes both `trip` and `trippy` from `xvm`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `HOME`/`XLINGS_HOME`: `local:trippy@0.13.0` install, `trip --version`, `trip --help`, `trip /?` non-blocking check without `CAP_NET_RAW`, `trip --print-config-template`, `xlings remove`, and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`) plus repository static/policy scripts and `tools/xpkg_ci.py inspect --only trippy`.
- `linux/aarch64`, `macosx`, and `windows/x86_64` runtime installs are verified by CI runners (archives downloaded, SHA256s verified, and ELF/Mach-O/PE headers inspected locally).

## Revision log

- 2026-11-26 — added at `0.13.0`: initial package using Linux `-musl` static binaries, macOS `-apple-darwin`, Windows `x86_64-pc-windows-msvc` with `xim:vcruntime`, and `trip` + `trippy` group xvm registration.
