# k9s

K9s is a terminal-based Kubernetes CLI for managing clusters. Provides the `k9s` command (`status = "stable"`).

- Upstream: https://github.com/derailed/k9s (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`)

## Source

- Tier: upstream GitHub release (`derailed/k9s`)
- GLOBAL: `https://github.com/derailed/k9s/releases/download/v${version}/k9s_<OS>_<arch>.<tar.gz|zip>`
- CN: none yet (declares `ci = { mirror = true }`)
- Checksums: verified against upstream `checksums.sha256` and computed SHA-256 of all six downloaded v0.51.0 release archives
- Auto-update: yes (`extensions.autoupdate`, `GLOBAL` required across all 6 platform/arch targets)

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables (`readelf -d` shows no `.dynamic` section, zero `DT_NEEDED` dependencies). No `xim:glibc` or runtime dependency required.
- Windows (`x86_64`, `aarch64`): static Go PE executables importing `kernel32.dll` only (no `vcruntime` dependency).

## What the hooks do

- install: upstream archives are flat (`k9s`/`k9s.exe`, `LICENSE`, `README.md` at archive root); extracts directly into `pkginfo.install_dir()` (`payload.unpack{}` via `System32\tar.exe` on Windows, `tar -xzf` + `chmod +x` on POSIX) and asserts `payload.require({ exe })`
- config: registers `k9s` with `xvm.add("k9s", { bindir = pkginfo.install_dir() })`
- uninstall: removes `k9s` via `xvm.remove("k9s")`
- System impact: none

## Verification

- Verified `linux/x86_64` locally in an isolated `XLINGS_HOME` (`xlings install`, `k9s version`, `tests/k/test_k9s.py`, `xlings remove`).
- `linux/aarch64`, `macosx/*`, and `windows/*` were not executed locally (verified via upstream `checksums.sha256`, archive layout inspection, `readelf -d` on `linux/aarch64`, and PE import table inspection on `windows/*`).

## Revision log

- 2026-11-25 — added at `0.51.0`.
