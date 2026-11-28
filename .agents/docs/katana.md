# katana

Stable web crawler providing `katana`; standard non-headless crawling is the
packaged baseline. Upstream had 17,907 GitHub stars on 2026-11-28.

- Upstream: https://github.com/projectdiscovery/katana (MIT)
- Namespace: `xim`
- Version: 1.8.0; Linux, macOS and Windows on x86_64 and aarch64.

## Source

- Tier: official upstream GitHub release, tag `v1.8.0`.
- GLOBAL: `https://github.com/projectdiscovery/katana/releases/download/v${version}/katana_${version}_<platform>_<arch>.zip`;
  platforms are `linux`, `macOS`, `windows`, arches `amd64`, `arm64`.
- CN: none; `ci = { mirror = true }` requests the maintainer-managed mirror.
- All six downloaded ZIP SHA-256 values agree with upstream
  `katana-1.8.0-checksums.txt` and GitHub release asset digests. The checksum
  document itself matches digest
  `e937745b6dd4bd9c657b2f27399c1479e72b5ba3ca384a24ef4ed34e1d666a33`.
- Updates are manual: no autoupdate declaration without running the pinned
  updater's inspect/check workflow.

## Linking

Both Linux ELF files are statically linked, with no interpreter or dynamic
section. Both Windows PE files import only `kernel32.dll`; no MSVC runtime is
needed. Both macOS Mach-O files load only native system libraries/frameworks:
libSystem, libresolv, CoreFoundation and Security. No ecosystem runtime
dependencies are needed for standard crawling. Upstream builds with CGO disabled.

## What the hooks do

- Every ZIP is flat: `katana` (`katana.exe` on Windows), `LICENSE.md`, `README.md`.
- POSIX: move precisely those three framework-extracted files into a clean
  payload, not the shared extraction directory. Windows: use the shared
  `payload.unpack{}` native ZIP helper. `payload.require` and `installed()`
  check the same complete manifest.
- Config registers only the `katana` xvm route; uninstall removes that route.
- No browser installation, daemon, shell profile, PATH or user-config changes.

## Optional upstream features

Headless/hybrid crawling is explicit opt-in (`-headless` / `-hybrid`). It needs
Chrome/Chromium (or chrome-headless-shell) and that browser's platform runtime
libraries, which are deliberately not installed by this package. Upstream may
fetch a browser at runtime when these modes are requested. To select an existing
browser explicitly, use `-system-chrome-path`; an explicitly supplied
`-chrome-ws-url` can attach to an existing debugging session. Browser modes and
browser downloads are not part of package acceptance. Standard crawling does
not require Go, Chrome, a service, credentials or cloud access.

Katana itself initializes a default form configuration under the user's home
when a crawl starts; this is upstream runtime behavior, not an install hook.
Use `-disable-update-check` to suppress its automatic online version check.
Only crawl targets for which you have permission.

## Verification

`tests/k/test_katana.py` covers static/isolation rules, all six URL/hash mappings,
registration, install/idempotence, version and an actual tiny local HTTP crawl.
The crawler must discover and fetch a distinct linked page. The test disables
updates, browser modes, known-file crawling, secret validation and redirects;
it isolates user configuration and removes its HTTP server, thread and process.
Removal is the last lifecycle test. Direct acceptance also checks the payload,
xvm route, repeated install/remove and overlay unregistration.
The first fresh xlings asset download timed out after 180 seconds. Local hook
and crawler acceptance uses the exact upstream ZIP, independently downloaded
and checksum-verified, seeded into the isolated client's cache. Fresh remote
installation remains an explicit CI check; no downloader workaround is shipped.

Local execution target: Linux x86_64 with xlings 2026.11.23.1 (CI's pin).
Linux aarch64, macOS and Windows payloads were downloaded and inspected, but
cannot be executed on that host; native installation/runtime checks remain for CI.

## Revision log

- 2026-11-28 — added 1.8.0 using all six official portable ZIPs; no browser bundled.
