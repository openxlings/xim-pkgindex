# dua

View disk space usage and delete unwanted data, fast (`dua` CLI, `status = "stable"`).

- Upstream: https://github.com/Byron/dua-cli (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` (`dua-v3.0.3-aarch64-pc-windows-msvc.zip`) is omitted because its PE imports `VCRUNTIME140.dll` and `xim:vcruntime` currently covers `x86_64` only.

## Source

- Tier: upstream release (`Byron/dua-cli`)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-x86_64-unknown-linux-musl.tar.gz`
  - `linux/aarch64`: `https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-aarch64-unknown-linux-musl.tar.gz`
  - `macosx/x86_64`: `https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-x86_64-apple-darwin.tar.gz`
  - `macosx/aarch64`: `https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-aarch64-apple-darwin.tar.gz`
  - `windows/x86_64`: `https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-x86_64-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`; CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: GitHub release asset SHA256 digests matched local `sha256sum` across all downloaded archives at `v3.0.3`
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/Byron/dua-cli/releases`, `GLOBAL` only)

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -d`: zero `DT_NEEDED`, no `PT_INTERP`; `ldd`: `statically linked`). Declares zero runtime deps.
- `linux/aarch64`: statically linked musl ELF (`readelf -d`: no `.dynamic` section, zero `DT_NEEDED`; `readelf -l`: no `PT_INTERP`). Declares zero runtime deps.
- `windows/x86_64`: PE32+ x86-64 importing `VCRUNTIME140.dll`, UCRT API sets (`api-ms-win-crt-*-l1-1-0.dll`), `kernel32.dll`, `ole32.dll`, `shell32.dll`, `oleaut32.dll`, `combase.dll`, `ntdll.dll`, `userenv.dll`, `bcryptprimitives.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `advapi32.dll`, and `USER32.dll`. Declares `xim:vcruntime` runtime dep and copies CRT DLLs app-local beside `dua.exe`.

## What the hooks do

- `installed()`: `payload.present({ "dua", "LICENSE" })` or `payload.present({ "dua.exe", "LICENSE" })`.
- `install()`: archives contain a single top-level directory `dua-v<ver>-<target>/`. Calls `payload.unpack{ extracted = stem, strip = 1 }`, copies `xim:vcruntime` DLLs into `pkginfo.install_dir()` on Windows, and verifies `dua` / `dua.exe` and `LICENSE` via `payload.require`.
- `config()`: registers `dua` (`bindir = pkginfo.install_dir()`) with `xvm`.
- `uninstall()`: removes `dua` from `xvm`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`local:dua@3.0.3`): `dua --version`, `dua aggregate` on a test directory, `xlings remove`, pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only dua`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` installs (no local ARM64/macOS/Windows hosts; archives downloaded, SHA256s verified, and ELF/PE headers inspected).

## Revision log

- 2026-11-26 — added at `3.0.3`.
