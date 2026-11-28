# taplo

Taplo is a TOML toolkit written in Rust providing formatting, linting, LSP, and query CLI operations via the `taplo` command (`status = "stable"`).

- Upstream: https://github.com/tamasfe/taplo (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream `0.10.0` also publishes `linux/{x86,armv7,riscv64}` and `windows/x86`, which are omitted because `xim-pkgindex` does not declare or validate those architectures.

## Source

- Tier: upstream release (`tamasfe/taplo` GitHub Releases, tag `0.10.0`)
- GLOBAL:
  - Linux: `https://github.com/tamasfe/taplo/releases/download/${version}/taplo-linux-${arch}.gz`
  - macOS: `https://github.com/tamasfe/taplo/releases/download/${version}/taplo-darwin-${arch}.gz`
  - Windows: `https://github.com/tamasfe/taplo/releases/download/${version}/taplo-windows-${arch}.zip`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: upstream `0.10.0` publishes no checksum file or release asset digest; SHA-256 digests were computed directly from the downloaded assets and re-verified via `tools/xpkg_ci.py materialize`.
- Auto-update: yes (`extensions.autoupdate` tracking `https://github.com/tamasfe/taplo/releases` with `${tag}`). Taplo CLI releases use bare semver tags (`0.10.0`, `0.9.3`), while older library/npm tags such as `release-taplo-0.13.0` carry no CLI assets.

## Linking

- `linux/x86_64`: `ELF 64-bit LSB pie executable, x86-64, static-pie linked, stripped`; `readelf -d` shows only `BIND_NOW`/`PIE`/`RELA` self-relocation entries and zero `DT_NEEDED`; `readelf -l` has no `PT_INTERP`; `ldd` reports `statically linked`.
- `linux/aarch64`: `ELF 64-bit LSB executable, ARM aarch64, statically linked, stripped`; `readelf -d` shows no dynamic section; `readelf -l` has no `PT_INTERP`; `ldd` reports not a dynamic executable.
- `windows/x86_64` & `windows/aarch64`: PE32+ console executables importing only Windows OS DLLs (`KERNEL32.dll`, `ntdll.dll`, `bcrypt.dll`, `bcryptprimitives.dll`, `advapi32.dll`, `ws2_32.dll`, `api-ms-win-core-synch-l1-2-0.dll`); no `VCRUNTIME140.dll` import.
- No runtime dependencies (`deps`) are needed on any platform.

## What the hooks do

- `install`: on POSIX, decompresses the `.gz` asset into `<install_dir>/taplo` via `gzip -dc` (or moves a pre-extracted binary if present) and runs `chmod +x`; on Windows, unpacks the flat `.zip` via `payload.unpack{}` into `<install_dir>/taplo.exe` (with pre-extracted fallback).
- `config`: registers `taplo` with `xvm.add("taplo", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `taplo` from xvm via `xvm.remove("taplo")`.
- System impact: none; writes only inside the package's own `install_dir` and xvm subos shims.

## Verification

- Static & isolation tests (`pytest tests/t/test_taplo.py -m "static or isolation"`): passed on Linux x86_64.
- Mirror precheck (`python3 tools/xpkg_ci.py inspect --only taplo`, `materialize taplo`, `verify`): passed for all 6 assets (`linux`, `macosx`, `windows` x `x86_64`/`aarch64`).
- Isolated `XLINGS_HOME` & `HOME` (`xlings config --add-xpkg pkgs/t/taplo.lua`, `xlings install local:taplo -y`, `taplo --version`, `taplo fmt --check`, `dep-closure-check.sh`, `pytest tests/t/test_taplo.py -m "index or lifecycle or verify"`, `xlings remove`): passed on Linux x86_64.
- Not run locally: macOS (`x86_64`, `aarch64`), Linux `aarch64`, and Windows (`x86_64`, `aarch64`) runtime installs (deferred to CI runners; macOS `x86_64` and Windows `aarch64` are resource-only in CI).

## Revision log

- 2026-11-26 — added at `0.10.0`: initial spec-2 recipe covering Linux, macOS, and Windows (`x86_64` and `aarch64`) with `ci = { mirror = true }` and `extensions.autoupdate`.
