# migrate

Database migrations CLI (`golang-migrate/migrate`), `status = "stable"`.

- Upstream: https://github.com/golang-migrate/migrate (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). 32-bit, ARMv7, `.deb` packages, and source zip (`migrate-4.20.1.zip`) are omitted.

## Source

- Tier: upstream GitHub release (`https://github.com/golang-migrate/migrate/releases`)
- GLOBAL: `migrate.linux-{amd64,arm64}.tar.gz`, `migrate.darwin-{amd64,arm64}.tar.gz`, `migrate.windows-{amd64,arm64}.zip` (note: upstream uses non-versioned asset names under the `v${version}` release tag)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `sha256sum.txt` for `v4.20.1` and verified locally via `sha256sum` against all six downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}`).

## Linking

- Linux (`x86_64`, `aarch64`): both binaries (`migrate`) are statically linked Go ELF executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`, `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- Windows (`x86_64`, `aarch64`): both PE32+ console executables (`migrate.exe`) import only `kernel32.dll` (no `VCRUNTIME140.dll` or MinGW DLL dependencies).

## What the hooks do

- install: extracts flat upstream archives directly into `pkginfo.install_dir()` (`tar -xzf` on POSIX, `payload.unpack{}` via `System32\tar.exe` on Windows, with pre-extracted fallback) and asserts `migrate[.exe]`, `LICENSE`, and `README.md` via `payload.require`.
- config: registers `migrate` with `bindir = pkginfo.install_dir()` via `xvm.add`.
- uninstall: removes `migrate` via `xvm.remove`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation checks: `pytest tests/m/test_migrate.py -m "static or isolation"`, repo-wide static checks, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect --only migrate`.
- Isolated `XLINGS_HOME` & `HOME` on Linux `x86_64`: `xlings install local:migrate@4.20.1 -y`, `migrate -version`, `migrate /?` (exits 2 cleanly), `migrate -help`, `migrate create`, `migrate -source file://... -database stub:// up`, `pytest tests/m/test_migrate.py -m "index or lifecycle or verify"`, and `xlings remove local:migrate@4.20.1 -y`.
- Not run locally: `linux` (`aarch64`), `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (no native hosts locally; macOS `.tar.gz` and Windows `.zip` hooks were exercised via Lua unit tests, and CI validates Linux `x86_64`/`aarch64`, macOS `aarch64`, and Windows `x86_64`).

## Revision log

- 2026-11-26 — added at 4.20.1: initial `spec = "2"` recipe covering Linux, macOS, and Windows (`x86_64` and `aarch64`).
