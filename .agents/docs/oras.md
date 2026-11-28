# oras

OCI registry client for managing content such as artifacts, images, and packages (`oras-project/oras`, `status = "stable"`).

- Upstream: https://github.com/oras-project/oras (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `freebsd/amd64` and Linux `armv7`, `loong64`, `ppc64le`, `riscv64`, `s390x`, which are omitted since xlings targets `x86_64` and `aarch64`.

## Source

- Tier: upstream official release (`https://github.com/oras-project/oras/releases`)
- GLOBAL:
  - `linux`: `oras_${version}_linux_${arch_alias}.tar.gz` (`amd64`, `arm64`)
  - `macosx`: `oras_${version}_darwin_${arch_alias}.tar.gz` (`amd64`, `arm64`)
  - `windows`: `oras_${version}_windows_${arch_alias}.zip` (`amd64`, `arm64`)
- CN: none (`ci = { mirror = true }`)
- Checksums: taken from upstream `oras_1.4.0_checksums.txt` and verified locally via `sha256sum -c --ignore-missing` across all six downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- `linux/x86_64` and `linux/aarch64`: statically linked, stripped Go ELF executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`, `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64` and `windows/aarch64`: PE32+ console executables (`0x8664` and `0xaa64`) importing only `kernel32.dll` (no `VCRUNTIME140.dll` or `MSVCP140.dll` dependencies).

## What the hooks do

- `install`: extracts the flat archive directly into `pkginfo.install_dir()` (using `libs/payload.lua` / `%SystemRoot%\System32\tar.exe` for `.zip` on Windows, and `tar -xzf` on POSIX, with a pre-extracted fallback moving `oras`/`oras.exe` and `LICENSE`), sets executable permissions with `chmod +x` on POSIX, and asserts `oras` / `oras.exe` plus `LICENSE` via `payload.require`.
- `config`: registers `oras` with `xvm.add("oras", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `oras` via `xvm.remove("oras")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on `linux/x86_64` in an isolated `HOME=/tmp/xlings-oras XLINGS_HOME=/tmp/xlings-oras`:
  - `xlings config --add-xpkg pkgs/o/oras.lua`, `xlings search oras`, `xlings install local:oras@1.4.0 -y`, `oras version`, `oras completion bash`, offline `oras push` / `manifest fetch` / `pull` with `--oci-layout`, `xlings list oras`, idempotent reinstall, `xlings remove local:oras -y`, and `xlings config --remove-xpkg oras`.
  - `pytest tests/o/test_oras.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only oras`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (covered by Lua hook unit tests for Windows `.zip` and pre-extracted fallbacks, SHA256 + ELF/PE inspection across all 6 archives, and CI runners for Linux, macOS, and Windows).

## Revision log

- 2026-11-26 — added at 1.4.0: initial `spec = "2"` recipe covering Linux, macOS, and Windows (`x86_64`, `aarch64`).
