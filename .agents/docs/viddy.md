# viddy

A modern `watch` command with time machine mode and pager (`viddy`), `status = "stable"`.

- Upstream: <https://github.com/sachaos/viddy> (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream also publishes `linux-i686`, which is omitted because xlings targets `x86_64` and `aarch64`; `windows/aarch64` is omitted because upstream publishes no Windows ARM64 asset (and `xim:vcruntime` currently ships `x86_64` only).

## Source

- Tier: official repository release (`sachaos/viddy`, tag `v1.3.1`)
- GLOBAL: `https://github.com/sachaos/viddy/releases/download/v${version}/viddy-v${version}-{linux,macos,windows}-${arch_alias}.tar.gz` (note Windows ships `.tar.gz`, not `.zip`; every archive is flat at root containing only `viddy` or `viddy.exe`)
- CN: none yet (`ci = { mirror = true }` declared; mirroring handled by CI/xlings-res)
- Checksums: matched against upstream per-asset `.sha256` sidecars and verified locally across all five archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}`).

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -d` shows no `DT_NEEDED` and no `PT_INTERP`; `readelf -V` shows no symbol version info; `ldd` reports `statically linked`). Zero runtime dependencies declared.
- `linux/aarch64`: statically linked ELF (`readelf -d` reports no dynamic section; `readelf -V` shows no symbol version info). Zero runtime dependencies declared.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ CUI executable (`viddy.exe`) importing `VCRUNTIME140.dll` and Windows UCRT/OS DLLs. Declares runtime dependency `xim:vcruntime` and copies its DLLs app-local beside `viddy.exe`.
- Note on `programs = {"viddy"}`: `viddy /?` treats `/?` as a command to watch in its full-screen TUI rather than printing help; `windows-test.ps1` automatically falls back to `viddy --version`, which prints version info and exits 0.

## What the hooks do

- `installed`: checks `payload.present` for `viddy` or `viddy.exe`.
- `install`: extracts the flat `.tar.gz` directly into `pkginfo.install_dir()` (using `%SystemRoot%\System32\tar.exe` on Windows because `libs/payload.lua` only dispatches `.zip`, and `shell.exec` `tar -xzf` + `chmod +x` on POSIX; falls back to moving a pre-extracted binary from the parent cache dir), copies `xim:vcruntime` DLLs app-local beside `viddy.exe` on Windows, and asserts `viddy` / `viddy.exe` via `payload.require`.
- `config`: registers `viddy` via `xvm.add("viddy", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `viddy` via `xvm.remove("viddy")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `HOME` & `XLINGS_HOME` (`/tmp/xlings-viddy`): `xlings config --add-xpkg`, `xlings search viddy`, `xlings install local:viddy@1.3.1 -y`, `viddy --version`, `viddy --help`, `xlings list viddy`, idempotent reinstall, `dep-closure-check.sh`, `xlings remove local:viddy@1.3.1 -y`, and `xlings config --remove-xpkg viddy`.
- Ran `pytest tests/v/test_viddy.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), full `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only viddy`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (Windows `.tar.gz` + `xim:vcruntime` hook was exercised via Lua unit tests, all 5 archives & checksums verified locally, and CI validates Linux, macOS, and Windows).

## Revision log

- 2026-11-26 — added at `1.3.1`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64` with `xim:vcruntime`).
