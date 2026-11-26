# restic

Fast, secure, efficient backup program (`restic`), `status = "stable"`.

- Upstream: https://restic.net / https://github.com/restic/restic (BSD-2-Clause)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v0.20.0` publishes no Windows ARM64 asset (`windows_386.zip` and `windows_amd64.zip` only).

## Source

- Tier: upstream release (`https://github.com/restic/restic/releases`)
- GLOBAL: `restic_${version}_linux_{amd64,arm64}.bz2`, `restic_${version}_darwin_{amd64,arm64}.bz2`, `restic_${version}_windows_amd64.zip`
- CN: none yet (`ci = { mirror = true }` declared; `tools/xpkg_ci.py materialize restic` and `verify` succeed because raw `.bz2` assets are verified by SHA-256 while the Windows `.zip` passes `validate_archive`)
- Checksums: taken from upstream `SHA256SUMS` for `v0.20.0` and verified locally via `sha256sum -c --ignore-missing SHA256SUMS` across all five downloaded release assets.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- `linux/x86_64`, `linux/aarch64`: statically linked Go ELF executables (`readelf -d` reports `There is no dynamic section in this file.`; `PT_INTERP` absent; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- `windows/x86_64`: `restic_0.20.0_windows_amd64.exe` PE32+ console executable; `objdump -p` shows it imports only `kernel32.dll` (no `VCRUNTIME140.dll`, `MSVCP140.dll`, or MinGW DLL dependencies). Zero `runtime` dependencies declared.

## What the hooks do

- `install()`:
  - POSIX (`linux`, `macosx`): moves a pre-extracted binary if present, or decompresses the `.bz2` single-file release via `bunzip2 -c` into `pkginfo.install_dir()/restic`, sets `+x`, and asserts `restic` via `payload.require`.
  - `windows`: unpacks `restic_<version>_windows_<arch>.zip` via `payload.unpack{}` (using `%SystemRoot%\System32\tar.exe`) and renames `restic_<version>_windows_<arch>.exe` to `restic.exe`, asserting `restic.exe` via `payload.require`.
- `installed()`: checks `payload.present({ "restic" }) or payload.present({ "restic.exe" })`.
- `config()`: registers `restic` via `xvm.add("restic", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `restic` via `xvm.remove("restic")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` and `HOME`: `xlings self init`, `xlings config --add-xpkg`, `xlings search restic`, `xlings install local:restic -y`, `which restic`, `restic version`, `xlings list restic`, idempotent reinstall, `xlings remove local:restic -y` (shim removed), idempotent remove, and `xlings config --remove-xpkg restic`.
- Verified `python3 tools/xpkg_ci.py inspect --only restic`, `materialize restic`, and `verify` against all five upstream release assets.
- Verified `pytest tests/r/test_restic.py` across `static`, `isolation`, `index`, `lifecycle`, and `verify` (including an end-to-end `restic init` / `backup` / `snapshots --json` / `restore` round-trip), plus repo-wide static/isolation and `.github/scripts/check-*.sh` checks.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (x86_64 Linux host; Windows `.zip` and POSIX pre-extracted/.bz2 hook paths were covered by Lua sandbox unit tests, and CI validates Linux, macOS, and Windows).

## Revision log

- 2026-11-26 — added at 0.20.0: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
