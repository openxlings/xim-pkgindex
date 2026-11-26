# bottom

Cross-platform graphical process/system monitor for the terminal (command `btm`, status: `stable`).

- Upstream: https://github.com/ClementTsang/bottom (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because `bottom_aarch64-pc-windows-msvc.zip` imports `VCRUNTIME140.dll` while `xim:vcruntime` currently ships `x86_64` only, and `bottom_aarch64-pc-windows-gnullvm.zip` imports `libunwind.dll`.

## Source

- Tier: official repository release (`ClementTsang/bottom`)
- GLOBAL:
  - `linux`: `https://github.com/ClementTsang/bottom/releases/download/${version}/bottom_${arch_alias}-unknown-linux-musl.tar.gz`
  - `macosx`: `https://github.com/ClementTsang/bottom/releases/download/${version}/bottom_${arch_alias}-apple-darwin.tar.gz`
  - `windows`: `https://github.com/ClementTsang/bottom/releases/download/${version}/bottom_${arch_alias}-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL to `xlings-res` after merge)
- Checksums: GitHub release `0.15.0` asset `digest` fields, verified by downloading all archives and matching `sha256sum`
- Auto-update: yes (`extensions.autoupdate`)

## Linking

- `linux/x86_64` (`-musl`): static-pie ELF, zero `DT_NEEDED` entries, `ldd`: `statically linked`.
- `linux/aarch64` (`-musl`): statically linked ELF, no dynamic section, `ldd`: not a dynamic executable.
  (Upstream `-gnu` builds dynamically link `libgcc_s.so.1`, `libm.so.6`, `libc.so.6`, so `-musl` is chosen; zero runtime dependencies declared.)
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64` (`-msvc`): PE32+ executable importing only Windows OS DLLs (`kernel32.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `shell32.dll`, `combase.dll`, `ntdll.dll`, `ole32.dll`, `oleaut32.dll`, `setupapi.dll`, `advapi32.dll`, `powrprof.dll`, `iphlpapi.dll`, `netapi32.dll`, `secur32.dll`, `pdh.dll`, `psapi.dll`, `bcryptprimitives.dll`, `USER32.dll`); no `VCRUNTIME140.dll` or delay-load imports, so no `xim:vcruntime` dependency is needed.

## What the hooks do

- install: all upstream archives are flat (`btm`/`btm.exe` and `completion/` at the root with no enclosing directory), so `install()` unpacks directly into `pkginfo.install_dir()` (`payload.unpack{}` on Windows, `tar -xzf` + `chmod +x` via `xim.pkgindex.shell` on POSIX) and asserts `btm`/`btm.exe` via `payload.require`.
- config: registers `btm` (`bindir = pkginfo.install_dir()`) and `bottom` (`type = "group"`).
- uninstall: removes `btm` and `bottom` from xvm.
- System impact: none (no shell profile, `PATH`, or host files modified).

## Verification

- Static & isolation tests (`pytest tests/b/test_bottom.py -m "static or isolation" -v`, full `tests/ -m "static or isolation"`), `lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect/materialize`, and isolated `XLINGS_HOME` & `HOME` install (`local:bottom`), `btm --version`, `dep-closure-check.sh`, `pytest -m "index or lifecycle or verify"`, and `xlings remove` on Linux `x86_64`.
- `linux/aarch64`, `macosx`, and `windows` runtime installs are verified by CI runners (archives and digests verified locally).

## Revision log

- 2026-11-26 — added at 0.15.0: initial package using Linux `-musl` static binaries, macOS `-apple-darwin`, Windows `x86_64-pc-windows-msvc` (static CRT), and `btm` + `bottom` group xvm registration.
