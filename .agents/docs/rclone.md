# rclone

Command-line program (`rclone`) to manage and synchronize files across cloud storage providers; status `stable`.

- Upstream: https://github.com/rclone/rclone (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream `.deb`/`.rpm` and non-desktop targets (`386`, `arm`, `bsd`, `plan9`, `solaris`, `aix`) are not included.

## Source

- Tier: upstream release (`rclone/rclone` GitHub Releases, `v1.76.0`)
- GLOBAL:
  - linux: `https://github.com/rclone/rclone/releases/download/v${version}/rclone-v${version}-linux-${arch_alias}.zip`
  - macosx: `https://github.com/rclone/rclone/releases/download/v${version}/rclone-v${version}-osx-${arch_alias}.zip` (upstream uses `osx` in macOS asset names)
  - windows: `https://github.com/rclone/rclone/releases/download/v${version}/rclone-v${version}-windows-${arch_alias}.zip`
- CN: none yet (maintainer mirror via `ci = { mirror = true }`)
- Checksums: upstream `SHA256SUMS` asset; all six `.zip` archives were downloaded and verified byte-for-byte with `sha256sum`.
- Auto-update: yes (`extensions.autoupdate`, using `${tag}` and `${version}`).

## Linking

- Linux `x86_64` & `aarch64`: statically linked Go ELF64 executables (`readelf -d` shows no `.dynamic` section, `ldd` reports not a dynamic executable). Zero runtime dependencies declared.
- Windows `x86_64` (`0x8664`) & `aarch64` (`0xaa64`): PE32+ executables importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`, so no `xim:vcruntime` dependency).

## What the hooks do

- install: Unpacks the single top-level directory (`rclone-v<ver>-<os>-<arch>/`) into `pkginfo.install_dir()` (Windows via `payload.unpack` / `System32\tar.exe`, POSIX via `payload.unpack` when pre-extracted or `unzip -q -o` with `tar` fallback, plus `chmod +x` on `rclone`) and requires `rclone`/`rclone.exe` and `rclone.1`.
- config: Registers `rclone` with `xvm.add("rclone", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `rclone` via `xvm.remove("rclone")`.
- System impact: none; self-contained inside `pkginfo.install_dir()` and the subos xvm shim.

## Verification

- Verified `rclone` `v1.76.0` checksums and binary linking on all six archives (`linux`, `macosx`, `windows` x `x86_64`, `aarch64`).
- Ran `pytest tests/r/test_rclone.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repository-wide static checks, `lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect`/`materialize`, and isolated `XLINGS_HOME` install/run/remove on `linux/x86_64`.
- `macosx` and `windows` runtime install/execution were not run locally (checked statically and covered by CI runners).

## Revision log

- 2026-11-26 — added at `1.76.0`: all-`.zip` release layout across Linux, macOS (`osx`), and Windows (`amd64`/`arm64`).
