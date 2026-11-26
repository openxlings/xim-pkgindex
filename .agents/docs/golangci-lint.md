# golangci-lint

Fast linters runner for Go (`golangci-lint`), providing the `golangci-lint` CLI command (`status = "stable"`).

- Upstream: https://github.com/golangci/golangci-lint (`GPL-3.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (GitHub Releases of `golangci/golangci-lint`)
- GLOBAL:
  - `linux`: `https://github.com/golangci/golangci-lint/releases/download/v${version}/golangci-lint-${version}-linux-${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/golangci/golangci-lint/releases/download/v${version}/golangci-lint-${version}-darwin-${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/golangci/golangci-lint/releases/download/v${version}/golangci-lint-${version}-windows-${arch_alias}.zip` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `golangci-lint-2.15.0-checksums.txt` from the `v2.15.0` release; all 6 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}` across all 6 platform/arch targets).

## Linking

- Linux (`x86_64` and `aarch64`): statically linked Go ELF64 executables (`readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). Zero `DT_NEEDED` entries, so no `xim:glibc` runtime dependency is declared.
- Windows (`x86_64` and `aarch64`): PE32+ console executables importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`), so no `xim:vcruntime` runtime dependency is needed.

## What the hooks do

- `install`: every upstream archive wraps `golangci-lint` / `golangci-lint.exe`, `LICENSE`, and `README.md` inside `golangci-lint-<version>-<os>-<arch>/`. On Windows or when `xlings` pre-extracts the wrapper directory on POSIX, `payload.unpack{ extracted = stem, strip = 1 }` lands the contents into `pkginfo.install_dir()`; if the wrapper directory is absent on POSIX, `install()` extracts directly from the `.tar.gz` with `--strip-components=1`. On POSIX it runs `chmod +x` on `golangci-lint`, then asserts all 3 files with `payload.require(...)`.
- `config`: registers `golangci-lint` via `xvm.add("golangci-lint", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `golangci-lint` via `xvm.remove("golangci-lint")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/g/test_golangci_lint.py`, `tests/test_docs.py`, repo-wide `static or isolation`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect --only golangci-lint` passed locally on Linux `x86_64`.
- Isolated `XLINGS_HOME` & `HOME` lifecycle (`xlings install local:golangci-lint -y`, `golangci-lint --version`, `golangci-lint linters`, `golangci-lint config verify`, `golangci-lint '/?'`, `pytest tests/g/test_golangci_lint.py -m "index or verify"`, `xlings remove golangci-lint -y`) passed on Linux `x86_64`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (verified via archive layout, checksums, ELF/PE inspection, and Lua hook unit mocks; runtime execution covered by CI).

## Revision log

- 2026-11-26 — added at `2.15.0`: verified all six upstream release archives, checksums, ELF/PE linkage, and Linux `x86_64` lifecycle.
