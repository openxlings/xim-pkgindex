# dasel

Dasel (`dasel`) provides unified querying, transformation, and modification of JSON, TOML, YAML, XML, INI, HCL, KDL, and CSV (`status = "stable"`).

- Upstream: https://github.com/TomWright/dasel (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream v3.11.2 also publishes `linux_386`, `linux_arm32`, and `windows_386` (outside `archs`), and publishes no `windows/aarch64` asset.

## Source

- Tier: upstream release (GitHub Releases of `TomWright/dasel`)
- GLOBAL (note unversioned asset filenames under `releases/download/v${version}/`):
  - `linux`: `https://github.com/TomWright/dasel/releases/download/v${version}/dasel_linux_${arch_alias}.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/TomWright/dasel/releases/download/v${version}/dasel_darwin_${arch_alias}.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/TomWright/dasel/releases/download/v${version}/dasel_windows_${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: all 5 downloaded release assets matched their `v3.11.2` GitHub Release SHA-256 digests (`sha256sum`).
- Auto-update: yes (`extensions.autoupdate` using `${tag}` with unversioned asset filenames).

## Linking

- Linux (`x86_64` and `aarch64`): statically linked Go ELF executables (`file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports not a dynamic executable). Zero `DT_NEEDED` entries (`xim:glibc` is not declared).
- Windows (`x86_64`): PE32+ console binary importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`), so `xim:vcruntime` is not declared.

## What the hooks do

- `install`: on Windows, moves the downloaded raw `.exe` (`pkginfo.install_file()`) to `pkginfo.install_dir()/dasel.exe`; on Linux/macOS, decompresses the `.gz` single-file binary with `gzip -dc` into `pkginfo.install_dir()/dasel` (or moves a pre-decompressed binary if present) and runs `chmod +x`; then verifies the binary with `payload.require(...)`.
- `config`: registers `dasel` via `xvm.add("dasel", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `dasel` via `xvm.remove("dasel")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/d/test_dasel.py`, repo-wide `static or isolation`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect --only dasel` / `materialize` run on Linux `x86_64`.
- Isolated `HOME=/tmp/xlings-dasel XLINGS_HOME=/tmp/xlings-dasel` `xlings` install/verify/remove and `pytest tests/d/test_dasel.py -m "index or lifecycle or verify"` run on Linux `x86_64`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime execution (verified via Lua hook unit mocks, checksums, Mach-O/ELF/PE inspection; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at `3.11.2`: initial packaging using `.gz` compressed binaries on POSIX and raw `.exe` binary on Windows (`x86_64`).
