# procs

A modern replacement for `ps` written in Rust, providing the `procs` CLI (`status = "stable"`).

- Upstream: https://github.com/dalance/procs (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream does not publish a Windows ARM64 asset (and `xim:vcruntime` is `x86_64`-only).

## Source

- Tier: official repository release (`dalance/procs` GitHub Releases)
- GLOBAL:
  - `linux`: `https://github.com/dalance/procs/releases/download/v${version}/procs-v${version}-${arch}-linux.zip`
  - `macosx`: `https://github.com/dalance/procs/releases/download/v${version}/procs-v${version}-${arch}-mac.zip`
  - `windows`: `https://github.com/dalance/procs/releases/download/v${version}/procs-v${version}-${arch}-windows.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against GitHub release asset digests and locally computed `sha256sum` on all five downloaded `v0.14.12` `.zip` archives.
- Auto-update: yes (`extensions.autoupdate`)

## Linking

- `linux/x86_64`: static-pie linked musl ELF (`readelf -d` shows no `PT_INTERP` and no `DT_NEEDED`, `ldd` reports `statically linked`). Declares no runtime dependencies.
- `linux/aarch64`: statically linked ELF (`readelf -d` shows no dynamic section, `ldd` reports not a dynamic executable). Declares no runtime dependencies.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` / `arm64`). Declares no runtime dependencies.
- `windows/x86_64`: PE32+ x86-64 executable importing `VCRUNTIME140.dll`, UCRT API sets, and Windows OS DLLs (`kernel32.dll`, `ntdll.dll`, `advapi32.dll`, `psapi.dll`, `iphlpapi.dll`, `ws2_32.dll`, `user32.dll`, `shell32.dll`, `combase.dll`, `bcryptprimitives.dll`). Declares `xim:vcruntime` runtime dependency on Windows.

## What the hooks do

- `install`: unpacks the flat `.zip` archive (`procs` / `procs.exe`) into `pkginfo.install_dir()` (pre-extracted fallback or `unzip -q -o` on POSIX, `payload.unpack{}` on Windows), copies `xim:vcruntime` DLLs beside `procs.exe` on Windows, sets `+x` on POSIX, and asserts the binary with `payload.require`.
- `config`: registers `procs` with `xvm.add("procs", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `procs` via `xvm.remove("procs")`.
- System impact: none; self-contained in `pkginfo.install_dir()` and xvm shims.

## Verification

- Linux `x86_64`: verified static/isolation/index tests, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect/materialize`, and isolated `XLINGS_HOME` & `HOME` `xlings install local:procs -y`, `procs --version`, `procs --pager disable --no-header`, `dep-closure-check.sh`, `pytest -m "index or lifecycle or verify"`, and `xlings remove procs -y`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` native installs (verified archive hashes, ELF/Mach-O/PE headers, and Lua sandbox tests instead; CI covers `linux`, `macosx/aarch64`, and `windows/x86_64`).

## Revision log

- 2026-11-26 — added at `0.14.12`: initial package for `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`).
