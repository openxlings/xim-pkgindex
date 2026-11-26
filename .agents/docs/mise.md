# mise

`mise` (`mise-en-place`) is a polyglot dev tool manager, environment variable manager, and task runner (`status = "stable"`).

- Upstream: https://github.com/jdx/mise (`MIT`)
- Homepage / Docs: https://mise.jdx.dev / https://mise.jdx.dev/
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`)

## Source

- Tier: upstream release (GitHub Releases of `jdx/mise`)
- GLOBAL:
  - `linux`: `https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-linux-${arch_alias}-musl.tar.gz` (`x86_64` -> `x64`, `aarch64` -> `arm64`)
  - `macosx`: `https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-macos-${arch_alias}.tar.gz` (`x86_64` -> `x64`, `aarch64` -> `arm64`)
  - `windows`: `https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-windows-${arch_alias}.zip` (`x86_64` -> `x64`, `aarch64` -> `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: all 6 SHA-256 digests at `v2026.11.14` matched upstream `SHASUMS256.txt`, GitHub release asset digests, and locally downloaded archives.
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/jdx/mise/releases`, `GLOBAL` only, using `${tag}`).

## Linking & CLI Probes

- `linux/x86_64`: static-pie musl ELF (`file`: `static-pie linked`; `readelf -l`: no `PT_INTERP`; `ldd`: `statically linked`, zero `DT_NEEDED`) — zero runtime dependencies.
- `linux/aarch64`: statically linked musl ELF (`file`: `statically linked`; `readelf -l`: no `PT_INTERP`; `readelf -d`: no dynamic section) — zero runtime dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64` and `windows/aarch64`: PE32+ CUI `mise.exe` and `mise-shim.exe` statically linking the MSVC CRT; import tables contain only Windows OS system DLLs (`kernel32.dll`, `advapi32.dll`, `oleaut32.dll`, `shell32.dll`, `combase.dll`, `ntdll.dll`, `userenv.dll`, `ole32.dll`, `api-ms-win-core-winrt-l1-1-0.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `bcryptprimitives.dll`, `bcrypt.dll`, `ws2_32.dll`, `user32.dll`, `cfgmgr32.dll`, `crypt32.dll`, `version.dll`; zero delay-load imports; `mise-shim.exe` imports only `KERNEL32.dll`, `ntdll.dll`, `api-ms-win-core-synch-l1-2-0.dll`), with no `VCRUNTIME140.dll` or `MSVCP140.dll`. No `xim:vcruntime` dependency needed.
- Windows CI `/?` check: verified locally (`timeout --foreground -k 2 5 ./mise /? </dev/null`) that `mise /?` exits immediately (exit 1, `mise ERROR no tasks defined ...`) without blocking.

## What the hooks do

- `installed()`: checks `payload.present({ "bin/mise", "LICENSE" })` or `payload.present({ "bin/mise.exe", "bin/mise-shim.exe", "LICENSE" })`.
- `install()`: every upstream archive extracts under a single `mise/` directory. Unpacks via `payload.unpack{ extracted = "mise", strip = 1 }` (moving pre-extracted `mise/` on POSIX or stripping `mise/` from `.zip` via `%SystemRoot%\System32\tar.exe --strip-components=1` on Windows) and asserts the platform payload files via `payload.require(...)`.
- `config()`: registers `mise` via `xvm.add("mise", { bindir = pkginfo.install_dir() .. "/bin" })`.
- `uninstall()`: removes `mise` via `xvm.remove("mise")`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Static & isolation pytest suites (package + repo-wide), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only mise` verified locally.
- Isolated `HOME=/tmp/xlings-mise XLINGS_HOME=/tmp/xlings-mise` verification on Linux `x86_64`: `xlings config --add-xpkg`, `xlings search mise`, `xlings install local:mise@2026.11.14 -y`, `mise --version`, `mise trust/env/run`, `xlings list mise`, idempotent re-install, `xlings remove mise -y`, idempotent re-remove, `xlings config --remove-xpkg mise`, plus `tests/m/test_mise.py` (`index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (hooks verified via Lua unit tests; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at `2026.11.14`: initial packaging across `linux`, `macosx`, and `windows` (`x86_64` and `aarch64`).
