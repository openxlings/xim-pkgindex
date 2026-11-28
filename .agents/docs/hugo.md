# hugo

Hugo is a static site generator written in Go. Provides the `hugo` command (`status = "stable"`).

- Upstream: https://github.com/gohugoio/hugo (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`)

## Source

- Tier: upstream GitHub release (`gohugoio/hugo`)
- GLOBAL:
  - Linux: `https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_linux-{amd64,arm64}.tar.gz`
  - macOS: `https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_darwin-universal.pkg`
  - Windows: `https://github.com/gohugoio/hugo/releases/download/${tag}/hugo_${version}_windows-{amd64,arm64}.zip`
- CN: none yet (declares `ci = { mirror = true }`)
- Checksums: verified against upstream `hugo_0.170.1_checksums.txt` and computed SHA-256 of downloaded `0.170.1` release assets
- Auto-update: yes (`extensions.autoupdate`, `GLOBAL` required across all 6 platform/arch targets)

## Linking

- From `v0.170.0`, Hugo removed LibSass and the CGO-enabled `extended` build; standard `hugo` is the single unified build across all platforms.
- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables (`readelf -d` shows no `.dynamic` section, `readelf -l` shows no `INTERP`). No `xim:glibc` or `xim:gcc-runtime` dependency required.
- macOS (`x86_64`, `aarch64`): signed component `.pkg` (`xar` archive with gzipped `cpio` `Payload`) containing a universal Mach-O binary (`0xcafebabe`) with `arm64` (`0x100000c`) and `x86_64` (`0x1000007`) slices.
- Windows (`x86_64`, `aarch64`): Go PE executables (`0x8664`, `0xaa64`) importing `kernel32.dll` only (no `VCRUNTIME140.dll`).

## What the hooks do

- install:
  - Linux: extracts flat `.tar.gz` directly into `pkginfo.install_dir()` via `tar -xzf` + `chmod +x`
  - macOS: expands `.pkg` via `pkgutil --expand-full` into a temporary directory, moves `Payload/hugo` into `pkginfo.install_dir()`, removes the temp directory, and runs `chmod +x`
  - Windows: extracts flat `.zip` via `payload.unpack{}` (`System32\tar.exe`)
  - All platforms assert `payload.require({ exe })`
- config: registers `hugo` with `xvm.add("hugo", { bindir = pkginfo.install_dir() })` (plus `alias = "hugo.exe"` on Windows)
- uninstall: removes `hugo` via `xvm.remove("hugo")`
- System impact: none

## Verification

- Verified `linux/x86_64` locally in an isolated `XLINGS_HOME` (`xlings install`, `hugo version`, `hugo new site`, `tests/h/test_hugo.py`, `xlings remove`).
- `linux/aarch64`, `macosx/*`, and `windows/*` were not executed locally (verified via upstream `checksums.txt`, archive/pkg inspection, `readelf -d`/`-l` on `linux/aarch64`, Mach-O fat header check on `darwin-universal.pkg`, and PE import table inspection on `windows/*`).

## Revision log

- 2026-11-26 — added at `0.170.1`.
