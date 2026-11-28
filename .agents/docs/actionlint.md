# actionlint

Static checker for GitHub Actions workflow files. Provides the `actionlint` CLI command; status `stable`.

- Upstream: https://github.com/rhysd/actionlint (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (`rhysd/actionlint` GitHub Releases)
- GLOBAL: `https://github.com/rhysd/actionlint/releases/download/${tag}/actionlint_${version}_<os>_<arch>.(tar.gz|zip)`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against upstream `actionlint_1.7.12_checksums.txt` and confirmed with `sha256sum -c` across all six downloaded archives (`linux`/`darwin`/`windows` x `amd64`/`arm64`).
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}` for all six platform/arch targets).

## Linking

- Linux (`amd64` and `arm64`): statically linked Go ELF executables (`readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). Zero `DT_NEEDED` entries, so no `xim:glibc` runtime dependency is declared.
- Windows (`amd64` and `arm64`): PE32+ executables importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`), so no `xim:vcruntime` runtime dependency is needed.

## What the hooks do

- `install`: extracts the flat upstream archive directly into `pkginfo.install_dir()` (using `tar -xzf` on POSIX + `chmod +x`, or `xim.pkgindex.payload.unpack{}` via `System32\tar.exe` on Windows, with pre-extracted binary fallback), then asserts `actionlint` / `actionlint.exe` with `payload.require`.
- `config`: registers `actionlint` via `xvm.add("actionlint", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `actionlint` via `xvm.remove("actionlint")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/a/test_actionlint.py` and repo-wide `tests/`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect/materialize` run on Linux `x86_64`.
- End-to-end isolated `XLINGS_HOME` & `HOME` lifecycle (`xlings install local:actionlint -y`, `actionlint -version`, linting valid & invalid workflow YAMLs, `pytest -m "index or verify"`, `xlings remove actionlint -y`, and clean `local` xpkg removal) verified on Linux `x86_64`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64`, `windows/aarch64` (covered by CI and verified via archive layout, checksum, ELF/PE inspection).

## Revision log

- 2026-11-26 — added at `1.7.12`: verified all six upstream release archives, checksums, ELF/PE linkage, and Linux `x86_64` lifecycle.
