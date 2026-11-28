# dbmate

A lightweight, framework-agnostic database migration tool (`amacneil/dbmate`); provides the `dbmate` CLI (status: `stable`).

- Upstream: https://github.com/amacneil/dbmate (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v2.38.2` publishes no `windows-arm64` binary (upstream `linux-386` and `linux-arm` binaries are outside `package.archs`).

## Source

- Tier: upstream official repository release (`https://github.com/amacneil/dbmate/releases`)
- GLOBAL:
  - `linux`: `https://github.com/amacneil/dbmate/releases/download/v${version}/dbmate-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/amacneil/dbmate/releases/download/v${version}/dbmate-macos-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/amacneil/dbmate/releases/download/v${version}/dbmate-windows-${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge; every asset has a distinct filename with zero `materialize` basename collision)
- Checksums: verified locally via `sha256sum` against GitHub release asset digests for all 5 downloaded binaries at `v2.38.2`
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/amacneil/dbmate/releases`)

## Linking

- `linux/x86_64` and `linux/aarch64`: static Go ELF64 executables. Verified with `readelf -d` (no dynamic section), `readelf -l` (no `PT_INTERP`), and `ldd` ("not a dynamic executable"). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`). PE import inspection shows `KERNEL32.dll` and Windows 10 Universal CRT API sets (`api-ms-win-crt-*.dll`), with no `VCRUNTIME140.dll` or `MSVCP140.dll`, so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, clears and creates `pkginfo.install_dir()`, moves the downloaded raw binary to `dbmate` (or `dbmate.exe` when the payload ends in `.exe` or runs on Windows), runs `chmod +x` on Unix, and verifies the target file exists.
- `config`: registers `dbmate` with `xvm.add("dbmate", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("dbmate")`.
- System impact: none (no shell profile, `PATH`, or system configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/d/test_dbmate.py -m "static or isolation"`
  - `python3 tools/xpkg_ci.py inspect --only dbmate`
  - `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`
  - Isolated `XLINGS_HOME` & `HOME`: `xlings config --add-xpkg pkgs/d/dbmate.lua`, `xlings install local:dbmate -y`, `dbmate --version`, `dbmate --help`, `pytest tests/d/test_dbmate.py -m "index or lifecycle or verify"`, and `xlings remove local:dbmate -y`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (not on host; covered by CI runners plus SHA-256, ELF/PE header, and `xpkg_ci.py inspect` verification for all 5 assets).

## Revision log

- 2026-11-26 — added at 2.38.2: initial spec-2 recipe using upstream single-file binaries for linux (x86_64, aarch64), macosx (x86_64, aarch64), and windows (x86_64).
