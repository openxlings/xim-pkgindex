# tilt

Multi-service development environment tool for Kubernetes (`tilt`), `status = "stable"`.

- Upstream: https://github.com/tilt-dev/tilt (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream also publishes `linux.arm.tar.gz`, omitted because `archs` only covers 64-bit targets; upstream does not publish a `windows/aarch64` binary for `v0.37.9`, so `xpm.windows` covers `x86_64` only.

## Source

- Tier: official upstream GitHub release (`tilt-dev/tilt`)
- GLOBAL:
  - `linux`: `https://github.com/tilt-dev/tilt/releases/download/v${version}/tilt.${version}.linux-alpine.${arch_alias}.tar.gz` (`x86_64`, `arm64`)
  - `macosx`: `https://github.com/tilt-dev/tilt/releases/download/v${version}/tilt.${version}.mac.${arch_alias}.tar.gz` (`x86_64`, `arm64`)
  - `windows`: `https://github.com/tilt-dev/tilt/releases/download/v${version}/tilt.${version}.windows.${arch_alias}.zip` (`x86_64`)
- CN: none yet (declares `ci = { mirror = true }` so post-merge CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: taken from upstream `checksums.txt` and verified against locally downloaded bytes for all five selected targets (plus the two glibc Linux archives inspected for comparison; all matched)
- Auto-update: yes (`extensions.autoupdate` with `${tag}` and `${version}`)

## Linking

Static musl Go binary on Linux with zero external shared-library dependencies:
- Linux `x86_64` and `aarch64` (`linux-alpine` archives): `readelf -d` shows no dynamic section; `ldd` reports `not a dynamic executable`. No `xim:glibc`, `xim:gcc-runtime`, or `xim:musl` dependency. (By contrast, upstream's `linux.{x86_64,arm64}.tar.gz` binaries dynamically link `libstdc++.so.6`, `libgcc_s.so.1`, and `libc.so.6`.)
- macOS `x86_64` and `aarch64`: Mach-O 64-bit executables (`DYLDLINK|WEAK_DEFINES|BINDS_TO_WEAK|PIE`).
- Windows `x86_64` (`0x8664`) PE32+ console executable: import table contains `KERNEL32.dll` and `msvcrt.dll` (built-in OS DLLs; no `VCRUNTIME140.dll` / `MSVCP140.dll`, no `xim:vcruntime` dependency).
- `tilt "/?"` exits immediately with status 1 (`unknown command "/?" for "tilt"`), so Windows CI program smoke probing will not hang.

## What the hooks do

- `install`: extracts the flat archive directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` -> `%SystemRoot%\System32\tar.exe` on Windows) with a move fallback if pre-extracted, so unrelated files in the shared download directory cannot mix into the payload; asserts `tilt` / `tilt.exe`, `LICENSE`, and `README.md` via `payload.require`.
- `config`: registers `tilt` via `xvm.add("tilt", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `tilt` via `xvm.remove("tilt")`.
- System impact: none; writes only inside `pkginfo.install_dir()` and registers the `xvm` shim.

## Verification

- Verified `v0.37.9` download URLs, SHA-256 digests, archive layouts, ELF headers (`readelf -d`, `ldd`), PE headers/imports, and `tilt "/?"` exit behavior across all 5 target archives (plus `linux.x86_64` and `linux.arm64` comparison).
- Static & isolation pytest (`tests/t/test_tilt.py -m "static or isolation"`), repo core static checks, lint scripts, and `tools/xpkg_ci.py inspect --only tilt` run on `linux/x86_64`.
- Isolated `XLINGS_HOME` & `HOME` lifecycle (`xlings config --add-xpkg`, `xlings search`, `xlings install local:tilt@0.37.9 -y`, `tilt version`, `tilt alpha tiltfile-result`, `tilt completion bash`, `xlings list`, `xlings remove`, `dep-closure-check.sh`, `pytest -m "index or lifecycle or verify"`) verified on `linux/x86_64`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`) native execution (no local hosts for those targets; covered by CI runners for `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64`, plus Lua unit tests for the Windows extraction hook).

## Revision log

- 2026-11-26 — added at `0.37.9`: initial release across `linux` (`x86_64`, `aarch64` via `linux-alpine` static musl), `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`), flat `.tar.gz` (POSIX) and `.zip` (Windows) extraction.
