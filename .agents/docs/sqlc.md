# sqlc

Generate type-safe code from SQL (`sqlc` CLI, `status = "stable"`).

- Upstream: https://github.com/sqlc-dev/sqlc (MIT)
- Homepage: https://sqlc.dev
- Docs: https://docs.sqlc.dev
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (`https://github.com/sqlc-dev/sqlc/releases`)
- GLOBAL:
  - Linux: `sqlc_${version}_linux_{amd64,arm64}.tar.gz`
  - macOS: `sqlc_${version}_darwin_{amd64,arm64}.tar.gz`
  - Windows: `sqlc_${version}_windows_{amd64,arm64}.zip`
- CN: none yet (`ci = { mirror = true }` requested for `xlings-res` mirroring)
- Checksums: all 6 SHA-256 hashes match the upstream `v1.31.1` release asset digests and locally downloaded archives (`sha256sum`).
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF64 executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- Windows (`x86_64`, `aarch64`): PE32+ console executables (`sqlc.exe`) importing only `kernel32.dll` (no VCRUNTIME or MinGW DLL dependencies).

## What the hooks do

- `installed`: checks `payload.present({ "sqlc" })` or `payload.present({ "sqlc.exe" })`.
- `install`: cleans `pkginfo.install_dir()`, extracts the flat `.tar.gz` directly into `install_dir` on POSIX (`tar -xf ... -C ...` + `chmod +x`) or `.zip` via `libs/payload.lua` (`%SystemRoot%\System32\tar.exe`) on Windows (with a pre-extracted fallback), and asserts `sqlc` / `sqlc.exe` via `payload.require`.
- `config`: registers `sqlc` with `xvm.add("sqlc", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `sqlc` via `xvm.remove("sqlc")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `HOME` & `XLINGS_HOME`:
  - `xlings config --add-xpkg pkgs/s/sqlc.lua`
  - `xlings search sqlc`
  - `xlings install local:sqlc@1.31.1 -y`
  - `sqlc version`, `sqlc generate` (offline SQLite schema + query -> Go codegen), `sqlc /?` (exits immediately without blocking)
  - `xlings list sqlc`, idempotent reinstall, `xlings remove local:sqlc -y`, idempotent re-remove, `xlings config --remove-xpkg sqlc`
- Ran `pytest tests/s/test_sqlc.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repo-wide `static or isolation`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect/materialize`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (checked all 6 release archives, checksums, layouts, ELF/PE headers, and Lua sandbox hooks instead; CI validates Linux, macOS, and Windows).

## Revision log

- 2026-11-26 — added at `1.31.1`: initial spec-2 recipe with `extensions.autoupdate` and `ci = { mirror = true }`.
