# gojq

Pure Go implementation of `jq` (`itchyny/gojq`), `status = "stable"`.

- Upstream: https://github.com/itchyny/gojq (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Covers all 6 upstream release assets for `v0.12.20`.

## Source

- Tier: upstream GitHub release (`itchyny/gojq`)
- GLOBAL:
  - `linux`: `https://github.com/itchyny/gojq/releases/download/v${version}/gojq_v${version}_linux_${arch_alias}.tar.gz`
  - `macosx`: `https://github.com/itchyny/gojq/releases/download/v${version}/gojq_v${version}_darwin_${arch_alias}.zip`
  - `windows`: `https://github.com/itchyny/gojq/releases/download/v${version}/gojq_v${version}_windows_${arch_alias}.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified locally via `sha256sum` against all 6 archives downloaded from `itchyny/gojq` release `v0.12.20`.
- Auto-update: yes (`extensions.autoupdate` using `${tag}`).

## Linking & Archive Layout

- Archive layout: all 6 archives pack a single top-level wrapper directory matching the archive stem (`gojq_v0.12.20_<os>_<arch>/`) containing `gojq` (or `gojq.exe` on Windows), `LICENSE`, `README.md`, `CHANGELOG.md`, `CREDITS`, and `_gojq`.
- `linux/x86_64`, `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d` reports no `.dynamic` section; `ldd` reports not a dynamic executable). Zero runtime dependencies declared.
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64`, `windows/aarch64`: PE32+ console executables (`0x8664`, `0xaa64`) importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`). Zero runtime dependencies declared.

## What the hooks do

- `installed`: checks `payload.present({ "gojq", "LICENSE" })` or `payload.present({ "gojq.exe", "LICENSE" })`.
- `install`: detects Windows via path/environment (never by `.zip`, since macOS also ships `.zip`), unpacks the wrapper directory `gojq_v<version>_<os>_<arch>/` via `payload.unpack` (or `unzip`/`tar` fallback on POSIX when not pre-extracted) into `pkginfo.install_dir()`, runs `chmod +x` on Unix, and verifies `gojq`/`gojq.exe` and `LICENSE` exist.
- `config`: registers `gojq` via `xvm.add("gojq", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `gojq` via `xvm.remove("gojq")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation checks: `pytest tests/g/test_gojq.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `python3 tools/xpkg_ci.py inspect --only gojq`.
- Isolated `HOME=/tmp/xlings-gojq XLINGS_HOME=/tmp/xlings-gojq` (`linux/x86_64`): `xlings config --add-xpkg pkgs/g/gojq.lua`, `xlings search gojq`, `xlings install local:gojq -y`, `gojq --version`, `echo '{"a":1,"b":[2,3]}' | gojq -c '.b[]'`, `xlings remove local:gojq -y`, and `pytest tests/g/test_gojq.py -m "index or lifecycle or verify" -v`.
- Not run locally: `linux/aarch64`, `macosx`, and `windows` runtime installs (covered by CI; binary SHA256s, archive layouts, ELF dynamic sections, Mach-O headers, and PE imports verified locally for all 6 assets).

## Revision log

- 2026-11-26 — added at `0.12.20`: initial `spec = "2"` recipe covering all 6 upstream targets (`linux` `.tar.gz`, `macosx` `.zip`, `windows` `.zip` x `x86_64`/`aarch64`).
