# lefthook

Lefthook (`lefthook`) is a fast and powerful Git hooks manager for any type of project (`status = "stable"`).

- Upstream: https://github.com/evilmartians/lefthook (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (GitHub Releases of `evilmartians/lefthook`)
- GLOBAL:
  - `linux`: `https://github.com/evilmartians/lefthook/releases/download/v${version}/lefthook_${version}_Linux_${arch_alias}.gz` (`x86_64` / `arm64`)
  - `macosx`: `https://github.com/evilmartians/lefthook/releases/download/v${version}/lefthook_${version}_MacOS_${arch_alias}.gz` (`x86_64` / `arm64`)
  - `windows`: `https://github.com/evilmartians/lefthook/releases/download/v${version}/lefthook_${version}_Windows_${arch_alias}.exe` (`x86_64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `lefthook_checksums.txt` from the `v2.2.3` release; all 6 downloaded assets matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

- Linux (`x86_64` and `aarch64`): statically linked Go ELF executables (`file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports not a dynamic executable). Zero `DT_NEEDED` entries (`xim:glibc` is not declared).
- Windows (`x86_64` and `aarch64`): PE32+ console binaries importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`), so `xim:vcruntime` is not declared.

## What the hooks do

- `install`: on Windows, moves the downloaded raw `.exe` (`pkginfo.install_file()`) to `pkginfo.install_dir()/lefthook.exe`; on Linux/macOS, decompresses the `.gz` single-file binary with `gzip -dc` into `pkginfo.install_dir()/lefthook` (or moves a pre-decompressed binary if present) and runs `chmod +x`; then verifies the binary with `payload.require(...)`.
- `config`: registers `lefthook` via `xvm.add("lefthook", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `lefthook` via `xvm.remove("lefthook")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/l/test_lefthook.py`, repo-wide `static or isolation`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect --only lefthook` / `materialize` run on Linux `x86_64`.
- Isolated `HOME=/tmp/xlings-lefthook XLINGS_HOME=/tmp/xlings-lefthook` `xlings` install/verify/remove and `pytest tests/l/test_lefthook.py -m "index or lifecycle or verify"` run on Linux `x86_64`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (verified via Lua hook unit mocks, checksums, Mach-O/ELF/PE inspection; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at `2.2.3`: initial packaging using `.gz` compressed binaries on POSIX and raw `.exe` binaries on Windows.
