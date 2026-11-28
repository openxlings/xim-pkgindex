# goreleaser

GoReleaser (`goreleaser`) is a release automation CLI for Go and other languages. Status: `stable`.

- Upstream: https://github.com/goreleaser/goreleaser (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also ships `Darwin_all` (universal), `Linux_armv7/i386/loong64/ppc64/riscv64`, and `Windows_i386`, which are omitted to match the index's `x86_64`/`aarch64` matrix and avoid downloading universal double-fat archives on macOS.

## Source

- Tier: upstream official repository release (`goreleaser/goreleaser` GitHub Releases)
- GLOBAL:
  - `linux`: `https://github.com/goreleaser/goreleaser/releases/download/v${version}/goreleaser_Linux_${arch_alias}.tar.gz`
  - `macosx`: `https://github.com/goreleaser/goreleaser/releases/download/v${version}/goreleaser_Darwin_${arch_alias}.tar.gz`
  - `windows`: `https://github.com/goreleaser/goreleaser/releases/download/v${version}/goreleaser_Windows_${arch_alias}.zip`
  (`x86_64 -> x86_64`, `aarch64 -> arm64`)
- CN: none yet (`ci = { mirror = true }`, CI mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: verified all 6 SHA256s against upstream `checksums.txt` and downloaded bytes of `v2.20.3`
- Auto-update: yes (`extensions.autoupdate` configured with `${tag}` for all 6 platform/arch targets)

## Linking

- `linux/x86_64` & `linux/aarch64`: static Go ELF executables (`readelf -d` reports no dynamic section; `ldd` reports not a dynamic executable). Declares no runtime dependencies.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit PIE executables.
- `windows/x86_64` & `windows/aarch64`: PE32+ console executables importing `kernel32.dll` only.

## What the hooks do

- `installed`: checks via `payload.present` for all 7 archive files (`goreleaser`/`goreleaser.exe`, `LICENSE.md`, `README.md`, `completions/goreleaser.{bash,fish,zsh}`, `manpages/goreleaser.1.gz`).
- `install`: clears `pkginfo.install_dir()` and extracts the flat upstream archive directly into it (`tar -xzf` + `chmod +x` on POSIX; `payload.unpack{}` via `System32\tar.exe` on Windows) so shared `runtimedir` files from other flat archives cannot leak into the payload, then asserts all 7 files with `payload.require`.
- `config`: registers `goreleaser` with `xvm.add("goreleaser", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `goreleaser` via `xvm.remove("goreleaser")`.
- System impact: none (no shell profile, `PATH`, or host package manager changes).

## Verification

- Verified `linux/x86_64` lifecycle and functional execution (`goreleaser --version`, `goreleaser check` on valid and invalid configs) in an isolated `XLINGS_HOME` & `HOME`, plus `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`) and CI lints.
- Not run locally: `linux/aarch64`, `macosx`, and `windows` runtime execution (host is `linux/x86_64`; their archives, checksums, ELF/Mach-O/PE types, and Windows hook logic in Lua were verified locally).

## Revision log

- 2026-11-26 — added at `2.20.3`: initial spec-2 recipe covering `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`).
