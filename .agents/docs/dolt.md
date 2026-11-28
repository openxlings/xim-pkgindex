# dolt

Git for Data — a SQL database that you can fork, clone, branch, merge, push, and pull like a Git repository. Provides the `dolt` command (`status = "stable"`).

- Upstream: https://www.dolthub.com / https://github.com/dolthub/dolt (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream v2.7.7 publishes no Windows ARM64 asset.

## Source

- Tier: upstream release (`dolthub/dolt`, tag `v2.7.7`)
- GLOBAL:
  - `linux/x86_64`: `https://github.com/dolthub/dolt/releases/download/${tag}/dolt-linux-amd64.tar.gz`
  - `linux/aarch64`: `https://github.com/dolthub/dolt/releases/download/${tag}/dolt-linux-arm64.tar.gz`
  - `macosx/x86_64`: `https://github.com/dolthub/dolt/releases/download/${tag}/dolt-darwin-amd64.tar.gz`
  - `macosx/aarch64`: `https://github.com/dolthub/dolt/releases/download/${tag}/dolt-darwin-arm64.tar.gz`
  - `windows/x86_64`: `https://github.com/dolthub/dolt/releases/download/${tag}/dolt-windows-amd64.zip`
- CN: none yet (`ci = { mirror = true }`; CI will mirror GLOBAL assets to `xlings-res`)
- Checksums: GitHub release asset SHA256 digests matched local `sha256sum` across all five downloaded archives at `2.7.7`.
- Auto-update: yes (`extensions.autoupdate` against `https://github.com/dolthub/dolt/releases`, `GLOBAL` only).

## Linking

- `linux/x86_64`: statically linked Go ELF (`readelf -l`: no `PT_INTERP`; `readelf -d`: no dynamic section; `readelf -V`: no version info; `ldd`: not a dynamic executable). Zero `runtime` deps declared.
- `linux/aarch64`: statically linked Go ELF (`readelf -l`: no `PT_INTERP`; `readelf -d`: no dynamic section; `readelf -V`: no version info). Zero `runtime` deps declared.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit `x86_64` and `arm64` executables.
- `windows/x86_64`: PE32+ executable importing only `ADVAPI32.dll`, `KERNEL32.dll`, and `msvcrt.dll` (no `VCRUNTIME140.dll` or `MSVCP140.dll` dependency).
- Program probe (`/?`): `dolt /?` exits immediately (exit 1: `Unknown Command /?`) without blocking.

## What the hooks do

- `installed()`: checks `payload.present({ "bin/dolt" })` or `payload.present({ "bin/dolt.exe" })`.
- `install()`: unpacks `dolt-<os>-<arch>/` into `pkginfo.install_dir()` via `payload.unpack{ extracted = candidates, strip = 1 }` (moving the pre-extracted directory on POSIX or extracting the `.zip` via `%SystemRoot%\System32\tar.exe --strip-components=1` on Windows), runs `chmod +x` on `bin/dolt` on POSIX, and asserts `bin/dolt` (or `bin/dolt.exe`) via `payload.require`.
- `config()`: registers `dolt` with `bindir = pkginfo.install_dir() .. "/bin"` via `xvm.add`.
- `uninstall()`: removes `dolt` via `xvm.remove`.
- System impact: none outside `XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` (`HOME=/tmp/xlings-dolt XLINGS_HOME=/tmp/xlings-dolt`): `xlings config --add-xpkg`, `xlings search dolt`, `xlings install dolt@2.7.7 -y`, `dolt version`, `dolt init`/`sql`/`add`/`commit`/`log` smoke test, idempotent reinstall, `xlings remove dolt -y`, and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows/x86_64` runtime installs (no local ARM64/macOS/Windows hosts; all 5 upstream archives downloaded, SHA256s verified, ELF/PE/Mach-O headers inspected, and POSIX/Windows hooks exercised via Lua unit tests).

## Revision log

- 2026-11-26 — added at `2.7.7`.
