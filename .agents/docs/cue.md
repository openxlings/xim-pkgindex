# cue

Validate and define text-based and dynamic configuration with the CUE language. Provides the `cue` CLI command; status `stable`.

- Upstream: https://github.com/cue-lang/cue (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (`cue-lang/cue` GitHub Releases)
- GLOBAL: `https://github.com/cue-lang/cue/releases/download/${tag}/cue_${tag}_<os>_<arch>.(tar.gz|zip)`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against GitHub release asset SHA256 digests of `v0.18.0` and confirmed with `sha256sum` across all six downloaded archives (`linux`/`darwin`/`windows` x `amd64`/`arm64`; upstream does not ship a `checksums.txt` asset for `v0.18.0`).
- Auto-update: yes (`extensions.autoupdate` using `${tag}` for all six platform/arch targets).

## Linking

- Linux (`amd64` and `arm64`): statically linked Go ELF executables (`CGO_ENABLED=0`; `readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). Zero `DT_NEEDED` entries, so no `xim:glibc` runtime dependency is declared.
- Windows (`amd64` and `arm64`): PE32+ executables importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`), so no `xim:vcruntime` runtime dependency is needed.

## What the hooks do

- `install`: extracts the flat upstream archive directly into `pkginfo.install_dir()` (using `tar -xzf` on POSIX + `chmod +x`, or `xim.pkgindex.payload.unpack{}` via `System32\tar.exe` on Windows, with pre-extracted binary fallback), then asserts `cue` / `cue.exe` with `payload.require`.
- `config`: registers `cue` via `xvm.add("cue", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `cue` via `xvm.remove("cue")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/c/test_cue.py` and repo-wide `tests/`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect/materialize` run on Linux `x86_64`.
- End-to-end isolated `XLINGS_HOME` & `HOME` lifecycle (`xlings install local:cue -y`, `cue version`, `cue eval` / `cue vet`, `pytest -m "index or lifecycle or verify"`, `xlings remove cue -y`, and clean `local` xpkg removal) verified on Linux `x86_64`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64`, `windows/aarch64` (covered by CI and verified via archive layout, checksum, and ELF/PE inspection).

## Revision log

- 2026-11-26 — added at `0.18.0`: verified all six upstream release archives, SHA256 digests, ELF/PE linkage, and Linux `x86_64` lifecycle.
