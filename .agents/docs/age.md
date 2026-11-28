# age

Simple, modern and secure file encryption tool providing `age`, `age-keygen`, `age-inspect`, and compatibility plugins (`age-plugin-batchpass`, `age-plugin-pq`, `age-plugin-tag`, `age-plugin-tagpq`). Status: `stable`.

- Upstream: https://github.com/FiloSottile/age (`BSD-3-Clause`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`) — covers all desktop/server architectures published by upstream `v1.3.2` (upstream also publishes `linux/arm` and `freebsd/amd64`, which xlings does not target).

## Source

- Tier: upstream release (`https://github.com/FiloSottile/age/releases`)
- GLOBAL: `https://github.com/FiloSottile/age/releases/download/v${version}/age-v${version}-${os_alias}-${arch_alias}.${ext}` (`.tar.gz` for `linux`/`darwin`, `.zip` for `windows`)
- CN: none yet (`ci = { mirror = true }`, a maintainer mirror job handles `xlings-res`)
- Checksums: verified SHA256 against GitHub release asset digests and locally downloaded bytes of all 6 archives (exact match).
- Auto-update: yes (`extensions.autoupdate`, GLOBAL required across all 6 platform/arch targets).

## Linking

- Linux (`x86_64` and `aarch64`): all seven ELF binaries are statically linked Go executables with no dynamic section and no external libc dependency (`readelf -d`, `ldd`). Declares no `deps`.
- Windows (`x86_64` and `aarch64`): all seven PE32+ executables import only `kernel32.dll` (no `VCRUNTIME140.dll` or MSVC runtime dependency).
- macOS (`x86_64` and `aarch64`): Mach-O 64-bit executables (`x86_64` and `arm64`).

## What the hooks do

- install: unpacks the single top-level `age/` directory into `pkginfo.install_dir()` via `payload.unpack{ extracted = "age", strip = 1 }` and verifies all seven executables plus `LICENSE` with `payload.require(...)`.
- config: registers `age` with `xvm.add("age", { bindir = pkginfo.install_dir() })` and binds all six sibling executables (`age-keygen`, `age-inspect`, `age-plugin-batchpass`, `age-plugin-pq`, `age-plugin-tag`, `age-plugin-tagpq`) to `"age@" .. pkginfo.version()`.
- uninstall: removes all six sibling xvm registrations in reverse order and then removes `age`.
- System impact: none; isolated under `pkginfo.install_dir()` and xvm shims.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME`: `pytest tests/a/test_age.py`, core static checks, lints, `tools/xpkg_ci.py inspect/materialize`, `xlings install local:age -y`, `age-keygen` / `age` / `age-inspect` round-trip, and `xlings remove age -y`.
- `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), and `windows` (`x86_64`/`aarch64`) runtime installs were not run locally (relying on GitHub Actions CI for `linux/aarch64`, `macosx/aarch64`, `windows/x86_64`, and archive/ELF/PE inspection for `macosx/x86_64` and `windows/aarch64`).

## Revision log

- 2026-11-26 — added at `1.3.2`: initial spec-2 recipe covering `linux`, `macosx`, and `windows` (`x86_64`/`aarch64`), all 7 shipped binaries, `ci = { mirror = true }`, and `extensions.autoupdate`.
