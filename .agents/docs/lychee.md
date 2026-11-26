# lychee

Fast, asynchronous link checker written in Rust (`lychee` CLI, status: `stable`).

- Upstream: <https://github.com/lycheeverse/lychee> (MIT / Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream publishes no Windows ARM64 release asset.

## Source

- Tier: official repository release (`lycheeverse/lychee`, tag `lychee-v0.24.2`)
- GLOBAL:
  - `linux`: `https://github.com/lycheeverse/lychee/releases/download/lychee-v${version}/lychee-${arch}-unknown-linux-musl.${ext}`
  - `macosx`: `https://github.com/lycheeverse/lychee/releases/download/lychee-v${version}/lychee-${arch}-apple-darwin.${ext}`
  - `windows`: `https://github.com/lycheeverse/lychee/releases/download/lychee-v${version}/lychee-${arch}-pc-windows-msvc.${ext}`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL to `xlings-res` after merge)
- Checksums: verified against upstream `.sha256` sidecar files, GitHub release asset `digest` fields, and local `sha256sum` on all 5 downloaded archives.
- Auto-update: yes (`extensions.autoupdate` with `tag = "lychee-v${version}"`).

## Linking

- `linux/x86_64` (`-musl`): static-pie ELF, zero `DT_NEEDED` entries, no `PT_INTERP`, `ldd`: `statically linked`.
- `linux/aarch64` (`-musl`): statically linked ELF, no dynamic section or `PT_INTERP`, `ldd`: `not a dynamic executable`. Zero runtime dependencies declared on Linux.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64` (`-msvc`): PE32+ console executable importing `VCRUNTIME140.dll`, Windows UCRT API sets (`api-ms-win-crt-*`), and Windows OS DLLs (`kernel32.dll`, `ws2_32.dll`, `bcrypt.dll`, `crypt32.dll`, etc.), with no delay-load imports. `xpm.windows.deps.runtime` declares `xim:vcruntime`, and `install()` copies its DLLs app-local beside `lychee.exe`.

## What the hooks do

- `installed()`: verifies `lychee` (POSIX) or `lychee.exe` (Windows) via `payload.present`.
- `install()`: extracts `lychee-<triple>` on POSIX with `tar -xzf` if not already pre-extracted, moves the stripped payload into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem, strip = 1 }`, runs `chmod +x` on POSIX via `xim.pkgindex.shell`, copies `xim:vcruntime` DLLs app-local on Windows, and asserts `lychee` (or `lychee.exe`) via `payload.require`.
- `config()`: registers `lychee` with `xvm.add("lychee", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `lychee` from xvm via `xvm.remove("lychee")`.
- System impact: none (no shell profile, `PATH`, or host files modified).

## Verification

- Locally verified on `linux/x86_64`:
  - `lychee --version` (`lychee 0.24.2`), `lychee /?` (exits 0 without blocking), `lychee --offline` on valid and broken local Markdown links.
  - Static & isolation tests (`pytest tests/l/test_lychee.py -m "static or isolation"`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `python3 tools/xpkg_ci.py inspect --only lychee`.
  - Isolated `HOME=/tmp/xlings-lychee XLINGS_HOME=/tmp/xlings-lychee` install (`local:lychee`), `pytest tests/l/test_lychee.py`, `dep-closure-check.sh`, and `xlings remove`.
- `linux/aarch64`, `macosx`, and `windows/x86_64` runtime installs are verified by CI runners (archives, digests, ELF linkage, and PE import tables verified locally).

## Revision log

- 2026-11-26 — added at `0.24.2` (`lychee-v0.24.2`): Linux `-musl` static builds, macOS `-apple-darwin`, Windows `x86_64-pc-windows-msvc` with `xim:vcruntime`.
