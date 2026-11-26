# goose

Database migration tool supporting SQL migrations and Go functions; provides the `goose` CLI (`status`: `stable`).

- Upstream: https://github.com/pressly/goose (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). All 6 targets match upstream's published release assets.

## Source

- Tier: upstream official repository release (`pressly/goose` GitHub Releases)
- GLOBAL:
  - `linux`: `https://github.com/pressly/goose/releases/download/v${version}/goose_linux_${arch_alias}`
  - `macosx`: `https://github.com/pressly/goose/releases/download/v${version}/goose_darwin_${arch_alias}`
  - `windows`: `https://github.com/pressly/goose/releases/download/v${version}/goose_windows_${arch_alias}.exe`
- CN: none yet (`ci = { mirror = true }` requests CI mirroring to `xlings-res`)
- Checksums: SHA-256 digests from upstream `checksums.txt` in `v3.30.2`, verified against downloaded bytes for all 6 release assets and GitHub release digests.
- Auto-update: yes (`extensions.autoupdate` with `${tag}` in the GitHub release download URLs; upstream asset basenames are fixed without a version string).

## Linking

- `linux/x86_64` and `linux/aarch64`: ELF64 statically linked Go binaries (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Declares no runtime dependencies.
- `windows/x86_64` and `windows/aarch64`: PE32+ console executables importing `kernel32.dll` only (no `VCRUNTIME140.dll`). Declares no runtime dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables.

## What the hooks do

- `install`: clears `pkginfo.install_dir()`, creates it, moves the downloaded raw binary from `pkginfo.install_file()` to `<install_dir>/goose` (or `<install_dir>/goose.exe` on Windows), runs `chmod +x` on non-Windows payloads, and checks the target file exists.
- `config`: registers `goose` with `xvm.add("goose", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("goose")`.
- System impact: none; only writes inside the package store directory and xvm shim registration.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` and `HOME`: `xlings install local:goose -y`, `goose -version`, `goose -dir <tmp> create init_schema sql`, `xlings remove local:goose -y`, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: macOS (`x86_64`/`aarch64`), Linux `aarch64`, and Windows (`x86_64`/`aarch64`) live installs (checked SHA-256 checksums, ELF/Mach-O/PE headers, and PE imports instead).

## Revision log

- 2026-11-26 — added at 3.30.2: standalone raw binary distribution on all 6 platform/arch targets (`x86_64`/`aarch64` across `linux`/`macosx`/`windows`), static Go binaries with `ci = { mirror = true }` and `extensions.autoupdate`.
