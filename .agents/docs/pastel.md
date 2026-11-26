# pastel

Command-line tool to generate, analyze, convert and manipulate colors (`status = "stable"`).

- Upstream: https://github.com/sharkdp/pastel (MIT / Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream does not publish a Windows ARM64 asset (and `xim:vcruntime` covers `x86_64` only).

## Source

- Tier: official repository release (`sharkdp/pastel` GitHub Releases)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/sharkdp/pastel/releases/download/v${version}/pastel-v${version}-x86_64-unknown-linux-musl.tar.gz`
  - `linux/aarch64`: `https://github.com/sharkdp/pastel/releases/download/v${version}/pastel-v${version}-aarch64-unknown-linux-gnu.tar.gz`
  - `macosx`: `https://github.com/sharkdp/pastel/releases/download/v${version}/pastel-v${version}-${arch}-apple-darwin.tar.gz`
  - `windows`: `https://github.com/sharkdp/pastel/releases/download/v${version}/pastel-v${version}-${arch}-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against GitHub release asset digests and locally computed `sha256sum` across all five downloaded `v0.12.0` archives.
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/sharkdp/pastel/releases`, `GLOBAL` only).

## Linking

- `linux/x86_64`: static-pie linked musl ELF (`readelf -d` shows no `PT_INTERP` and no `DT_NEEDED`; `ldd` reports `statically linked`).
- `linux/aarch64`: dynamic GNU ELF (upstream publishes no `aarch64-unknown-linux-musl` asset). `readelf -l` / `readelf -d` / `readelf -V` show `INTERP /lib/ld-linux-aarch64.so.1` and `NEEDED`: `libc.so.6`, `libm.so.6`, `libpthread.so.0`, `libgcc_s.so.1`, `libdl.so.2` (`GLIBC_2.17`/`2.18`, `GCC_3.0`/`3.3`/`4.2.0`). `xpm.linux.deps.runtime` declares `xim:glibc@>=2.39` and `xim:gcc-runtime@15.1.0`.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O executables.
- `windows/x86_64`: PE32+ x86-64 executable importing `VCRUNTIME140.dll`, UCRT API sets (`api-ms-win-crt-*.dll`), `api-ms-win-core-synch-l1-2-0.dll`, `bcryptprimitives.dll`, `KERNEL32.dll`, and `ntdll.dll`. Declares `xim:vcruntime` runtime dependency and copies CRT DLLs app-local beside `pastel.exe`.

## What the hooks do

- `installed()`: `payload.present({ "pastel" }) or payload.present({ "pastel.exe" })`.
- `install()`: unpacks `pastel-v<version>-<target>/` with `payload.unpack{ extracted = stem, strip = 1 }`, copies `xim:vcruntime` DLLs beside `pastel.exe` on Windows, and verifies the binary with `payload.require`.
- `config()`: registers `pastel` with `xvm.add("pastel", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `pastel` via `xvm.remove("pastel")`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`local:pastel@0.12.0`): `pastel --version`, `pastel format hex red`, `dep-closure-check.sh`, `xlings remove`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect --only pastel`, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` native installs (archives downloaded, SHA256s verified, ELF/PE headers inspected, and Windows hook logic tested in Lua sandbox; CI exercises `linux`, `macosx/aarch64`, and `windows/x86_64`).

## Revision log

- 2026-11-26 — added at `0.12.0`.
