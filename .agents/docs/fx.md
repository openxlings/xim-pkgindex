# fx

Terminal JSON viewer & processor (`fx`), `status = "stable"`.

- Upstream: https://fx.wtf / https://github.com/antonmedv/fx (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Covers all 6 upstream release assets for `40.0.2`.

## Source

- Tier: upstream GitHub release (`antonmedv/fx`)
- GLOBAL: `https://github.com/antonmedv/fx/releases/download/${version}/fx_<os>_${arch_alias}[.exe]` (note: upstream tags use bare `40.0.2` without a `v` prefix)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from GitHub release asset digests for `40.0.2` and verified locally via `sha256sum` against all 6 downloaded binaries.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- `linux/x86_64`, `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d` reports no dynamic section; `ldd` reports not a dynamic executable). Zero runtime dependencies declared.
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64`, `windows/aarch64`: PE32+ console executables (`x86-64`, `ARM64`) importing only `kernel32.dll`. Zero runtime dependencies declared.

## What the hooks do

- install: moves the downloaded raw binary (`pkginfo.install_file()`) to `<install_dir>/fx` (`fx.exe` on Windows), sets `+x` on Unix, and verifies the target file exists.
- config: registers `fx` via `xvm.add("fx", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `fx` via `xvm.remove("fx")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation checks: `pytest tests/f/test_fx.py -m "static or isolation"`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect/materialize`.
- Isolated `XLINGS_HOME` & `HOME` (`linux/x86_64`): `xlings config --add-xpkg pkgs/f/fx.lua`, `xlings install local:fx -y`, `fx --version`, `echo '{"a":1}' | fx .a`, `pytest tests/f/test_fx.py -m "index or lifecycle or verify"`, and `xlings remove local:fx -y`.
- Not run locally: `linux/aarch64`, `macosx`, and `windows` runtime installs (covered by CI; binary SHA256s, ELF dynamic sections, and PE imports verified locally for all 6 assets).

## Revision log

- 2026-11-26 — added at `40.0.2`: initial `spec = "2"` recipe covering all 6 upstream raw-binary targets (`linux`, `macosx`, `windows` x `x86_64`/`aarch64`).
