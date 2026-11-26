# pandoc

Universal document converter (`pandoc`), status `stable`.

- Upstream: https://github.com/jgm/pandoc (GPL-2.0-or-later)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is not covered because upstream publishes no Windows ARM64 release asset.

## Source

- Tier: upstream release (`jgm/pandoc` GitHub Releases)
- GLOBAL:
  - `linux`: `https://github.com/jgm/pandoc/releases/download/${version}/pandoc-${version}-linux-${arch_alias}.tar.gz` (`amd64`/`arm64`)
  - `macosx`: `https://github.com/jgm/pandoc/releases/download/${version}/pandoc-${version}-${arch_alias}-macOS.zip` (`x86_64`/`arm64`)
  - `windows`: `https://github.com/jgm/pandoc/releases/download/${version}/pandoc-${version}-windows-${arch}.zip` (`x86_64`)
- CN: none yet (`ci = { mirror = true }`; CI mirrors to `xlings-res` after merge)
- Checksums: GitHub Release API asset `digest` for `3.14` verified identical to SHA256 computed locally on all five downloaded archives.
- Auto-update: yes (`extensions.autoupdate`, GitHub Releases, GLOBAL required)

## Linking

- `linux/x86_64` & `linux/aarch64`: statically linked ELF64 executables (`file` reports `statically linked`, `readelf -d` reports no dynamic section / no `DT_NEEDED`), so no `xim:glibc` or `xim:gcc-runtime` dependency is declared.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit executables linking only macOS system libraries (`/usr/lib/libSystem.B.dylib`, `/usr/lib/libiconv.2.dylib`, `/usr/lib/libffi.dylib`, `/System/Library/Frameworks/Security.framework/Versions/A/Security`, `/usr/lib/libcharset.1.dylib`).
- `windows/x86_64`: PE32+ x86-64 executable importing only Windows OS and UCRT DLLs (`api-ms-win-crt-*`, `KERNEL32.dll`, `WS2_32.dll`, `SHELL32.dll`, `USER32.dll`, `ADVAPI32.dll`, `CRYPT32.dll`, `ole32.dll`, `RPCRT4.dll`, `ntdll.dll`, `GDI32.dll`, `WINMM.dll`, `dbghelp.dll`); no `VCRUNTIME140.dll` or `MSVCP140.dll`.

## What the hooks do

- `install`: unpacks the upstream top-level directory (`pandoc-<ver>` on Linux/Windows, `pandoc-<ver>-{x86_64,arm64}` on macOS) via `payload.unpack` (with `strip = 1` for Windows `.zip`), sets `+x` on `bin/pandoc` on POSIX, and asserts `bin/pandoc` or `pandoc.exe` via `payload.require`.
- `config`: registers `pandoc` with `xvm.add` (`bindir = dir .. "/bin"` on POSIX; `bindir = dir, alias = "pandoc.exe"` on Windows).
- `uninstall`: calls `xvm.remove("pandoc")`.
- System impact: none outside `pkginfo.install_dir()` and the subos `pandoc` xvm shim.

## Verification

- Linux `x86_64`: tested in isolated `XLINGS_HOME` (`xlings config --add-xpkg`, `xlings search`, `xlings install`, `pandoc --version`, `pandoc -f markdown -t html`, idempotent reinstall, `xlings remove`, `dep-closure-check.sh`) and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Linux `aarch64`, macOS (`x86_64`, `aarch64`), Windows (`x86_64`): binaries/archives downloaded and inspected on Linux host; runtime execution on those hosts is covered by CI (`linux-arm64-install-test`, `macos-install-test`, `windows-install-test`).

## Revision log

- 2026-11-26 — added at `3.14`.
