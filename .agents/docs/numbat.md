# numbat

Statically typed programming language for scientific computations with first class support for physical dimensions and units (`numbat`), status `stable`.

- Upstream: https://github.com/sharkdp/numbat (`MIT` / `Apache-2.0`)
- Homepage & docs: https://numbat.dev / https://numbat.dev/docs/
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is not covered because upstream v1.24.0 publishes no Windows ARM64 asset and `xim:vcruntime` is `x86_64`-only.

## Source

- Tier: upstream official repository release (`sharkdp/numbat` tag `v1.24.0`)
- GLOBAL:
  - `linux`: `https://github.com/sharkdp/numbat/releases/download/v${version}/numbat-v${version}-${arch_alias}.tar.gz` (`x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl`)
  - `macosx`: `https://github.com/sharkdp/numbat/releases/download/v${version}/numbat-v${version}-${arch}-apple-darwin.tar.gz`
  - `windows`: `https://github.com/sharkdp/numbat/releases/download/v${version}/numbat-v${version}-${arch}-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge)
- Checksums: GitHub release asset SHA256 digests matched local `sha256sum` on all five downloaded archives.
- Auto-update: yes (`extensions.autoupdate` tracking `https://github.com/sharkdp/numbat/releases`)

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -l`: no `PT_INTERP`; `readelf -d`: `statically linked`, no `DT_NEEDED`; `ldd`: `statically linked`) — zero runtime dependencies.
- `linux/aarch64`: static musl ELF (no `PT_INTERP`, no dynamic section) — zero runtime dependencies.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit executables.
- `windows/x86_64`: PE32+ console x86-64 importing `VCRUNTIME140.dll`, `api-ms-win-crt-*.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `bcryptprimitives.dll`, `bcrypt.dll`, `KERNEL32.dll`, `USER32.dll`, `SHELL32.dll`, `ADVAPI32.dll`, `ole32.dll`, `ws2_32.dll`, `ntdll.dll`. Declares `xim:vcruntime` as a runtime dep and copies CRT DLLs app-local beside `numbat.exe`.

## What the hooks do

- `installed()`: verifies the `numbat` / `numbat.exe` binary plus `modules/prelude.nbt` and `modules/all.nbt` are present in `install_dir`.
- `install()`: unpacks the `numbat-v<ver>-<target>/` wrapper directory via `payload.unpack{ extracted = stem, strip = 1 }` (preserving `numbat`, `modules/`, `assets/`, licenses, and `README.md`), copies `xim:vcruntime` DLLs into `install_dir` on Windows, and asserts `numbat` / `numbat.exe`, `modules/prelude.nbt`, and `modules/all.nbt` via `payload.require`.
- `config()`: registers `numbat` with `xvm.add("numbat", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `numbat` via `xvm.remove("numbat")`.
- System impact: none; only writes inside the package install directory and xvm shim registration.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME`: `xlings config --add-xpkg pkgs/n/numbat.lua`, `xlings search numbat`, `xlings install numbat@1.24.0 -y`, `numbat --version`, `numbat -e "3m + 50cm to cm"`, `numbat -e "use extra::astronomy; earth_mass to kg"`, `numbat /? </dev/null`, `dep-closure-check.sh`, `xlings remove numbat -y`, `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only numbat`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, and `windows/x86_64` runtime installs (no local hosts for those targets; covered by static SHA256/layout/PE/ELF inspection and GitHub Actions CI where runners exist).

## Revision log

- 2026-11-26 — added at `1.24.0`: official musl static binaries on Linux (`x86_64`, `aarch64`), Mach-O binaries on macOS (`x86_64`, `aarch64`), and Windows `x86_64` with app-local `xim:vcruntime` DLLs; preserves `modules/` and full archive layout.
