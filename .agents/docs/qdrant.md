# qdrant

High-performance, massive-scale vector database and vector search engine (`qdrant/qdrant`, `status = "stable"`).

- Upstream: <https://qdrant.tech> / <https://github.com/qdrant/qdrant> (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream `v1.20.2` publishes no Windows ARM64 asset (and `qdrant.exe` imports `VCRUNTIME140.dll`, while `xim:vcruntime` currently ships `x86_64` DLLs only).

## Source

- Tier: official repository release (`https://github.com/qdrant/qdrant/releases`, tag `v1.20.2`)
- GLOBAL:
  - `linux`: `https://github.com/qdrant/qdrant/releases/download/v${version}/qdrant-${arch}-unknown-linux-musl.tar.gz`
  - `macosx`: `https://github.com/qdrant/qdrant/releases/download/v${version}/qdrant-${arch}-apple-darwin.tar.gz`
  - `windows`: `https://github.com/qdrant/qdrant/releases/download/v${version}/qdrant-${arch}-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against GitHub release `v1.20.2` asset digests and computed `sha256sum` across all five downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- `linux/x86_64`: `static-pie linked` musl ELF (`readelf -d`: zero `DT_NEEDED` entries, no `PT_INTERP`; `ldd`: `statically linked`). Zero `runtime` dependencies declared.
- `linux/aarch64`: `statically linked` musl ELF (`readelf -d`: no dynamic section, no `PT_INTERP`). Zero `runtime` dependencies declared.
- `windows/x86_64`: PE32+ CUI `qdrant.exe` importing `VCRUNTIME140.dll` and Windows UCRT/system DLLs. Declares `deps = { runtime = { "xim:vcruntime" } }` on `windows` and copies `xim:vcruntime/bin/*.dll` app-local beside `qdrant.exe`.
- Windows CI probe safety: tested locally that `qdrant /?` exits immediately (code `2`, clap unexpected argument) without starting the server or creating `./storage`.

## What the hooks do

- install: Every upstream archive is flat at root (`qdrant` / `qdrant.exe`). On Windows, extracts via `payload.unpack{}` (`System32\tar.exe`) into `pkginfo.install_dir()` and copies `xim:vcruntime/bin` DLLs beside `qdrant.exe`. On POSIX, extracts directly from `pkginfo.install_file()` with `tar -xzf` (or moves a pre-extracted binary fallback), sets `+x`, and asserts `qdrant` / `qdrant.exe` via `payload.require`.
- config: Registers `qdrant` via `xvm.add("qdrant", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `qdrant` via `xvm.remove("qdrant")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally in an isolated `XLINGS_HOME` on Linux `x86_64`: `xlings config --add-xpkg`, `xlings search qdrant`, `xlings install qdrant@1.20.2 -y`, `qdrant --version`, `qdrant --help`, `qdrant /?`, HTTP server startup (`/healthz`, `/collections`), `xlings list qdrant`, idempotent reinstall, `xlings remove qdrant -y`, and `xlings config --remove-xpkg qdrant`.
- Verified static/isolation/index/lifecycle/verify pytest suites, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `.github/scripts/dep-closure-check.sh`, and `tools/xpkg_ci.py inspect --only qdrant` + `materialize`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (hooks validated via Lua sandbox tests; native execution delegated to CI).

## Revision log

- 2026-11-26 — added at `1.20.2`: official musl static builds on Linux, Darwin tarballs on macOS, MSVC zip with app-local `xim:vcruntime` on Windows `x86_64`.
