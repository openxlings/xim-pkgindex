# cosign

Container signing, verification, and storage in an OCI registry (`sigstore/cosign`); provides the `cosign` CLI (status: `stable`).

- Upstream: https://github.com/sigstore/cosign (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v3.1.6` publishes no `windows-arm64` binary.

## Source

- Tier: upstream official repository release (`https://github.com/sigstore/cosign/releases`)
- GLOBAL:
  - `linux`: `https://github.com/sigstore/cosign/releases/download/v${version}/cosign-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/sigstore/cosign/releases/download/v${version}/cosign-darwin-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/sigstore/cosign/releases/download/v${version}/cosign-windows-${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge; every asset has a distinct filename with zero `materialize` basename collision)
- Checksums: taken from upstream `cosign_checksums.txt` for `v3.1.6` and verified locally via `sha256sum -c` on all 5 downloaded binaries
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/sigstore/cosign/releases`)

## Linking

- `linux/x86_64` and `linux/aarch64`: static Go ELF executables (`CGO_ENABLED=0`). Verified with `readelf -d` (no dynamic section) and `ldd` ("not a dynamic executable"). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`). PE import inspection shows only `KERNEL32.dll` and Windows 10 Universal CRT API-set DLLs (`api-ms-win-crt-*.dll`), with no `VCRUNTIME140.dll` or `MSVCP140.dll`, so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, clears and creates `pkginfo.install_dir()`, moves the downloaded raw binary to `cosign` (or `cosign.exe` when the payload ends in `.exe`), runs `chmod +x` on Unix, and verifies the target file exists.
- `config`: registers `cosign` with `xvm.add("cosign", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("cosign")`.
- System impact: none (no shell profile, `PATH`, or system configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/c/test_cosign.py -m "static or isolation"`
  - `tools/xpkg_ci.py inspect --only cosign` and `tools/xpkg_ci.py materialize --package cosign`
  - Repo-wide static/isolation checks, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`
  - Isolated `XLINGS_HOME` & `HOME`: `xlings config --add-xpkg pkgs/c/cosign.lua`, `xlings search cosign`, `xlings install local:cosign -y`, `cosign version`, offline `cosign generate-key-pair` / `signing-config create` / `sign-blob` / `verify-blob`, `pytest tests/c/test_cosign.py -m "index or lifecycle or verify"`, and `xlings remove local:cosign -y`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (not on host; covered by CI runners for `linux`, `macosx` arm64, `windows` x86_64, plus SHA-256 and `materialize` verification for all 5 assets).

## Revision log

- 2026-11-26 — added at 3.1.6: initial spec-2 recipe using upstream single-file binaries for linux (x86_64, aarch64), macosx (x86_64, aarch64), and windows (x86_64).
