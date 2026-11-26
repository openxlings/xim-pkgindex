# frp

Fast reverse proxy to expose a local server behind a NAT or firewall to the internet (`frpc`, `frps`), `status = "stable"`.

- Upstream: https://gofrp.org / https://github.com/fatedier/frp (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). 32-bit, MIPS, RISC-V, Loong64, Android, and BSD upstream builds are omitted.

## Source

- Tier: upstream GitHub release (`https://github.com/fatedier/frp/releases`)
- GLOBAL: `frp_${version}_linux_{amd64,arm64}.tar.gz`, `frp_${version}_darwin_{amd64,arm64}.tar.gz`, `frp_${version}_windows_{amd64,arm64}.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `frp_sha256_checksums.txt` for `v0.72.0` and verified locally via `sha256sum -c --ignore-missing frp_sha256_checksums.txt` against all six downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- Linux (`x86_64`, `aarch64`): both binaries (`frpc`, `frps`) are statically linked Go ELF executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`, `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- Windows (`x86_64`, `aarch64`): both PE32+ executables (`frpc.exe`, `frps.exe`) import only `kernel32.dll` (no `VCRUNTIME140.dll` or MinGW DLL dependencies).

## What the hooks do

- install: unpacks `frp_<version>_<os>_<arch>/` into `pkginfo.install_dir()` via `payload.unpack` (handles pre-extracted directory moves and Windows `.zip` extraction via `System32\tar.exe`), and asserts `frpc[.exe]`, `frps[.exe]`, and `LICENSE` via `payload.require`.
- config: registers `frp` as a binding-group root (`type = "group"`, preventing an orphan `frp` shim) and registers `frpc` and `frps` with `bindir = pkginfo.install_dir()` and `binding = "frp@" .. pkginfo.version()`.
- uninstall: removes `frps`, `frpc`, and `frp` via `xvm.remove`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation checks: `pytest tests/f/test_frp.py -m "static or isolation"`, repo-wide static checks, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect/materialize`.
- Isolated `XLINGS_HOME` & `HOME` on Linux `x86_64`: `xlings install local:frp -y`, `frpc --version`, `frps --version`, `frpc verify`, `frps verify`, `pytest tests/f/test_frp.py -m "index or lifecycle or verify"`, and `xlings remove local:frp -y`.
- Not run locally: `linux` (`aarch64`), `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (no native hosts locally; macOS `.tar.gz` and Windows `.zip` hooks were exercised via Lua unit tests, and CI validates Linux `x86_64`/`aarch64`, macOS `aarch64`, and Windows `x86_64`/`aarch64`).

## Revision log

- 2026-11-26 — added at 0.72.0: initial `spec = "2"` recipe covering Linux, macOS, and Windows (`x86_64` and `aarch64`) with `frpc` and `frps` bound to `frp`.
