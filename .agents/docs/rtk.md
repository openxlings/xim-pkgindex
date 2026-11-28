# rtk

RTK's Apache-2.0-only OSS command filters, providing `rtk`.
The engine and proxy distributions are deliberately not selected.

- Upstream: https://github.com/rtk-ai/rtk (Apache-2.0)
- Namespace: `xim`; unmodified official release binaries
- Platforms: Linux and macOS x86_64/aarch64; Windows x86_64 only.
  This upstream OSS release publishes no Windows ARM64 asset.

## Source

- Tier: official repository release, v1.2.1.
- GLOBAL: RTK release assets named `rtk-oss-<target>`.
- CN: none verified; `ci.mirror = true` requests maintainer mirroring after merge.
- All five downloads matched upstream `checksums.txt` and GitHub release digests.
- Manual version updates: the Apache-only release flavor is reviewed explicitly.

## Linking

Both Linux musl binaries have no DT_NEEDED entries. The x86_64 binary is
static PIE; a dynamic table alone is not evidence of a dynamic dependency.
Windows PE imports VCRUNTIME140.dll: `xim:vcruntime` is a runtime dependency,
and its complete runtime set is copied beside rtk.exe. Other imports are Windows
system DLLs/API sets. macOS uses the corresponding official Mach-O build.
Wrapper subcommands invoke the user's separately selected developer tools;
the built-in JSON filter requires none of those tools.

## Hooks and impact

- install: place only the flat tarball's executable and LICENSE; Windows uses
  the shared ZIP extractor, then places the declared app-local CRT.
- installed: require the executable and license; Windows runtime files come from
  the declared provider rather than a hard-coded DLL list.
- config: register only `rtk` with xvm.
- uninstall: remove its xvm registration; xlings owns payload removal.
- No shell/profile/PATH changes, hooks, daemon or telemetry opt-in.
  The package never runs `rtk init` or the upstream installer.

## Verification

- Upstream Linux x86_64 `--version` and offline `json --keys-only` ran.
- Both Linux ELF payloads and Windows imports were inspected.
- tests/r/test_rtk.py covers registration, install/reinstall, a real JSON
  filter, removal, complete native payload files and routing.
- macOS, Windows and ARM64 executables were not run on the local Linux
  x86_64 host; their downloaded resources and layouts were inspected.

## Revision log

- 2026-11-28 — added 1.2.1, explicitly selecting the Apache-2.0 OSS flavor.
