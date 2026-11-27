# revive

Revive is a stable, configurable Go linter; it provides the `revive` command.

- Upstream: https://github.com/revive-lint/revive (MIT)
- Namespace: `xim`
- Platforms: Linux, macOS, and Windows on x86_64 and aarch64; no other architectures are declared.

## Source

- Tier: canonical upstream GitHub release v1.17.1.
- GLOBAL: Linux `https://github.com/revive-lint/revive/releases/download/v${version}/revive_linux_${arch_alias}.tar.gz`; macOS `https://github.com/revive-lint/revive/releases/download/v${version}/revive_darwin_${arch_alias}.tar.gz`; Windows `https://github.com/revive-lint/revive/releases/download/v${version}/revive_windows_${arch_alias}.tar.gz`.
- CN: none declared; the updater requires all six GLOBAL platform/architecture targets.
- Checksums: all six archives matched the GitHub release asset digests and upstream `checksums.txt` at v1.17.1.
- Auto-update: yes, required GLOBAL-only release templates.

## Linking

No package dependencies are declared. The inspected Linux artifacts are static ELF binaries without an interpreter or dynamic section. File-only linting does not need a Go SDK; package-pattern/type analysis may use a separately installed Go toolchain.

## What the hooks do

- install: extracts the flat `.tar.gz` payload (`revive`/`revive.exe`, `LICENSE`, `README.md`) into the package directory and requires all files. Windows extraction explicitly uses native `System32\tar.exe`; POSIX installs set execute permission.
- config: registers `revive` with xvm, bound to the package install directory.
- uninstall: removes the xvm registration; xlings removes the versioned package payload.
- System impact: no shell profile, Go configuration, system configuration, or user environment is changed.

## Verification

- `python3 -m pytest tests/r/test_revive.py -q`: 19 passed in 0.30s, including static/isolation, index/install, version, and installed-shim lint behavior.
- Native Linux x86_64 tests used a fresh isolated HOME, XDG directories, and `XLINGS_HOME`; cached official archives and the real worktree library modules were used. Explicit-file lint assertions run without Go, and direct removal checks confirmed the payload, shim, and xvm workspace entry were removed.
- Final CI is green, including the native Windows runner after the test driver was changed to invoke xlings directly with argv rather than through a login shell.

## Revision log

- 2026-11-27 — added with revive 1.17.1; six upstream assets and their platform formats/checksums were verified.
