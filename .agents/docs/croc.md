# croc

Easily and securely send things from one computer to another (`schollz/croc`), providing the `croc` command (`status = "stable"`).

- Upstream: https://github.com/schollz/croc (`MIT`, homepage: https://getcroc.com)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes 32-bit, ARMv5/ARMv7, RISCV64, BSD, deb/rpm, and `croc-web` assets, which are outside xlings' `{x86_64, aarch64}` matrix.

## Source

- Tier: upstream GitHub release (`schollz/croc`)
- GLOBAL: `https://github.com/schollz/croc/releases/download/v${version}/croc_v${version}_<OS>-<arch>.{tar.gz,zip}`
- CN: none yet (`ci = { mirror = true }` declared for `xlings-res` mirroring)
- Checksums: all six `v11.6.6` archives verified with `sha256sum` against upstream `croc_v11.6.6_checksums.txt` and GitHub Release asset digests
- Auto-update: yes (`extensions.autoupdate`, `GLOBAL` required across all 6 platform/arch targets)

## Linking

- `linux/x86_64`: statically linked Go ELF64 x86-64 executable (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Declares no `deps`.
- `linux/aarch64`: statically linked Go ELF64 ARM aarch64 executable (`readelf -d`: no dynamic section). Declares no `deps`.
- `macosx/x86_64` and `macosx/aarch64`: official upstream macOS tarballs (`croc_v11.6.6_macOS-{64bit,ARM64}.tar.gz`).
- `windows/x86_64` (`0x8664`) and `windows/aarch64` (`0xaa64`): PE32+ executables importing `kernel32.dll` only (no `VCRUNTIME140.dll` / `MSVCP140.dll` dependency). Declares no `xim:vcruntime`.

## What the hooks do

- `installed`: checks `croc` (or `croc.exe`) and `LICENSE` via `payload.present` (with `os.isfile` fallback when `payload` stub is loaded without `libs/`).
- `install`: all upstream archives are flat at root (`croc`/`croc.exe`, `croc-update`/`croc-update.exe`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `src/codephrase/wordlists/LICENSE.txt`). On Windows, extracts the `.zip` into `pkginfo.install_dir()` via `payload.unpack{}` (using `%SystemRoot%\System32\tar.exe`, with direct `winpath.native` fallback). On POSIX, extracts the `.tar.gz` directly into `pkginfo.install_dir()` via `tar -xzf` (with pre-extracted file move fallback) and ensures `+x` on `croc`. Verifies `croc`/`croc.exe` and `LICENSE` via `payload.require` (with explicit missing-file check fallback).
- `config`: registers `croc` with `xvm.add("croc", { bindir = pkginfo.install_dir() })`. `croc-update` is intentionally not registered on PATH because xlings manages package upgrades.
- `uninstall`: removes `croc` via `xvm.remove("croc")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in isolated `HOME` / `XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search croc`, `xlings install local:croc -y`, `croc --version`, `croc --help`, `timeout 5 croc /? </dev/null` (exits immediately with code 0 without connecting to the public relay; also verified `CROC_SECRET='/?'` exits immediately with code 1 `"code is too short"` simulating Windows argument passing), idempotent reinstall, `xlings remove croc -y`, `pytest tests/c/test_croc.py`, repo-wide static/isolation pytest checks, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only croc`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (covered by archive checksum/binary linkage inspection, Lua sandbox hook tests, and GitHub Actions CI).

## Revision log

- 2026-11-26 — added at `11.6.6`.
