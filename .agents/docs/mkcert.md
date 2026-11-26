# mkcert

A simple zero-config tool to make locally trusted development certificates with any names you would like (`mkcert`). Status: `stable`.

- Upstream: https://github.com/FiloSottile/mkcert (BSD-3-Clause)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes a 32-bit `linux-arm` binary, omitted because `archs` covers 64-bit `x86_64` and `aarch64`.

## Source

- Tier: upstream release (`FiloSottile/mkcert`)
- GLOBAL: `https://github.com/FiloSottile/mkcert/releases/download/v${version}/mkcert-v${version}-<os>-${arch_alias}[.exe]`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: computed locally from all 6 downloaded `v1.4.4` release binaries.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`)

## Linking

- `linux/x86_64`, `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d` reports no dynamic section; `ldd` reports not a dynamic executable). Declares no runtime dependencies.
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64`, `windows/aarch64`: PE32+ console executables (`x86-64`, `ARM64`) importing only `kernel32.dll`. No `xim:vcruntime` dependency needed.

## What the hooks do

- install: moves the downloaded raw binary (`pkginfo.install_file()`) to `<install_dir>/mkcert` (`mkcert.exe` on Windows), sets `+x` on Unix, and verifies the target file exists.
- config: registers `mkcert` via `xvm.add("mkcert", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `mkcert` via `xvm.remove("mkcert")`.
- System impact: none during package install/config/uninstall (does not run `mkcert -install` against any host trust store).

## Verification

- Static / isolation / repo-wide checks: `pytest tests/m/test_mkcert.py -m "static or isolation"`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect/materialize`.
- Isolated `XLINGS_HOME` / `HOME` (`linux/x86_64`): `xlings config --add-xpkg`, `xlings search`, `xlings install local:mkcert@1.4.4 -y`, `mkcert --version`, `mkcert -CAROOT` + certificate generation inside an isolated temp `CAROOT`, `pytest -m "index or verify"`, `xlings remove`, and clean state verification.
- Not run locally: `linux/aarch64`, `macosx`, and `windows` runtime installs (covered by CI; binary SHA256s, ELF dynamic sections, and PE imports verified locally for all 6 assets).

## Revision log

- 2026-11-26 — added at `1.4.4`: initial spec-2 recipe covering all 6 64-bit upstream raw-binary targets (`linux`, `macosx`, `windows` x `x86_64`/`aarch64`).
