# hexyl

A command-line hex viewer (`hexyl`, `status = "stable"`).

- Upstream: https://github.com/sharkdp/hexyl (MIT / Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream does not publish a `aarch64-pc-windows-msvc` archive and `xim:vcruntime` currently covers `x86_64` only.

## Source

- Tier: upstream release (`sharkdp/hexyl`)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-x86_64-unknown-linux-musl.tar.gz`
  - `linux/aarch64`: `https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-aarch64-unknown-linux-gnu.tar.gz`
  - `macosx/x86_64`: `https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-x86_64-apple-darwin.tar.gz`
  - `macosx/aarch64`: `https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-aarch64-apple-darwin.tar.gz`
  - `windows/x86_64`: `https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-x86_64-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`; CI will mirror GLOBAL assets to `xlings-res`)
- Checksums: GitHub release asset SHA256 digests matched local `sha256sum` across all 5 downloaded archives at `0.17.0`
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/sharkdp/hexyl/releases`, `GLOBAL` only)

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -l`: no `PT_INTERP`; `readelf -d`: no `DT_NEEDED`; `ldd`: `statically linked`).
- `linux/aarch64`: dynamic GNU ELF (upstream publishes no `aarch64-unknown-linux-musl` asset). `readelf -l` / `readelf -d` / `readelf -V` showed `INTERP /lib/ld-linux-aarch64.so.1` and `NEEDED`: `libgcc_s.so.1`, `libpthread.so.0`, `libc.so.6` (`GLIBC_2.17`, `GCC_3.0`/`GCC_3.3`/`GCC_4.2.0`). `xpm.linux.deps.runtime` declares `xim:glibc` and `xim:gcc-runtime`.
- `windows/x86_64`: PE32+ importing `VCRUNTIME140.dll`, UCRT API sets, `kernel32.dll`, and `ntdll.dll`; declares `xim:vcruntime` runtime dep and copies CRT DLLs app-local beside `hexyl.exe`.

## What the hooks do

- `installed()`: `payload.present({ "hexyl" }) or payload.present({ "hexyl.exe" })`.
- `install()`: archives extract into `hexyl-v<ver>-<target>/`. Calls `payload.unpack{ extracted = stem, strip = 1 }`, copies `xim:vcruntime` DLLs beside `hexyl.exe` on Windows, and verifies the binary with `payload.require`.
- `config()`: registers `hexyl` (`bindir = pkginfo.install_dir()`) with `xvm`.
- `uninstall()`: removes `hexyl` from `xvm`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`/tmp/xlings-hexyl`): `xlings config --add-xpkg`, `xlings search`, `xlings install local:hexyl@0.17.0 -y`, `hexyl --version`, hex-dumping input, `dep-closure-check.sh`, `xlings remove`, and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` installs (no local ARM64/macOS/Windows hosts; all 5 archives were downloaded, SHA256s verified, and ELF/PE/Mach-O headers inspected).

## Revision log

- 2026-11-26 — added at `0.17.0`.
