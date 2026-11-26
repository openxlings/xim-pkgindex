# miniserve

`miniserve` is a small, self-contained CLI tool to serve files and directories over HTTP (`status = "stable"`).

- Upstream: https://github.com/svenstaro/miniserve (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream v0.35.0 publishes no Windows ARM64 binary.

## Source

- Tier: upstream release (GitHub Releases of `svenstaro/miniserve`)
- GLOBAL:
  - `linux`: `https://github.com/svenstaro/miniserve/releases/download/v${version}/miniserve-${version}-${arch}-unknown-linux-musl` (`x86_64`, `aarch64`)
  - `macosx`: `https://github.com/svenstaro/miniserve/releases/download/v${version}/miniserve-${version}-${arch}-apple-darwin` (`x86_64`, `aarch64`)
  - `windows`: `https://github.com/svenstaro/miniserve/releases/download/v${version}/miniserve-${version}-${arch}-pc-windows-msvc.exe` (`x86_64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: GitHub release asset SHA-256 digests at `v0.35.0` matched local `sha256sum` across all 5 downloaded binaries.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` in the release path and `${version}` in the filename).

## Linking & CLI Probes

- `linux/x86_64`: statically linked musl ELF (`file`: `statically linked`; `readelf -d`: no dynamic section; `ldd`: not a dynamic executable) — zero runtime dependencies.
- `linux/aarch64`: statically linked musl ELF (`file`: `statically linked`; `readelf -d`: no dynamic section) — zero runtime dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64`: PE32+ CUI executable importing `advapi32.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `bcrypt.dll`, `bcryptprimitives.dll`, `iphlpapi.dll`, `KERNEL32.DLL`, `ntdll.dll`, `ws2_32.dll` (no `VCRUNTIME140.dll`, no UCRT DLLs, no delay-load imports). Needs no `xim:vcruntime` dependency.
- Windows CI `/?` check: verified locally (`timeout 5 ./miniserve-0.35.0-x86_64-unknown-linux-musl /?`) that `miniserve /?` exits immediately (exit 1, `Error: Failed to resolve path to be served`) rather than starting an HTTP server.

## What the hooks do

- `installed()`: checks `payload.present({ "miniserve" })` or `payload.present({ "miniserve.exe" })`.
- `install()`: upstream distributes raw single-file binaries (no archive container). Cleans `pkginfo.install_dir()`, creates it with `fs.mkdir_p`, moves `pkginfo.install_file()` to `miniserve` (or `miniserve.exe` on Windows), runs `chmod +x` via `shell.exec` on Unix, and asserts payload presence via `payload.require`.
- `config()`: registers `miniserve` via `xvm.add("miniserve", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `miniserve` via `xvm.remove("miniserve")`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Static & isolation pytest suites, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only miniserve` verified locally.
- Isolated `xlings` install/verify/remove on Linux `x86_64` verified (`miniserve --version`, `miniserve --help`, static HTTP file serving, `tests/m/test_miniserve.py`, and `xlings remove`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime execution (hooks verified via Lua unit tests; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 0.35.0: raw single-file upstream binaries across 5 targets (`linux/{x86_64,aarch64}`, `macosx/{x86_64,aarch64}`, `windows/x86_64`).
