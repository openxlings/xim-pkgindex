# flux

Open and extensible continuous delivery CLI for Kubernetes (`flux`, Flux v2), `status = "stable"`.

- Upstream: https://github.com/fluxcd/flux2 (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `linux_arm` and `windows_386`, omitted because `archs` only covers 64-bit targets.

## Source

- Tier: official upstream GitHub release (`fluxcd/flux2`)
- GLOBAL: `https://github.com/fluxcd/flux2/releases/download/v${version}/flux_${version}_<os>_<arch_alias>.<ext>` (`linux`/`darwin` `.tar.gz`, `windows` `.zip`)
- CN: none yet (declares `ci = { mirror = true }` so post-merge CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: taken from upstream `flux_2.10.1_checksums.txt` and verified against locally downloaded bytes for all six targets (all matched)
- Auto-update: yes (`extensions.autoupdate` with `${tag}` and `${version}`)

## Linking

Static Go binary with zero external shared-library dependencies:
- Linux `x86_64` and `aarch64` ELFs: `readelf -d` shows no dynamic section; `ldd` reports `not a dynamic executable`. No `xim:glibc` or `xim:gcc-runtime` dependency.
- macOS `x86_64` and `aarch64`: Mach-O 64-bit executables (`DYLDLINK|PIE`).
- Windows `x86_64` (`0x8664`) and `aarch64` (`0xaa64`) PE32+ console executables: import table contains `kernel32.dll` only (no `VCRUNTIME140.dll` / `MSVCP140.dll`, no `xim:vcruntime` dependency).
- `flux "/?"` exits immediately with status 1 (`unknown command "/?" for "flux"`), so Windows CI program smoke probing will not hang.

## What the hooks do

- `install`: extracts the flat archive directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` -> `%SystemRoot%\System32\tar.exe` on Windows) with a move fallback if pre-extracted, so unrelated files in the shared download directory cannot mix into the payload; asserts `flux` / `flux.exe` via `payload.require`.
- `config`: registers `flux` via `xvm.add("flux", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `flux` via `xvm.remove("flux")`.
- System impact: none; writes only inside `pkginfo.install_dir()` and registers the `xvm` shim.

## Verification

- Verified `v2.10.1` download URLs, SHA-256 digests, archive layouts, ELF headers (`readelf -d`, `ldd`), PE headers/imports, and `flux "/?"` exit behavior across all 6 archives.
- Static & isolation pytest (`tests/f/test_flux.py -m "static or isolation"`), repo core static checks, lint scripts, and `tools/xpkg_ci.py inspect --only flux` run on `linux/x86_64`.
- Isolated `XLINGS_HOME` & `HOME` lifecycle (`xlings config --add-xpkg`, `xlings search`, `xlings install local:flux@2.10.1 -y`, `flux version --client`, `flux completion bash`, `xlings list`, `xlings remove`, `pytest -m "index or lifecycle or verify"`) verified on `linux/x86_64`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) native execution (no local hosts for those targets; covered by CI runners for `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64`, plus Lua unit tests for the Windows extraction hook).

## Revision log

- 2026-11-26 — added at `2.10.1`: initial release across `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`), flat `.tar.gz` (POSIX) and `.zip` (Windows) extraction.
