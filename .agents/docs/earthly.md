# earthly

Super simple build framework with fast, repeatable builds using Earthfiles (`earthly` CLI, status `stable`).

- Upstream: https://github.com/earthly/earthly (MPL-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is not covered because upstream does not publish a `windows-arm64` asset.

## Source

- Tier: upstream release (`earthly/earthly` on GitHub Releases, raw single-file binaries)
- GLOBAL: `https://github.com/earthly/earthly/releases/download/v${version}/earthly-<os>-${arch_alias}[.exe]`
- CN: none yet (`ci = { mirror = true }` triggers maintainer mirroring to `xlings-res`)
- Checksums: matched upstream `checksum.asc`, GitHub Release asset digests, and `sha256sum` of downloaded bytes for all 5 assets of `v0.8.16`
- Auto-update: yes (`extensions.autoupdate` tracking `https://github.com/earthly/earthly/releases`)

## Linking

- `linux/x86_64` and `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). Declares no `deps.runtime`.
- `windows/x86_64`: PE32+ console executable importing `kernel32.dll` only.
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables.

## What the hooks do

- `install()`: moves `pkginfo.install_file()` to `<install_dir>/earthly` (or `earthly.exe` on Windows) and `chmod +x` on POSIX.
- `config()`: registers `earthly` via `xvm.add("earthly", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `earthly` via `xvm.remove("earthly")`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Direct isolated verification on `linux/x86_64` (`HOME=/tmp/xlings-earthly XLINGS_HOME=/tmp/xlings-earthly`): `xlings config --add-xpkg pkgs/e/earthly.lua`, `xlings search earthly`, `xlings install earthly@0.8.16 -y`, `earthly --version`, `earthly --help`, `xlings list earthly`, idempotent re-install, `xlings remove earthly -y`, idempotent re-remove, `xlings config --remove-xpkg earthly`.
- Pytest: `static`, `isolation`, `index`, `lifecycle`, `verify` on `linux/x86_64`.
- Not run locally: `linux/aarch64`, `macosx`, and `windows` live installs (covered by CI; binaries inspected via `file`, `readelf -d`, and PE import table).

## Revision log

- 2026-11-26 — added at `0.8.16`: initial spec-2 xpkg with `ci = { mirror = true }` and `extensions.autoupdate`.
