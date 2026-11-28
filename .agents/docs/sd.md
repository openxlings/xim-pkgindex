# sd

Intuitive find & replace CLI (`sd`), status `stable`.

- Upstream: https://github.com/chmln/sd (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is not covered because upstream v1.1.0 publishes no Windows ARM64 asset and `xim:vcruntime` is `x86_64`-only.

## Source

- Tier: upstream official repository release (`chmln/sd` tag `v1.1.0`)
- GLOBAL:
  - `linux`: `https://github.com/chmln/sd/releases/download/v${version}/sd-v${version}-${arch_alias}.tar.gz` (`x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl`)
  - `macosx`: `https://github.com/chmln/sd/releases/download/v${version}/sd-v${version}-${arch}-apple-darwin.tar.gz`
  - `windows`: `https://github.com/chmln/sd/releases/download/v${version}/sd-v${version}-${arch}-pc-windows-msvc.zip`
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge)
- Checksums: GitHub release asset SHA256 digests matched local `sha256sum` on all five downloaded archives.
- Auto-update: yes (`extensions.autoupdate` tracking `https://github.com/chmln/sd/releases`)

## Linking

- `linux/x86_64`: static-pie musl ELF (`readelf -d`: no `PT_INTERP`, no `DT_NEEDED`; `ldd`: `statically linked`) — zero runtime dependencies.
- `linux/aarch64`: static musl ELF (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable) — zero runtime dependencies.
- `windows/x86_64`: PE32+ x86-64 importing `VCRUNTIME140.dll`, `api-ms-win-crt-*.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `bcryptprimitives.dll`, `kernel32.dll`, `ntdll.dll`. Declares `xim:vcruntime` as a runtime dep and copies CRT DLLs app-local beside `sd.exe`.

## What the hooks do

- install: unpacks the `sd-v<ver>-<target>/` wrapper directory with `payload.unpack{ extracted = stem, strip = 1 }`, copies `xim:vcruntime` DLLs into `install_dir` on Windows, and checks `sd` / `sd.exe` via `payload.require`.
- config: registers `sd` with `xvm.add("sd", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `sd` via `xvm.remove("sd")`.
- System impact: none; only writes inside the package install directory and xvm shim registration.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME`: `xlings install local:sd -y`, `sd --version` (note: upstream v1.1.0 binary prints `sd 1.0.0`), stdin find/replace (`sd "world" "xlings"`), `dep-closure-check.sh`, `xlings remove sd -y`, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`), plus `tools/xpkg_ci.py inspect/materialize`, `lint_exec_quoting.sh`, and `.github/scripts/check-*.sh`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, and `windows/x86_64` runtime installs (no local hosts for those targets; covered by static SHA256/layout/PE/ELF inspection and GitHub Actions CI where runners exist).

## Revision log

- 2026-11-26 — added at `1.1.0`: upstream v1.1.0 release binary reports `sd 1.0.0` on `--version`; both Linux architectures use official musl static binaries, and Windows `x86_64` copies `xim:vcruntime` DLLs app-local.
