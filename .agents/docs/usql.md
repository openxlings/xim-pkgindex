# usql

Universal command-line interface for SQL databases (`xo/usql`), `status = "stable"`.

- Upstream: https://github.com/xo/usql (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v0.21.6` publishes no Windows ARM64 asset (`usql-0.21.6-windows-amd64.zip` only).

## Source

- Tier: upstream release (`https://github.com/xo/usql/releases`)
- GLOBAL:
  - `linux`: `usql_static-${version}-linux-${arch_alias}.tar.bz2` (`amd64` / `arm64`)
  - `macosx`: `usql-${version}-darwin-${arch_alias}.tar.bz2` (`amd64` / `arm64`)
  - `windows`: `usql-${version}-windows-amd64.zip`
- CN: none yet (`ci = { mirror = true }` declared; `tools/xpkg_ci.py` validates `.tar.bz2` and `.zip` via `validate_archive`).
- Checksums: verified against GitHub release asset `digest` metadata for `v0.21.6` and `sha256sum` across all five downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- `linux/x86_64`, `linux/aarch64`: `usql_static` is a statically linked Go ELF executable (`readelf -d` reports `There is no dynamic section in this file.`; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared. (In contrast, the non-static `usql-0.21.6-linux-amd64.tar.bz2` binary dynamically links `libm.so.6`, `libstdc++.so.6`, `libgcc_s.so.1`, `libc.so.6`, and `ld-linux-x86-64.so.2`.)
- `windows/x86_64`: `usql.exe` is a PE32+ console executable; `objdump -p` shows it imports only `KERNEL32.dll` and Windows 10+ UCRT API sets (`api-ms-win-crt-*-l1-1-0.dll`, no `VCRUNTIME140.dll` or `MSVCP140.dll`). Zero `runtime` dependencies declared.

## What the hooks do

- `install()`:
  - POSIX (`linux`, `macosx`): all upstream tarballs are flat at root (`usql_static` + `LICENSE` on Linux; `usql` + `LICENSE` on macOS). Extracts `pkginfo.install_file()` directly into `pkginfo.install_dir()` via `tar -xjf` (with fallback to moving pre-extracted `usql_static`/`usql` + `LICENSE`), renames `usql_static` to `usql` on Linux, runs `chmod +x`, and asserts `usql` and `LICENSE` via `payload.require`.
  - `windows`: unpacks `usql-<version>-windows-amd64.zip` into `pkginfo.install_dir()` via `payload.unpack{}` (`%SystemRoot%\System32\tar.exe`) and asserts `usql.exe` and `LICENSE` via `payload.require`.
- `installed()`: checks `payload.present({ "usql", "LICENSE" })` or `payload.present({ "usql.exe", "LICENSE" })`.
- `config()`: registers `usql` via `xvm.add("usql", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `usql` via `xvm.remove("usql")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` and `HOME`: `xlings self init`, `xlings config --add-xpkg pkgs/u/usql.lua`, `xlings search usql`, `xlings install local:usql@0.21.6 -y`, `which usql`, `usql --version` (`usql 0.21.6`), `usql "sqlite://..." -c "select 1"`, `xlings list usql`, idempotent reinstall, `xlings remove local:usql@0.21.6 -y` (shim removed), idempotent repeat remove, and `xlings config --remove-xpkg usql`.
- Verified `python3 tools/xpkg_ci.py inspect --only usql`, `materialize usql`, and `verify` against all five upstream release assets.
- Verified `pytest tests/u/test_usql.py` across all 19 tests (`static`, `isolation`, `index`, `lifecycle`, `verify`), plus repo-wide `static or isolation` pytest, `tools/lint_exec_quoting.sh`, and `.github/scripts/check-*.sh`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (covered by Lua sandbox tests locally and by CI across Linux, macOS, and Windows).

## Revision log

- 2026-11-26 — added at 0.21.6: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64` via `usql_static`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
