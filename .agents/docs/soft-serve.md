# soft-serve

The mighty, self-hostable Git server for the command line (`charmbracelet/soft-serve`), providing the `soft` binary. Status: `stable`.

- Upstream: https://github.com/charmbracelet/soft-serve (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`) — covers all desktop/server architectures published by upstream `v0.12.4` (upstream does not publish a `windows/aarch64` archive).

## Source

- Tier: upstream release (`https://github.com/charmbracelet/soft-serve/releases`)
- GLOBAL: `https://github.com/charmbracelet/soft-serve/releases/download/v${version}/soft-serve_${version}_${os}_${arch_alias}.${ext}` (`.tar.gz` for `Linux`/`Darwin`, `.zip` for `Windows`)
- CN: none yet (`ci = { mirror = true }`, a maintainer mirror job handles `xlings-res`)
- Checksums: verified SHA256 against `checksums.txt`, GitHub release asset digests, and locally downloaded bytes of all 5 archives (exact match).
- Auto-update: yes (`extensions.autoupdate`, GLOBAL required across all 5 platform/arch targets).

## Linking

- Linux (`x86_64` and `aarch64`): `soft` is a statically linked Go ELF executable with no dynamic section and no external libc dependency (`readelf -d`, `ldd`). Declares no `deps`.
- Windows (`x86_64`): `soft.exe` is a PE32+ console executable importing only `kernel32.dll` (no `VCRUNTIME140.dll` or MSVC runtime dependency).
- macOS (`x86_64` and `aarch64`): Mach-O 64-bit executables (`x86_64` and `arm64`).

## What the hooks do

- install: unpacks the archive's top-level `soft-serve_${version}_${os}_${arch}/` directory into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem, strip = 1 }` and verifies `soft` (`soft.exe` on Windows) plus `LICENSE` with `payload.require(...)`.
- config: registers `soft` with `xvm.add("soft", { bindir = pkginfo.install_dir() })` and registers `soft-serve` with `xvm.add(package.name, { type = "group" })` so `xvm info soft-serve` and `xlings remove soft-serve` work without creating an orphan `soft-serve` shim in `bin/`.
- uninstall: removes `soft` and `soft-serve` from xvm.
- System impact: none; isolated under `pkginfo.install_dir()` and xvm shims.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME`: `pytest tests/s/test_soft_serve.py`, `tests/test_shortcut.py`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `python3 tools/xpkg_ci.py inspect --only soft-serve`, `xlings install local:soft-serve -y`, `soft --version`, `soft --help`, and `xlings remove soft-serve -y`.
- `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows` (`x86_64`) runtime installs were not run locally (relying on GitHub Actions CI for `linux/aarch64`, `macosx/aarch64`, `windows/x86_64`, and archive/ELF/PE inspection for `macosx/x86_64`).

## Revision log

- 2026-11-26 — added at `0.12.4`: initial spec-2 recipe covering `linux` (`x86_64`/`aarch64`), `macosx` (`x86_64`/`aarch64`), and `windows` (`x86_64`), `ci = { mirror = true }`, and `extensions.autoupdate`.
