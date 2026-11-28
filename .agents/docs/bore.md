# bore

A small self-hosted TCP tunnel, providing the `bore local` client and `bore server` commands; stable.

- Upstream: https://github.com/ekzhang/bore (MIT), 11,641 GitHub stars at selection.
- Namespace: `xim`.
- Platforms: Linux and macOS `x86_64`/`aarch64`; Windows `x86_64`.
- Windows ARM64 is not declared: upstream v0.6.0 publishes no corresponding archive.

## Source

- Tier: official upstream GitHub release `v0.6.0`.
- GLOBAL: `https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-<target>.{tar.gz,zip}`.
- CN: none verified; `ci = { mirror = true }` opts into post-merge mirroring without inventing a download URL.
- Checksums: all five downloaded archives matched their upstream GitHub Release asset SHA256 digests.
- Auto-update: `extensions.autoupdate` explicitly covers the same five platform/architecture combinations.

## Linking

- Linux: official musl builds; x86_64 is static PIE with no `DT_NEEDED` or interpreter, aarch64 is static ELF with no dynamic section. No runtime dependencies.
- macOS: native Mach-O x86_64 and arm64 binaries.
- Windows: x86_64 PE imports `VCRUNTIME140.dll` and Windows OS/UCRT DLLs. Declares `xim:vcruntime` and copies its DLLs beside `bore.exe`; no redistributable installer or system-wide DLL deployment.

## What the hooks do

- install: extracts the flat upstream archive directly into the package's own directory, never moving the shared extraction directory. POSIX uses `tar` and restores executable permission; Windows uses the shared system-tar helper and deploys the declared CRT app-locally. Checks every installed executable/runtime file.
- config: registers `bore` with xvm, using the package directory as `bindir`.
- uninstall: removes the `bore` registration; xlings owns payload cleanup.
- System impact: none. No service starts, firewall rules, shell profiles, PATH edits, credentials, or user configuration writes.

## Verification

`tests/b/test_bore.py` covers metadata, SubOS isolation, index registration, installation, the actual shim's version output, and an authenticated TCP request/response with binary data and half-closes. The functional test binds only loopback addresses and always terminates its client/server; upstream's fixed control port 7835 must be free. Windows additionally checks that the CRT DLL is app-local. Native results and direct install/reinstall/uninstall observations are recorded in the PR, separately from cross-target archive inspection.

## Revision log

- 2026-11-28 — added at 0.6.0 using five unmodified upstream archives; static Linux binaries and explicit Windows runtime dependency.
