# zellij

Terminal workspace and multiplexer (`zellij`; GUI terminal `zellij-terminal.exe` on Windows), status `stable`.

- Upstream: https://github.com/zellij-org/zellij (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream release `v0.46.1` publishes no Windows ARM64 archive.

## Source

- Tier: upstream release (`zellij-org/zellij` GitHub Releases)
- GLOBAL: `https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-<target>.{tar.gz,zip}`
- CN: none yet (`ci = { mirror = true }` declared for `xlings-res` mirroring)
- Checksums: archive SHA-256 digests verified against GitHub Release asset digests for `v0.46.1`, and extracted inner binaries verified with `sha256sum` against upstream `*.sha256sum` sidecars.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` for `zellij-org/zellij/releases`)

## Linking

- `linux/x86_64`: `static-pie linked` musl ELF (`DT_NEEDED` empty; `ldd` reports `statically linked`). Declares no `deps`.
- `linux/aarch64`: `statically linked` musl ELF (no `.dynamic` section). Declares no `deps`.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: `zellij.exe` (PE32+ console) and `zellij-terminal.exe` (PE32+ GUI) linked with static CRT (only Windows OS DLLs; no `VCRUNTIME140.dll` / `MSVCP140.dll`). Declares no `xim:vcruntime`.

## What the hooks do

- install: upstream archives are flat (`zellij` on POSIX; `zellij.exe` and `zellij-terminal.exe` on Windows). On POSIX, extracts `.tar.gz` directly into `pkginfo.install_dir()` via `tar -xzf` and runs `chmod +x`; on Windows, extracts `.zip` via `payload.unpack{}` (`System32\tar.exe`). Asserts extracted payloads via `payload.require`.
- config: registers `zellij` via `xvm.add("zellij", { bindir = pkginfo.install_dir() })`; on Windows also registers `zellij-terminal` bound to `zellij@<version>` (kept out of `programs` so Windows CI `/?` probing does not launch the GUI binary).
- uninstall: removes `zellij-terminal` (on Windows) and `zellij` via `xvm.remove`.
- System impact: none.

## Verification

- Verified locally on Linux `x86_64` in isolated `XLINGS_HOME`/`HOME`: `xlings config --add-xpkg`, `xlings search`, `xlings install local:zellij -y`, `which zellij`, `zellij --version`, `zellij --help`, idempotent reinstall, `xlings remove`, plus `pytest tests/z/test_zellij.py`, repo-wide static/isolation checks, `.github/scripts/check-*.sh`, `tools/lint_exec_quoting.sh`, and `tools/xpkg_ci.py inspect/materialize`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (covered by archive checksum/binary inspection, Lua sandbox hook tests, and GitHub Actions CI).

## Revision log

- 2026-11-26 — added at `0.46.1`: static musl binaries on Linux (`x86_64`, `aarch64`), Mach-O binaries on macOS (`x86_64`, `aarch64`), static-CRT flat zip on Windows (`x86_64`).
