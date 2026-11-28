# nats

Command-line interface (`nats`) for NATS.io messaging and JetStream; status `stable`.

- Upstream: https://github.com/nats-io/natscli (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream `.deb`/`.rpm` and non-desktop targets (`386`, `arm6`, `arm7`, `s390x`, `freebsd`) are not included.

## Source

- Tier: upstream release (`nats-io/natscli` GitHub Releases, `v0.5.2`)
- GLOBAL:
  - linux: `https://github.com/nats-io/natscli/releases/download/v${version}/nats-${version}-linux-${arch_alias}.zip`
  - macosx: `https://github.com/nats-io/natscli/releases/download/v${version}/nats-${version}-darwin-${arch_alias}.zip`
  - windows: `https://github.com/nats-io/natscli/releases/download/v${version}/nats-${version}-windows-${arch_alias}.zip`
- CN: none yet (maintainer mirror via `ci = { mirror = true }`)
- Checksums: upstream `SHA256SUMS` asset; all six `.zip` archives were downloaded and verified byte-for-byte with `sha256sum`.
- Auto-update: yes (`extensions.autoupdate`, using `${tag}` and `${version}`).

## Linking

- Linux `x86_64` & `aarch64`: statically linked Go ELF64 executables (`readelf -d` shows no `.dynamic` section; `ldd` reports not a dynamic executable). Zero runtime dependencies declared.
- Windows `x86_64` (`0x8664`) & `aarch64` (`0xaa64`): PE32+ console executables importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`, so no `xim:vcruntime` dependency).

## What the hooks do

- install: Unpacks the single top-level directory (`nats-<ver>-<os>-<arch>/`) into `pkginfo.install_dir()` (Windows via `payload.unpack` / `System32\tar.exe`, POSIX via `payload.unpack` when pre-extracted or `unzip -q -o` with `tar` fallback, plus `chmod +x` on `nats`) and requires `nats`/`nats.exe` and `LICENSE`.
- config: Registers `nats` with `xvm.add("nats", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `nats` via `xvm.remove("nats")`.
- System impact: none; self-contained inside `pkginfo.install_dir()` and the subos xvm shim.

## Verification

- Verified `nats` `v0.5.2` checksums and binary linking on all six archives (`linux`, `macosx`, `windows` x `x86_64`, `aarch64`).
- Ran `pytest tests/n/test_nats.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repository-wide static checks, `lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect`/`materialize`, and isolated `XLINGS_HOME` install/run/remove on `linux/x86_64`.
- `macosx` and `windows` runtime install/execution were not run locally (checked statically and covered by CI runners).

## Revision log

- 2026-11-26 — added at `0.5.2`: all-`.zip` release layout across Linux, macOS (`darwin`), and Windows (`amd64`/`arm64`).
