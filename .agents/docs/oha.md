# oha

HTTP load generator with real-time TUI, inspired by rakyll/hey. Provides the `oha` command (`status = "stable"`).

- Upstream: https://github.com/hatoo/oha (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream v1.17.0 publishes no Windows ARM64 binary.

## Source

- Tier: official repository release (`hatoo/oha`)
- GLOBAL:
  - `https://github.com/hatoo/oha/releases/download/v${version}/oha-linux-${arch_alias}`
  - `https://github.com/hatoo/oha/releases/download/v${version}/oha-macos-${arch_alias}`
  - `https://github.com/hatoo/oha/releases/download/v${version}/oha-windows-${arch_alias}.exe`
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge)
- Checksums: GitHub Release API digests for v1.17.0 matched `sha256sum` of all 5 downloaded binaries.
- Auto-update: yes (`extensions.autoupdate`, tracking `https://github.com/hatoo/oha/releases`)

## Linking

- `linux/x86_64` (`oha-linux-amd64`): ELF64 static-pie (`readelf -d`: no `DT_NEEDED`, no `PT_INTERP`; `ldd`: `statically linked`). Declares no runtime dependencies.
- `linux/aarch64` (`oha-linux-arm64`): ELF64 static (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Declares no runtime dependencies.
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables. Declares no runtime dependencies.
- `windows/x86_64` (`oha-windows-amd64.exe`): PE32+ console executable importing `VCRUNTIME140.dll`, UCRT `api-ms-win-crt-*.dll`, and Windows system DLLs. Declares `deps = { runtime = { "xim:vcruntime" } }`.

## What the hooks do

- install: cleans `pkginfo.install_dir()`, creates it with `fs.mkdir_p`, moves the raw downloaded binary to `oha` (or `oha.exe` on Windows), copies `xim:vcruntime/bin/*.dll` beside `oha.exe` on Windows, runs `chmod +x` on Unix, and verifies the target file exists.
- config: registers `oha` with `xvm.add("oha", { bindir = pkginfo.install_dir() })`.
- uninstall: calls `xvm.remove("oha")`.
- System impact: none; only writes inside the xlings store and subos xvm registry.

## Verification

- Linux `x86_64` verified in an isolated `XLINGS_HOME` & `HOME`: `xlings config --add-xpkg`, `xlings search oha`, `xlings install oha@1.17.0 -y`, `oha --version` (`oha 1.17.0`), `oha -n 5 -c 1 --no-tui http://127.0.0.1:<port>/` (`100.00%`, `[200] 5 responses`), idempotent reinstall, `xlings remove oha -y`, idempotent re-remove, plus `dep-closure-check.sh` and pytest (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64` (covered by CI / asset inspection).

## Revision log

- 2026-11-26 — added at 1.17.0: raw single-file upstream binaries across 5 targets (`linux/{x86_64,aarch64}`, `macosx/{x86_64,aarch64}`, `windows/x86_64` with app-local `xim:vcruntime` DLL copy).
