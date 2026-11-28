# cilium

CLI to install, manage & troubleshoot Kubernetes clusters running Cilium (`cilium`), `status = "stable"`.

- Upstream: https://github.com/cilium/cilium-cli (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: official upstream GitHub release (`cilium/cilium-cli`)
- GLOBAL: `https://github.com/cilium/cilium-cli/releases/download/v${version}/cilium-<os>-<arch_alias>.<ext>` (`linux`/`darwin` `.tar.gz`, `windows` `.zip`)
- CN: none yet (declares `ci = { mirror = true }` so post-merge CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: computed from locally downloaded upstream `v0.20.3` release archives for all six targets
- Auto-update: yes (`extensions.autoupdate` with `${tag}`)

## Linking

Static Go binary with zero external shared-library dependencies:
- Linux `x86_64` and `aarch64` ELFs: `readelf -d` shows no dynamic section; `ldd` reports `not a dynamic executable`. No `xim:glibc` or `xim:gcc-runtime` dependency.
- Windows `x86_64` and `aarch64` PE32+ console executables: `cilium-windows-amd64.zip` import table contains `kernel32.dll` only (no `VCRUNTIME140.dll` / `MSVCP140.dll`, no `xim:vcruntime` dependency).
- `cilium "/?"` exits immediately with status 1 (`unknown command "/?" for "cilium"`), so Windows CI program smoke probing will not hang.

## What the hooks do

- `install`: extracts the flat archive directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` -> `%SystemRoot%\System32\tar.exe` on Windows) with a move fallback if pre-extracted, so unrelated files in the shared download directory cannot mix into the payload; asserts `cilium` / `cilium.exe` via `payload.require`.
- `config`: registers `cilium` via `xvm.add("cilium", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `cilium` via `xvm.remove("cilium")`.
- System impact: none; writes only inside `pkginfo.install_dir()` and registers the `xvm` shim.

## Verification

- Verified `v0.20.3` download URLs, SHA-256 digests, archive layouts, ELF headers (`readelf -d`, `ldd`), PE headers/imports, and `cilium "/?"` + `cilium version --client` behavior.
- Static & isolation pytest (`tests/c/test_cilium.py -m "static or isolation"`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only cilium` run on `linux/x86_64`.
- Isolated `HOME=/tmp/xlings-cilium XLINGS_HOME=/tmp/xlings-cilium` lifecycle (`xlings config --add-xpkg`, `xlings install local:cilium@0.20.3 -y`, `cilium version --client`, `xlings remove`) verified on `linux/x86_64`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) native execution (covered by CI runners).

## Revision log

- 2026-11-26 — added at `0.20.3`: initial release across `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`), flat `.tar.gz` (POSIX) and `.zip` (Windows) extraction.
