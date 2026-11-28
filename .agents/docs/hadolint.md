# hadolint

Haskell Dockerfile Linter (`hadolint` command), `status = "stable"`.

- Upstream: https://github.com/hadolint/hadolint (GPL-3.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream `v2.15.1` publishes no Windows ARM64 binary.

## Source

- Tier: official repository release (`hadolint/hadolint`)
- GLOBAL:
  - `linux`: `https://github.com/hadolint/hadolint/releases/download/v${version}/hadolint-linux-${arch_alias}` (`x86_64` -> `x86_64`, `aarch64` -> `arm64`)
  - `macosx`: `https://github.com/hadolint/hadolint/releases/download/v${version}/hadolint-macos-${arch_alias}` (`x86_64` -> `x86_64`, `aarch64` -> `arm64`)
  - `windows`: `https://github.com/hadolint/hadolint/releases/download/v2.15.1/hadolint-windows-x86_64.exe`
- CN: none yet (`ci = { mirror = true }`; CI mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: taken from upstream `v2.15.1/checksums.sha256` and verified byte-for-byte with `sha256sum` on all five downloaded assets.
- Auto-update: yes (`extensions.autoupdate` watching `hadolint/hadolint` releases)

## Linking

- `linux/x86_64`, `linux/aarch64`: fully static ELF64 executables (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Zero runtime dependencies (`deps` omitted).
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables linking only macOS system libraries (`/usr/lib/libSystem.B.dylib`, `/usr/lib/libiconv.2.dylib`, `/usr/lib/libffi.dylib`, `/System/Library/Frameworks/Security.framework/Versions/A/Security`, `/usr/lib/libcharset.1.dylib`).
- `windows/x86_64`: PE32+ console executable importing only standard Windows OS / UCRT DLLs (`KERNEL32.dll`, `SHELL32.dll`, `USER32.dll`, `dbghelp.dll`, `ADVAPI32.dll`, `WS2_32.dll`, `ole32.dll`, `RPCRT4.dll`, `ntdll.dll`, `WINMM.dll`, `GDI32.dll`, `api-ms-win-crt-*.dll`); no `VCRUNTIME140.dll` or `MSVCP140.dll`.

## What the hooks do

- install: upstream ships raw binaries rather than archives; moves `pkginfo.install_file()` to `<install_dir>/hadolint` (or `hadolint.exe` on Windows), runs `chmod +x` on Unix, and verifies the target file exists.
- config: registers `hadolint` with `xvm.add("hadolint", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `hadolint` via `xvm.remove("hadolint")`.
- System impact: none.

## Verification

- Verified `linux/x86_64` in an isolated `XLINGS_HOME` & `HOME`: `config --add-xpkg`, `search`, `install hadolint@2.15.1`, `hadolint --version`, linting both failing (`DL3009`) and passing Dockerfiles, `list`, idempotent reinstall, `remove`, `list`, idempotent remove, `config --remove-xpkg`, and `dep-closure-check.sh`.
- Ran `pytest tests/h/test_hadolint.py -m "static or isolation"`, `pytest tests/h/test_hadolint.py -m index`, `pytest tests/h/test_hadolint.py -m "lifecycle or verify"` (isolated `XLINGS_HOME`), full `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect/materialize`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, and `windows/x86_64` runtime execution (covered by binary header/dependency inspection locally and native CI runners for `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64`).

## Revision log

- 2026-11-26 — added at `2.15.1`: initial package for Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
