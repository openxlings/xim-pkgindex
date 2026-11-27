# jless

Stable terminal JSON/YAML viewer with structural navigation and regex search.
Provides the `jless` command from official prebuilt release archives.

- Upstream: https://github.com/PaulJuliusMartinez/jless (MIT)
- Namespace: `xim`
- Platforms: Linux x86_64; macOS x86_64 and aarch64.
- Not covered: Linux aarch64 and Windows; upstream v0.9.0 publishes no binaries for them.

## Source

- Tier: upstream release, v0.9.0 (published 2023-07-17).
- Release: https://github.com/PaulJuliusMartinez/jless/releases/tag/v0.9.0
- GLOBAL Linux x86_64: `https://github.com/PaulJuliusMartinez/jless/releases/download/${tag}/jless-${tag}-x86_64-unknown-linux-gnu.zip`
- GLOBAL macOS x86_64: `https://github.com/PaulJuliusMartinez/jless/releases/download/${tag}/jless-${tag}-x86_64-apple-darwin.zip`
- GLOBAL macOS aarch64: `https://github.com/PaulJuliusMartinez/jless/releases/download/${tag}/jless-${tag}-aarch64-apple-darwin.zip`
- CN: none yet (a maintainer will add it).
- Auto-update: yes, `extensions.autoupdate`; all three GLOBAL targets are required.
- Checksums: computed from the actual official ZIP downloads:
  - Linux x86_64: `a1e0eb63ef347adc649989ac5c7d2dc896df6d494622b953c86e3a248e733a93`.
  - macOS x86_64: `8228d44b918af7e904a75df10f85dabf29cdedac17156d870c80968e6836b04f`.
  - macOS aarch64: `1967568762e44d3a5a7b09211c55ff9680419878a5a7045876d2cc6870e40390`.
- Independent xlings downloads revalidated Linux x86_64 and macOS aarch64 hashes during install/CI.
- This older upstream release has no checksum sidecars; GitHub asset digests are null.
- macOS x86_64 was downloaded, hashed and inspected, but not independently executed.

## Linking

Linux uses dynamic glibc ELF binaries (highest required symbol version: GLIBC_2.34).
Measured DT_NEEDED: `libxcb.so.1`, `libxcb-render.so.0`, `libxcb-shape.so.0`,
`libxcb-xfixes.so.0`, `libgcc_s.so.1`, `libc.so.6`, `ld-linux-x86-64.so.2`.
Declare `xim:libxcb@>=1.17.0`, `xim:gcc-runtime@>=15.1.0`, `xim:glibc@>=2.34`.
Seal `bin/` with the existing selfcontain helper; refuse unavailable sealing support.
The installed loader resolved the complete closure inside the isolated `$XLINGS_HOME`.
Both macOS binaries link only system AppKit/Foundation, libSystem, libobjc and libiconv.

## What the hooks do

- install: move the framework-extracted singleton executable into package `bin/`, assert it with payload helpers, chmod and seal Linux runtime paths.
- config: register `jless` through xvm with the package's `bin/` directory.
- uninstall: remove the xvm command registration; xlings removes the package payload.
- System impact: only xlings-managed state; no system configuration, shell-profile, PATH-variable or application-config edits.
- Archives contain only the executable: no bundled libraries, CA data or license files are discarded.

## Verification

- Isolated Linux x86_64: register/search/install, `xlings use jless local:0.9.0`, `jless --version`, JSON pretty-print/parse-failure, remove; payload/shim/workspace cleanup passed.
- Real PTY: first-row rendering, `G` navigation, successful/missing regex searches and `q` exit; repaired shutdown replay passed in 0.007s using the installed native binary.
- Shim version/JSON tests remain separate; PTY drains output and closes the terminal before bounded process-group cleanup.
- Loader listing and host-library-free bubblewrap execution confirmed the declared Linux closure.
- Focused package tests: `python3 -m pytest tests/j/test_jless.py -q -rA`, followed by affected-check reruns for corrected harness assumptions.
- Final required CI, including Linux x86_64 and macOS aarch64 native checks, is green: https://github.com/openxlings/xim-pkgindex/pull/1514/checks
- Native macOS x86_64 was not run; its runtime compatibility remains dependent on upstream's prebuilt binary.
- Workflow-pinned updater `c60835a1f00f902dd02f85739d5be9680cd52754` inspect/check reported 0.9.0 up-to-date.

## Revision log

- 2026-11-27 — added at 0.9.0: upstream singleton ZIPs, sealed Linux dependencies, three-target autoupdate and native PTY coverage.
