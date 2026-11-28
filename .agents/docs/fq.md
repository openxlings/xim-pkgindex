# fq

`fq` is a stable jq-style query language and decoder for binary formats; its executable is `fq`.

- Upstream: https://github.com/wader/fq (MIT; verified at v0.18.0)
- Namespace: `xim`
- Platforms: Linux, macOS, and Windows on x86_64 and aarch64; no other architectures are declared.

## Source

- Tier: upstream GitHub release v0.18.0.
- GLOBAL: Linux `https://github.com/wader/fq/releases/download/v${version}/fq_${version}_linux_${arch_alias}.tar.gz`; macOS `https://github.com/wader/fq/releases/download/v${version}/fq_${version}_macos_${arch_alias}.zip`; Windows `https://github.com/wader/fq/releases/download/v${version}/fq_${version}_windows_${arch_alias}.zip`.
- CN: none declared; the updater requires all six GLOBAL platform/architecture targets.
- Checksums: each archive matched both its GitHub release asset SHA256 digest and upstream `checksums.txt` at v0.18.0. The checksum file matched GitHub digest `e5f9b0b37fa2c53e7a011fa928da232aaa319bef2fbaf6d211c1e55317c672a8`.
- Auto-update: yes, required GLOBAL-only release templates.

## Linking

No package dependencies are declared. The inspected Linux artifacts are static ELF binaries without an interpreter or dynamic section.

## What the hooks do

- install: extracts the flat upstream `fq`/`fq.exe` archive payload into the package directory, requires the executable, and sets POSIX execute permission. Windows ZIP extraction uses the shared payload helper; macOS ZIPs use `unzip`.
- config: registers `fq` with xvm, bound to the package install directory.
- uninstall: removes the xvm registration; xlings removes the versioned package payload.
- System impact: no shell profile, system configuration, or user environment is changed.

## Verification

- `python3 -m pytest tests/f/test_fq.py -q`: 10 passed in 0.37s, including static/isolation, index/install, version, PNG decode, and JSON transform checks.
- Native Linux x86_64 tests used a fresh isolated HOME, XDG directories, and `XLINGS_HOME`; cached official archives and the real worktree library modules were used. Direct removal checks confirmed the package payload, shim, and xvm workspace entry were removed.
- Final CI is green, including the native Windows runner after the test driver was changed to invoke xlings directly with argv rather than through a login shell.

## Revision log

- 2026-11-27 — added with fq 0.18.0; six upstream assets and their platform formats/checksums were verified.
