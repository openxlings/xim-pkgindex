# gron

Stable CLI that converts JSON into greppable assignments and reconstructs JSON with `--ungron`.

- Upstream: [tomnomnom/gron](https://github.com/tomnomnom/gron) (MIT).
- Namespace: `xim`; official upstream binaries, not a repack or custom build.
- Platforms: Linux, macOS and Windows, each on x86_64 and aarch64.
- Excluded: upstream 386 and FreeBSD targets are outside this package's supported matrix.

## Source

- Tier: upstream release, [v0.7.1](https://github.com/tomnomnom/gron/releases/tag/v0.7.1).
- GLOBAL: `https://github.com/tomnomnom/gron/releases/download/v${version}/gron-linux-${arch_alias}-${version}.tgz`.
- macOS uses `gron-darwin-${arch_alias}-${version}.tgz`; Windows uses `gron-windows-${arch_alias}-${version}.zip` at the same release base.
- Architecture aliases: x86_64 → `amd64`, aarch64 → `arm64`.
- CN: none verified; `ci = { mirror = true }` requests maintainer-managed mirroring.
- Checksums: all six official assets were downloaded, SHA256-calculated and matched to the [recipe](../../pkgs/g/gron.lua); six checks passed. Upstream supplies no checksum asset or GitHub digest for this release; no independent upstream checksum comparison is claimed.
- Auto-update: yes, required GLOBAL-only `extensions.autoupdate`; pinned-updater inspect/check passed, latest remains 0.7.1.

## Linking

Linux x86_64 needs `libpthread.so.0` and `libc.so.6` (maximum GLIBC_2.3.2 symbol requirement).
Linux declares managed `xim:glibc@>=2.44.3`, whose loader finds its libraries beside itself.
Interpreter-only `elfpatch.set_interpreter` plus `elfpatch.skip` follows the existing Bun integration:
adding RPATH moved this Go binary's writable `.dynamic` into an RX LOAD and broke startup.
No custom ELF-header edits or host-runtime fallback are used.
Linux aarch64 is static and skips automatic ELF patching; it harmlessly shares the platform dependency.
macOS binaries use Apple system libraries/frameworks; Windows PE32+ binaries import only `kernel32.dll`, not the VC runtime.

## What the hooks do

- install: place the flat `gron`/`gron.exe`, restore POSIX execute permission, seal the Linux interpreter as above, and install the exact MIT notice from upstream v0.7.1 because archives omit it. Shared `payload` handles Windows ZIP fallback and required-file checks.
- config: register only `gron` with xvm.
- uninstall: remove the gron registration; package removal deletes its payload.
- System impact: package-store/runtime dependency and subos routing only; no system configuration, shell profile, PATH or environment mutation, and no host package manager.

## Verification

- Fresh temporary HOME, XLINGS_HOME and XDG directories; both `XLINGS_SUBOS_LIB` and `XLINGS_SUBOS_LIBS` pointed into that temporary home. Index helper modules were copied before installation.
- `python3 -m pytest -q tests/g/test_gron.py`: **17 passed in 5.01s**, including real registration, installation, offline native behavior and removal on Linux x86_64.
- Direct search/install/version, nested JSON → deterministic assignments → semantic ungron round-trip, field filtering → ungron, license comparison and removal passed.
- Managed-loader `--inhibit-cache --list`, with `LD_LIBRARY_PATH` removed, resolved the interpreter, libc and libpthread entirely within `$XLINGS_HOME`.
- Official v0.7.1 reports `gron version dev`; the test preserves and documents that upstream string.
- Other targets received archive, hash, format and linkage inspection, not local native execution; those hosts were unavailable.
- CI is not claimed all-green: mirror precheck can remain blocked pending maintainer `.tgz` tooling support; contributor tooling changes are outside this package.

## Revision log

- 2026-11-27 — added at 0.7.1 with six verified resources, preserved MIT notice and managed interpreter-only Linux runtime integration.
