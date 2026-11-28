# osv-scanner

Vulnerability scanner written in Go using the OSV database (`osv-scanner` command), `status = "stable"`.

- Upstream: https://github.com/google/osv-scanner (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: official repository release (`google/osv-scanner`)
- GLOBAL:
  - `linux`: `https://github.com/google/osv-scanner/releases/download/v${version}/osv-scanner_linux_${arch_alias}` (`x86_64` -> `amd64`, `aarch64` -> `arm64`)
  - `macosx`: `https://github.com/google/osv-scanner/releases/download/v${version}/osv-scanner_darwin_${arch_alias}` (`x86_64` -> `amd64`, `aarch64` -> `arm64`)
  - `windows`: `https://github.com/google/osv-scanner/releases/download/v${version}/osv-scanner_windows_${arch_alias}.exe` (`x86_64` -> `amd64`, `aarch64` -> `arm64`)
- CN: none yet (`ci = { mirror = true }`; CI mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: taken from upstream `v2.7.1/osv-scanner_SHA256SUMS` and verified byte-for-byte against GitHub release digests and `sha256sum` across all six downloaded assets.
- Auto-update: yes (`extensions.autoupdate` watching `google/osv-scanner` releases)

## Linking

- `linux/x86_64`, `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Zero runtime dependencies (`deps` omitted).
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64`, `windows/aarch64`: PE32+ console executables (`x86-64`, `ARM64`) importing only `kernel32.dll`; no `VCRUNTIME140.dll` or `MSVCP140.dll`.
- Offline `/?` check (`windows-test.ps1`): `osv-scanner /?` treats `/?` as a scan path and exits immediately with status `127` (`failed to resolve path: ...`), without hanging or hitting the network.

## What the hooks do

- install: upstream ships raw single-file binaries rather than archives; moves `pkginfo.install_file()` to `<install_dir>/osv-scanner` (or `osv-scanner.exe` on Windows), runs `chmod +x` on Unix, and verifies the target file exists.
- config: registers `osv-scanner` with `xvm.add("osv-scanner", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `osv-scanner` via `xvm.remove("osv-scanner")`.
- System impact: none.

## Verification

- Verified `linux/x86_64` in an isolated `XLINGS_HOME` & `HOME`: `config --add-xpkg`, `search`, `install osv-scanner@2.7.1`, `osv-scanner --version`, offline `osv-scanner scan source --offline --no-ignore --allow-no-lockfiles -L <empty package-lock.json> --format json`, `list`, idempotent reinstall, `remove`, `list`, idempotent remove, and `config --remove-xpkg`.
- Ran `pytest tests/o/test_osv_scanner.py -m "static or isolation"`, `pytest tests/o/test_osv_scanner.py -m index`, `pytest tests/o/test_osv_scanner.py -m "lifecycle or verify"` (isolated `XLINGS_HOME`), full `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect --only osv-scanner`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64`, and `windows/aarch64` runtime execution (covered locally by binary header, SHA256, ELF dynamic section, and PE import checks, and on native CI runners for `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64`).

## Revision log

- 2026-11-26 — added at `2.7.1`: initial spec-2 recipe covering all 6 upstream raw-binary targets (`linux`, `macosx`, `windows` x `x86_64`/`aarch64`).
