# brook

Brook is a stable programmable network CLI. This package provides `brook`, not
Brook's GUI, Android application, OpenWrt build, or the separate `ipio` command.

- Upstream: https://github.com/txthinking/brook (GPL-3.0-only)
- Namespace: `xim` (unmodified official upstream binaries)
- Platforms: Linux, macOS and Windows, each x86_64/aarch64.
- Selection snapshot: 15,204 GitHub stars; latest API release `v20270101`,
  published **2026-09-14T04:56:56Z**. The numeric tag is not a publication date.

## Source

- Tier: official repository release, https://github.com/txthinking/brook/releases/tag/v20270101
- GLOBAL: `https://github.com/txthinking/brook/releases/download/v${version}/brook_<linux|darwin>_<amd64|arm64>`;
  Windows uses `brook_windows_<amd64|arm64>.exe`.
- CN: none verified. `ci.mirror = true` requests the normal post-merge mirror;
  no speculative mirror URL is declared.
- All six raw downloads matched their release-asset API `sha256:` digests.
  They are not archives: install must rename the downloaded file explicitly.
- Automatic updates: GLOBAL-only, all six targets required. The pinned updater
  accepts a single-component numeric version and strips the `v` prefix, so the
  templates use `${tag}` without a custom version parser.

## Linking

- Both Linux payloads: static Go ELF, no dynamic section or ELF interpreter;
  no glibc or compiler-runtime dependency.
- Both Windows PE payloads import only the OS `kernel32.dll`; no VC runtime DLL.
- Both macOS Mach-O payloads reference the OS `libSystem.B.dylib`,
  `libresolv.9.dylib`, CoreFoundation and Security frameworks only.
- No third-party runtime libraries or install-time build tools are needed.

## What the hooks do

- `installed`: checks the actual root-level `brook`/`brook.exe` payload.
- `install`: moves the raw binary to that name, applies executable permissions
  on POSIX, and checks that the executable exists.
- `config`/`uninstall`: add/remove only the `brook` xvm registration.
- System impact: no shell profiles, environment changes, privileged networking,
  system proxy changes, background services or auto-start configuration.

## Verification

- Asset acceptance: download all six URLs, SHA256 against GitHub asset digests,
  `file`, Linux `readelf -d/-l`, PE import tables, Mach-O load commands.
- Package acceptance: `pytest tests/b/test_brook.py` under a throwaway
  `HOME`/`XLINGS_HOME` bootstrapped with the current xlings executable and index.
  It covers static/isolation/index/install, the xvm-routed executable, and clean
  removal. `XLINGS_TEST_VERSION` can select a version without freezing updates.
- Meaningful offline test: `brook link` serializes a Brook server, WSS server and
  SOCKS5 server with escaped password/name values; Python independently parses
  the resulting URLs and checks every value. No listeners or external network.
- Direct acceptance also checks search/list, repeat install/remove and overlay
  cleanup. Resource acceptance uses the pinned updater inspect/check and mirror
  materialize/verify; the PR records actual command results.
- Native local execution is Linux x86_64 only. The remaining five binaries are
  resource/layout/linkage-verified, not claimed as locally executed. CI provides
  native Linux ARM64, macOS ARM64 and Windows x86_64 coverage; macOS Intel and
  Windows ARM64 remain resource-only in the standard runner matrix.

## Revision log

- 2026-11-28 — added official CLI release 20270101 with all six upstream assets.
