# gping

`gping` is a ping tool with a live terminal graph (`orf/gping`, `status = "stable"`).

- Upstream: <https://github.com/orf/gping> (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream publishes no Windows ARM64 release asset.

## Source

- Tier: upstream release (GitHub Releases of `orf/gping`, tag `gping-v${version}`)
- GLOBAL:
  - `linux`: `https://github.com/orf/gping/releases/download/gping-v${version}/gping-Linux-musl-${arch_alias}.tar.gz` (`x86_64` -> `x86_64`, `aarch64` -> `arm64`)
  - `macosx`: `https://github.com/orf/gping/releases/download/gping-v${version}/gping-macOS-${arch_alias}.tar.gz` (`x86_64` -> `x86_64`, `aarch64` -> `arm64`)
  - `windows`: `https://github.com/orf/gping/releases/download/gping-v${version}/gping-Windows-msvc-${arch}.zip` (`x86_64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: GitHub release asset SHA-256 digests at `gping-v1.21.0` matched local `sha256sum` across all 5 packaged archives.
- Auto-update: yes (`extensions.autoupdate` with `tag = "gping-v${version}"`).

## Linking & CLI Probes

- `linux/x86_64`: static-pie musl ELF (`file`: `static-pie linked`; `readelf -l`: no `PT_INTERP`; `readelf -d`: zero `DT_NEEDED`; `ldd`: `statically linked`) — zero runtime dependencies.
- `linux/aarch64`: statically linked musl ELF (`file`: `statically linked`; `readelf -d`: no dynamic section) — zero runtime dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64`: PE32+ CUI `gping.exe` importing `VCRUNTIME140.dll`, UCRT API sets (`api-ms-win-crt-*`), `kernel32.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `user32.dll`, `ws2_32.dll`, `ntdll.dll`, `bcryptprimitives.dll`, and `IPHLPAPI.DLL` (no delay-load imports). Declares `xim:vcruntime` runtime dep on Windows and copies CRT DLLs app-local beside `gping.exe`.
- Windows CI `/?` check: verified locally (`timeout 5 ./gping /? </dev/null`) that `gping /?` fails immediately at hostname resolution (`Error: Resolving /?`, exit 1) without opening a TUI or running ICMP ping.

## What the hooks do

- `installed()`: `payload.present({ "gping" })` or `payload.present({ "gping.exe" })`.
- `install()`: every upstream archive is flat at root (`gping` or `gping.exe`, plus `gping.1`). On POSIX, extracts into a clean `pkginfo.install_dir()` via `shell.exec({ "tar", "-xzf", ... })` and `chmod +x` (with pre-extracted parent-dir move fallback). On Windows, unpacks via `payload.unpack{}` (`%SystemRoot%\System32\tar.exe`) and copies `xim:vcruntime` DLLs beside `gping.exe`. Asserts payload presence via `payload.require({ exe })`.
- `config()`: registers `gping` via `xvm.add("gping", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `gping` via `xvm.remove("gping")`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Static & isolation pytest suites, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only gping` verified locally.
- Isolated `xlings` install/verify/remove on Linux `x86_64` verified (`gping --version`, `gping --help`, `gping /?`, `tests/g/test_gping.py`, `dep-closure-check.sh`, and `xlings remove`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime execution (hooks verified via Lua unit tests; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 1.21.0 (`gping-v1.21.0`): initial packaging with flat-archive direct extraction, `xim:vcruntime` app-local DLL copy on Windows `x86_64`, and payload verification.
