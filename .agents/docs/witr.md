# witr

Witr explains why a process is running by tracing its ancestry. This stable
package provides `witr` without installing shell integration.

- Upstream: https://github.com/pranshuparmar/witr (Apache-2.0).
- Namespace: `xim`; version `0.3.4`.
- Popularity: 23,486 GitHub stars observed on 2026-11-28.
- Platforms: Linux, macOS and Windows, each x86_64 and aarch64.

## Source

- Tier: official upstream GitHub release `v0.3.4`.
- GLOBAL: `https://github.com/pranshuparmar/witr/releases/download/v${version}/witr-<linux|darwin|windows>-<amd64|arm64>`; Windows adds `.zip`.
- CN: none verified; `ci = { mirror = true }` requests post-merge mirroring.
- Checksums: all six downloaded assets agree with upstream `SHA256SUMS`
  and the GitHub release SHA-256 digests. The checksum document itself hashes
  to `ca4581174d49fceab59a1596a049d6a0e9e770b7e497d0289ae2f73ebcd407b6`.
- Auto-update: manual. No updater extension is declared because the pinned
  updater inspect/check flow has not been exercised for this package.

## Linking and layout

- Both Linux assets are static ELF executables; `readelf -d` reports no dynamic
  section. There are no third-party runtime dependencies.
- Both macOS Mach-O assets load only OS-provided `/usr/lib/libSystem.B.dylib`
  and `/usr/lib/libresolv.9.dylib`.
- Both Windows PE import tables name only `kernel32.dll`; no MSVC runtime is
  required. Each flat ZIP contains exactly `LICENSE`, `README.md`, `witr.exe`.
- POSIX resources are bare binaries, not archives.

## Hooks and system impact

- Install: move the POSIX binary to the package root and grant executable
  permission. On Windows, `xim.pkgindex.payload.unpack()` extracts the flat
  ZIP directly into the package root, preserving its three files and avoiding
  unrelated files in the framework's shared extraction directory.
- Both branches require the actual executable; `installed()` checks the same
  file. Configuration registers `witr` with xvm; uninstall removes that route.
- No shell profiles, user PATH, host package manager or system directories are
  changed. There is no shell integration or privileged setup.

## Verification

- `pytest tests/w/test_witr.py -v` covers metadata, all six resource resolutions,
  isolation, registration/search, install/list,
  idempotent install, version, executable permission, owned-PID short JSON,
  final uninstall, repeated removal and overlay unregistration.
- Runtime tests create their own disposable home and copy the native xlings
  executable there so shims never depend on or modify the developer's home.
  Shared helpers are copied into that home's primary index from the checkout.
  Optional `XLINGS_TEST_ARCHIVES` names an explicit directory of official Witr
  assets: the fixture reads only the exact host asset, verifies its pinned
  SHA-256, and copies it to the disposable runtime cache. It never discovers
  user caches or registers that directory as an archive source. A fresh native
  download timed out after 180 seconds locally; acceptance uses these verified
  bytes, not a changed URL or relaxed checksum.
- The offline feature test starts a sanitized Python child, queries only its
  PID using `--short --json`, and checks its PID/name without logging raw JSON.
  Pinned upstream code serializes only PID/name and optional parent markers in
  this mode, with no outbound reporting. Witr intrinsically reads related
  ancestry context internally; no environment values are inspected by the test.
- Local execution target: Linux x86_64 with xlings `2026.11.23.1`, matching CI.
  Exact run results belong in the pull request. Linux aarch64, macOS and Windows
  payloads were inspected but cannot be executed on the available host.

## Revision log

- 2026-11-28 — added `0.3.4` using six official portable binaries.
