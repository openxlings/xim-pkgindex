# difftastic

Structural diff tool that compares files based on their syntax. Provides the `difft` command (`status = "stable"`).

- Upstream: https://github.com/Wilfred/difftastic (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` (`difft-0.72.0-aarch64-pc-windows-msvc.zip`) is omitted for now because its PE imports `VCRUNTIME140.dll` and `xim:vcruntime` currently covers `x86_64` only.

## Source

- Tier: upstream release (`Wilfred/difftastic`)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-x86_64-unknown-linux-musl.tar.gz`
  - `linux/aarch64`: `https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-aarch64-unknown-linux-gnu.tar.gz`
  - `macosx/x86_64`: `https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-x86_64-apple-darwin.tar.gz`
  - `macosx/aarch64`: `https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-aarch64-apple-darwin.tar.gz`
  - `windows/x86_64`: `https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-x86_64-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`; CI will mirror GLOBAL assets to `xlings-res`)
- Checksums: GitHub release asset SHA256 digests matched local `sha256sum` across all downloaded archives at `0.72.0`
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/Wilfred/difftastic/releases`, `GLOBAL` only)

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -d`: no `DT_NEEDED`, no `PT_INTERP`; `ldd`: `statically linked`).
- `linux/aarch64`: dynamic GNU ELF (upstream publishes no `aarch64-unknown-linux-musl` asset). `readelf -l` / `readelf -d` showed `INTERP /lib/ld-linux-aarch64.so.1` and `NEEDED`: `libgcc_s.so.1`, `libpthread.so.0`, `libdl.so.2`, `libc.so.6`, `ld-linux-aarch64.so.1` (`GLIBC_2.17`/`2.18`). `xpm.linux.deps.runtime` declares `xim:glibc@>=2.39` and `xim:gcc-runtime@15.1.0`.
- `windows/x86_64`: PE32+ importing `VCRUNTIME140.dll`, UCRT API sets, `kernel32.dll`, `bcryptprimitives.dll`, `userenv.dll`, and `ntdll.dll`; declares `xim:vcruntime` runtime dep and copies CRT DLLs app-local beside `difft.exe`.

## What the hooks do

- `installed()`: `payload.present({ "difft" })` or `payload.present({ "difft.exe" })`.
- `install()`: archives are flat (no enclosing directory). On POSIX, extracts directly into `pkginfo.install_dir()` with `tar -xzf` (with fallback move from the parent download dir) and runs `chmod +x`. On Windows, unpacks via `payload.unpack{}` (`%SystemRoot%\System32\tar.exe`) and copies `xim:vcruntime` DLLs beside `difft.exe`.
- `config()`: registers `difft` (`bindir = pkginfo.install_dir()`) and `difftastic` (`type = "group"`) with `xvm`.
- `uninstall()`: removes both `difft` and `difftastic` from `xvm`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`local:difftastic@0.72.0`): `difft --version`, structural diffing of two Python files, `dep-closure-check.sh`, `xlings remove`, and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` installs (no local ARM64/macOS/Windows hosts; archives downloaded, SHA256s verified, and ELF/PE headers inspected).

## Revision log

- 2026-11-26 — added at `0.72.0`.
