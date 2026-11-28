# rqlite

Rqlite is a distributed relational database built on SQLite. The 10.8.0 package is stable and provides `rqlite`, `rqlited`, and the Linux-only `rqbench` companion.

- Upstream: https://github.com/rqlite/rqlite (MIT)
- Namespace: `xim`
- Platforms: Linux x86_64/aarch64 and Windows x86_64. The v10.8.0 release has no portable macOS or Windows ARM64 asset selected here.

## Source

- Tier: upstream GitHub release v10.8.0
- GLOBAL: `https://github.com/rqlite/rqlite/releases/download/v${version}/rqlite-v${version}-linux-${arch_alias}.tar.gz` and `.../rqlite-v${version}-win64.zip`
- CN: none yet (no verified mirror)
- Checksums: downloaded release archives agreed with the SHA256 `digest` values in the official GitHub release metadata: Linux x86_64 `3bf0f1dba46b4d069ef3c49dc1fe1d1a05d5ad9d16d1de9daa4afea1f0203038`, Linux aarch64 `a26bb98755bb608cff457e3d0a2161bca42dbe8bc507a6373595c04d44d576f9`, Windows x86_64 `a5da71daafe91b5dee72b03753f26b2871725dcc01a508a1fc5b3691e1f5ef07`.
- Auto-update: yes (`extensions.autoupdate`), GLOBAL only.

## Linking

Linux archives contain dynamic GNU ELF programs. The recipe declares `xim:glibc@2.44.3`; automatic ELF sealing uses the build dependency `xim:patchelf@>=0.19.3` because the older patchelf build corrupted the Go client. The nominal upstream amd64-musl archive was inspected and is dynamic, so it is not advertised. Windows uses the operating system runtime and declares no xlings runtime dependency.

## What the hooks do

- install: use the shared payload unpacker, preserve the archive's complete executable set, and require every expected client/server/benchmark file.
- config: register `rqlite` and `rqlited`; register `rqbench` when the Linux payload contains it, binding companions to the client version.
- uninstall: remove exact namespace-qualified xvm version keys for all registered programs.
- System impact: none outside the package directory and xlings metadata; installation does not start a server or write user configuration.

## Verification

Focused `pytest -q tests/r/test_rqlite.py` passed 9 tests on Linux x86_64 after the final test-driver and Windows provenance repair. A fresh isolated Linux home, with both `XLINGS_SUBOS_LIB` and `XLINGS_SUBOS_LIBS` set to the temporary SubOS library directory, initialized the copied xlings client, installed the local recipe, ran generated client/server shims, exercised real loopback HTTP CREATE/INSERT/SELECT (`[['native']]`), and removed the package; both program shims were absent afterward. Windows client verification pins the exact upstream default output plus the verified executable hash and embedded clean Go module/revision identity; native Windows SQL remains CI coverage.

## Revision log

- 2026-11-27 — added at 10.8.0: upstream portable archives, exact platform matrix, glibc/patchelf runtime handling, and namespace-safe companion registrations.
