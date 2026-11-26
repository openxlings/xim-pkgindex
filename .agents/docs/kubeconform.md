# kubeconform

Fast Kubernetes manifests validator with support for Custom Resources (`kubeconform`), `status = "stable"`.

- Upstream: https://github.com/yannh/kubeconform (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `linux-armv6`, omitted because `archs` only covers 64-bit targets.

## Source

- Tier: official upstream GitHub release (`yannh/kubeconform`)
- GLOBAL: `https://github.com/yannh/kubeconform/releases/download/v${version}/kubeconform-<os>-<arch_alias>.<ext>` (`linux`/`darwin` `.tar.gz`, `windows` `.zip`)
- CN: none yet (declares `ci = { mirror = true }` so post-merge CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: taken from upstream `CHECKSUMS` on `v0.8.0` and verified against locally downloaded bytes for all six targets (all matched)
- Auto-update: yes (`extensions.autoupdate` with `${tag}`)

## Linking

Static Go binary with zero external shared-library dependencies:
- Linux `x86_64` and `aarch64` ELFs: `readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable. No `xim:glibc` or `xim:gcc-runtime` dependency.
- macOS `x86_64` and `aarch64`: Mach-O 64-bit executables (`DYLDLINK|PIE`).
- Windows `x86_64` (`0x8664`) and `aarch64` (`0xaa64`) PE32+ console executables: import table contains `kernel32.dll` only (no `VCRUNTIME140.dll` / `MSVCP140.dll`, no `xim:vcruntime` dependency).
- `kubeconform "/?"` does not block reading stdin (verified with `/dev/null` and a pty) and exits immediately with status 1 (`/? - failed validation: lstat /?: no such file or directory`), so Windows CI program smoke probing will not hang.

## What the hooks do

- `install`: extracts the flat archive directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` -> `%SystemRoot%\System32\tar.exe` on Windows) with a move fallback if pre-extracted, so unrelated files in the shared download directory cannot mix into the payload; asserts `kubeconform` / `kubeconform.exe` via `payload.require`.
- `config`: registers `kubeconform` via `xvm.add("kubeconform", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `kubeconform` via `xvm.remove("kubeconform")`.
- System impact: none; writes only inside `pkginfo.install_dir()` and registers the `xvm` shim.

## Verification

- Verified `v0.8.0` download URLs, SHA-256 digests, archive layouts, ELF headers (`readelf -d`, `readelf -l`, `ldd`), PE headers/imports, and `kubeconform "/?"` non-blocking exit behavior across all 6 archives.
- Static, isolation, index, lifecycle, and verify pytest suites (`tests/k/test_kubeconform.py`), repo-wide static checks, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect --only kubeconform`, and isolated `XLINGS_HOME`/`HOME` install/run/remove verified on `linux/x86_64`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) native execution (no local hosts for those targets; covered by CI runners for `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64`, plus Lua unit tests for the Windows extraction hook).

## Revision log

- 2026-11-26 — added at `0.8.0`: initial release across `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`), flat `.tar.gz` (POSIX) and `.zip` (Windows) extraction.
