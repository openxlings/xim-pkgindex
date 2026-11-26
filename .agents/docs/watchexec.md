# watchexec

Executes commands in response to file modifications. Provides the `watchexec` CLI command; status `stable`.

- Upstream: <https://github.com/watchexec/watchexec> (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because `watchexec.exe` imports `VCRUNTIME140.dll` and `xim:vcruntime` currently ships `x86_64` DLLs only.

## Source

- Tier: official repository release (`watchexec/watchexec`, tag `v2.8.0`)
- GLOBAL: `https://github.com/watchexec/watchexec/releases/download/${tag}/watchexec-${version}-<triple>.(tar.xz|zip)`
- CN: none yet (`ci = { mirror = true }` declared; a maintainer/mirror job handles `xlings-res`)
- Checksums: verified against upstream `SHA256SUMS`, per-asset `.sha256` sidecars, and computed `sha256sum` on downloaded assets for all covered targets (plus `aarch64-pc-windows-msvc.zip`).
- Auto-update: yes (`extensions.autoupdate`, GitHub releases with `v`-prefixed tags `${tag}` / `${version}`).

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -d`: no `DT_NEEDED` or `PT_INTERP`; `ldd`: `statically linked`). Declares no `xim:glibc` or `xim:gcc-runtime`.
- `linux/aarch64`: statically linked musl ELF (`readelf -d`: no dynamic section or `PT_INTERP`; `ldd`: `not a dynamic executable`). Declares no `xim:glibc` or `xim:gcc-runtime`.
- `windows/x86_64`: PE32+ x86-64 importing `VCRUNTIME140.dll` and Windows UCRT/system DLLs. Declares runtime dependency `xim:vcruntime` and copies its DLLs app-local beside `watchexec.exe`.

## What the hooks do

- install: unpacks `watchexec-<version>-<triple>` (running `tar -xJf` first on POSIX if xlings did not pre-extract `.tar.xz`), moves the payload into `pkginfo.install_dir()` via `payload.unpack`, sets executable permission on `watchexec`, copies `xim:vcruntime` DLLs app-local on Windows, and asserts `watchexec` / `watchexec.exe` via `payload.require`.
- config: registers `watchexec` with `xvm.add("watchexec", { bindir = pkginfo.install_dir() })`.
- uninstall: removes the `watchexec` xvm registration with `xvm.remove("watchexec")`.
- System impact: none; stays completely inside the isolated `XLINGS_HOME`.

## Verification

- Verified locally on `linux/x86_64` in an isolated `XLINGS_HOME`: `watchexec --version`, functional run, `xlings list`, `xlings remove`, `dep-closure-check.sh`, `lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect/materialize`, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not executed locally: `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64` runtime installs (covered by GitHub Actions CI after PR creation; `macosx/x86_64` is resource-verified).

## Revision log

- 2026-11-26 — added at `2.8.0`: official musl static builds on Linux, Darwin tarballs on macOS, MSVC zip with `xim:vcruntime` on Windows `x86_64`.
