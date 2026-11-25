# websocat

Command-line client for WebSockets, like netcat (or curl) for `ws://` with advanced socat-like functions. Provides the `websocat` command (`status = "stable"`).

- Upstream: https://github.com/vi/websocat (MIT)
- Namespace: `xim`
- Platforms: Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), Windows (`x86_64`). Windows `aarch64` is not published by upstream and is omitted.

## Source

- Tier: upstream release (`vi/websocat` GitHub Releases)
- GLOBAL: `https://github.com/vi/websocat/releases/download/v${version}/websocat.${arch}-...` (per-platform `xpm.<os>.source`, distinct filename per target triple)
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: SHA-256 digests from the GitHub Release API (`gh release view --repo vi/websocat`) cross-checked against `sha256sum` of all 5 downloaded binaries; exact match.
- Auto-update: yes (`extensions.autoupdate` with `${tag}`)

## Linking

- `linux/x86_64`: `websocat.x86_64-unknown-linux-musl` — `ELF 64-bit LSB pie executable, static-pie linked, stripped`; `readelf -l` has no `PT_INTERP`, `readelf -d` has no `DT_NEEDED` (`STRTAB` 1 byte), `ldd` reports `statically linked`.
- `linux/aarch64`: `websocat.aarch64-unknown-linux-musl` — `ELF 64-bit LSB executable, statically linked, stripped`; `readelf -l` has no `PT_INTERP`, `readelf -d` reports no dynamic section.
- `windows/x86_64`: `websocat.x86_64-pc-windows-gnu.exe` — MinGW-w64 `PE32+ executable`; `objdump -p` imports only standard Windows system DLLs (`ntdll.dll`, `crypt32.dll`, `kernel32.dll`, `ncrypt.dll`, `secur32.dll`, `ws2_32.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `bcryptprimitives.dll`, `ADVAPI32.dll`, `bcrypt.dll`, `msvcrt.dll`) — no `VCRUNTIME140.dll` or MinGW runtime DLLs.
- No runtime or build `deps` required.

## What the hooks do

- `install`: moves the standalone `pkginfo.install_file()` binary into `pkginfo.install_dir()` as `websocat` (Unix, with `chmod +x`) or `websocat.exe` (Windows), and verifies the target file exists.
- `config`: registers `websocat` via `xvm.add("websocat", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `websocat` via `xvm.remove("websocat")`.
- System impact: none; all files reside inside the xlings package store and subos shim directory.

## Verification

- Verified locally on Linux `x86_64` in an isolated `$XLINGS_HOME` (install, `--version`, literal echo, idempotent reinstall, remove, idempotent re-remove, index overlay cleanup) and with pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`) plus repo-wide static/revision/dep-namespace checks and `tools/xpkg_ci.py` inspect/materialize.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64` runtime execution (not on host OS/arch; URLs, SHA-256s, ELF/PE headers verified from downloaded release assets; covered by CI matrix).

## Revision log

- 2026-11-25 — added at `1.14.2`: initial spec-2 recipe using upstream standalone musl/darwin/mingw-gnu binaries.
