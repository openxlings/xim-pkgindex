# meilisearch

Lightning-fast full-text and hybrid search engine API. Provides the `meilisearch` command (`status = "stable"`).

- Upstream: https://github.com/meilisearch/meilisearch (MIT / OpenLDAP for LMDB connector)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream publishes no Windows ARM64 binary (and `xim:vcruntime` currently covers `x86_64` only). `linux/riscv64` is omitted because `riscv64` is not in the index's validated runner/arch matrix.

## Source

- Tier: upstream release (`meilisearch/meilisearch`, tag `v1.58.0`)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-linux-amd64`
  - `linux/aarch64`: `https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-linux-aarch64`
  - `macosx/x86_64`: `https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-macos-amd64`
  - `macosx/aarch64`: `https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-macos-apple-silicon`
  - `windows/x86_64`: `https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-windows-amd64.exe`
- CN: none yet (`ci = { mirror = true }`; CI will mirror GLOBAL assets to `xlings-res`)
- Checksums: GitHub release asset SHA256 digests matched local `sha256sum` across all five downloaded binaries at `1.58.0`
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/meilisearch/meilisearch/releases`, `GLOBAL` only)

## Linking

- `linux/x86_64`: dynamically linked PIE ELF (`readelf -l`: `INTERP /lib64/ld-linux-x86-64.so.2`; `readelf -d`: `NEEDED` `libgcc_s.so.1`, `libm.so.6`, `libc.so.6`, `ld-linux-x86-64.so.2`; `readelf -V`: max `GCC_4.2.0`, `GLIBC_2.39` weak / `GLIBC_2.38`).
- `linux/aarch64`: dynamically linked PIE ELF (`readelf -l`: `INTERP /lib/ld-linux-aarch64.so.1`; `readelf -d`: `NEEDED` `libgcc_s.so.1`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`; `readelf -V`: max `GCC_4.2.0`, `GLIBC_2.39`).
- `xpm.linux.deps.runtime` declares `xim:glibc@>=2.39` (resolves to `2.44.3` on both `x86_64` and `aarch64`) and `xim:gcc-runtime`.
- `windows/x86_64`: PE32+ importing `VCRUNTIME140.dll`, UCRT API sets (`api-ms-win-crt-*`), and Windows system DLLs; declares `xim:vcruntime` runtime dep and copies CRT DLLs app-local beside `meilisearch.exe`.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit `x86_64` and `arm64` executables.
- Program probe (`/?`): `meilisearch /?` exits immediately with exit code 2 (`unexpected argument '/?' found`) without launching the HTTP server.

## What the hooks do

- `installed()`: `payload.present({ "meilisearch" })` or `payload.present({ "meilisearch.exe" })`.
- `install()`: upstream distributes unarchived raw single-file binaries with distinct per-platform/arch names, so xlings skips extraction and passes the binary via `pkginfo.install_file()`. Moves the binary into `pkginfo.install_dir()` as `meilisearch` (or `meilisearch.exe` on Windows), copies `xim:vcruntime` DLLs beside `meilisearch.exe` on Windows, runs `chmod +x` on POSIX, and asserts payload presence with `payload.require`.
- `config()`: registers `meilisearch` (`bindir = pkginfo.install_dir()`) with `xvm`.
- `uninstall()`: removes `meilisearch` from `xvm`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME`: `xlings search`, `xlings install`, `meilisearch --version`, `GET /health` & `GET /version` HTTP smoke test, `dep-closure-check.sh`, `posix-test.sh`, `xlings remove`, and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` installs (no local ARM64/macOS/Windows hosts; all 5 upstream binaries downloaded, SHA256s verified, and ELF/PE/Mach-O headers inspected).

## Revision log

- 2026-11-26 — added at `1.58.0`.
