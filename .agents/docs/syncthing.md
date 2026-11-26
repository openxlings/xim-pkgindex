# syncthing

Open Source Continuous File Synchronization (`syncthing`), `status = "stable"`.

- Upstream: https://syncthing.net / https://github.com/syncthing/syncthing (MPL-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Other architectures/OSes (`386`, `arm`, `loong64`, `ppc64le`, `riscv64`, `s390x`, `bsd`, `illumos`, `.deb`) and `macos-universal` are omitted.

## Source

- Tier: upstream GitHub release (`https://github.com/syncthing/syncthing/releases`)
- GLOBAL: `syncthing-linux-{amd64,arm64}-v${version}.tar.gz`, `syncthing-macos-{amd64,arm64}-v${version}.zip`, `syncthing-windows-{amd64,arm64}-v${version}.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `sha256sum.txt.asc` for `v2.1.7` and verified locally via `sha256sum` against all six downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF64 executables with no `.dynamic` section (`readelf -d` reports `There is no dynamic section in this file.`, `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- Windows (`x86_64`, `aarch64`): PE32+ executables (`syncthing.exe`) import only `KERNEL32.dll` and Windows UCRT (`api-ms-win-crt-*.dll`), with no `VCRUNTIME140.dll` dependency.

## What the hooks do

- install: unpacks `syncthing-<os>-<arch>-v<version>/` into `pkginfo.install_dir()` via `payload.unpack` and asserts `syncthing[.exe]` via `payload.require`.
- config: registers `syncthing` with `xvm.add("syncthing", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `syncthing` via `xvm.remove("syncthing")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation checks: `pytest tests/ -m "static or isolation" -q`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only syncthing`.
- Isolated `XLINGS_HOME` & `HOME` on Linux `x86_64`: `syncthing --version`, `syncthing /?` (exits 80 without starting daemon).
- Not run locally: `linux` (`aarch64`), `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (covered by CI runners).

## Revision log

- 2026-11-26 — added at 2.1.7: initial `spec = "2"` recipe covering Linux, macOS, and Windows (`x86_64` and `aarch64`).
