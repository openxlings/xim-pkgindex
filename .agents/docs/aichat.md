# aichat

AIChat (`aichat`) is an all-in-one LLM CLI tool featuring Shell Assistant, Chat-REPL, RAG, AI Tools & Agents (`status = "stable"`).

- Upstream: https://github.com/sigoden/aichat (`MIT OR Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` (`aichat-v0.30.0-aarch64-pc-windows-msvc.zip`) is omitted because its PE imports `VCRUNTIME140.dll` and `xim:vcruntime` currently covers `x86_64` only.

## Source

- Tier: upstream release (GitHub Releases of `sigoden/aichat`)
- GLOBAL:
  - `linux`: `https://github.com/sigoden/aichat/releases/download/v${version}/aichat-v${version}-${arch}-unknown-linux-musl.tar.gz` (`x86_64`, `aarch64`)
  - `macosx`: `https://github.com/sigoden/aichat/releases/download/v${version}/aichat-v${version}-${arch}-apple-darwin.tar.gz` (`x86_64`, `aarch64`)
  - `windows`: `https://github.com/sigoden/aichat/releases/download/v${version}/aichat-v${version}-${arch}-pc-windows-msvc.zip` (`x86_64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: GitHub release asset SHA-256 digests at `v0.30.0` matched local `sha256sum` across all 5 packaged archives (and the inspected `windows/aarch64` archive).
- Auto-update: yes (`extensions.autoupdate` using `${tag}`).

## Linking & CLI Probes

- `linux/x86_64`: static-pie musl ELF (`file`: `static-pie linked`; `ldd`: `statically linked`) — zero runtime dependencies.
- `linux/aarch64`: statically linked musl ELF (`file`: `statically linked`; `readelf -d`: no dynamic section; `ldd`: not a dynamic executable) — zero runtime dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64` (and `windows/aarch64`): PE32+ CUI `aichat.exe` importing `VCRUNTIME140.dll`, UCRT API sets, `kernel32.dll`, `bcryptprimitives.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `ADVAPI32.dll`, `USER32.dll`, `ws2_32.dll`, `ntdll.dll`, `api-ms-win-core-handle-l1-1-0.dll`, `shell32.dll`, `ole32.dll`, `bcrypt.dll`, and `crypt32.dll`. Declares `xim:vcruntime` runtime dep on Windows and copies CRT DLLs app-local beside `aichat.exe`.
- Windows CI `/?` check: verified locally (`timeout --foreground -k 2 5 ./aichat /? </dev/null`) that `aichat /?` prompts interactively (`? No config file, create a new one? (Y/n)`) and times out (exit 124), so Windows CI falls back to `aichat --version` (`aichat 0.30.0`).

## What the hooks do

- `installed()`: `payload.present({ "aichat" })` or `payload.present({ "aichat.exe" })`.
- `install()`: every upstream archive is flat at root (single `aichat` or `aichat.exe` binary). On POSIX, extracts into a clean `pkginfo.install_dir()` via `shell.exec({ "tar", "-xzf", ... })` and `chmod +x` (with parent-dir move fallback). On Windows, unpacks via `payload.unpack{}` (`%SystemRoot%\System32\tar.exe`) and copies `xim:vcruntime` DLLs beside `aichat.exe`. Asserts payload presence via `payload.require(...)`.
- `config()`: registers `aichat` via `xvm.add("aichat", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `aichat` via `xvm.remove("aichat")`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Static & isolation pytest suites, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only aichat` verified locally.
- Isolated `xlings` install/verify/remove on Linux `x86_64` verified (`aichat --version`, `aichat --help`, `tests/a/test_aichat.py`, and `xlings remove`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime execution (hooks verified via Lua unit tests; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 0.30.0: initial packaging with flat-archive direct extraction, `xim:vcruntime` app-local DLL copy on Windows `x86_64`, and payload verification.
