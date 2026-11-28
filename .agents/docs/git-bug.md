# git-bug

Stable distributed, offline-first issue tracker storing issues in Git objects; provides `git-bug`.

- Upstream: https://github.com/git-bug/git-bug (GPL-3.0).
- Namespace: `xim`; official upstream binaries, not repackaged or compiled.
- Platforms: Linux x86_64/aarch64 and Windows x86_64.
- The official v0.12.0 release has all six Linux/macOS/Windows amd64/arm64 binaries.
  All six were downloaded and checked against upstream `checksums.txt` and API digests.
  macOS is omitted because `xim:git` has no macOS resource. Windows ARM64 is omitted
  because its indexed Git release has only an x86_64 asset. Neither falls back to host Git.
- GitHub API observed 10,890 stars on 2026-11-28; `/releases/latest` reported v0.12.0.

## Source

- Tier: upstream release, https://github.com/git-bug/git-bug/releases/tag/v0.12.0.
- GLOBAL: `https://github.com/git-bug/git-bug/releases/download/v${version}/git-bug_linux_${arch_alias}`
  or `git-bug_windows_${arch_alias}.exe`; aliases are amd64/arm64.
- CN: none verified. `ci.mirror = true` requests post-merge mirroring without changing URLs.
- Checksums: official release `checksums.txt`, cross-checked with the GitHub asset
  SHA256 digests and locally calculated SHA256 of the downloaded bytes. Upstream also
  publishes `checksums.txt.sigstore.json`; signature verification was not performed.
- Auto-update: GLOBAL-only `extensions.autoupdate`, all three indexed targets required.
  Templates use `${tag}` and match the raw official assets, not tar/zip or SBOM files.

## Linking

- Both Linux binaries are static ELF files with no PT_INTERP or dynamic section;
  no libc loader, RPATH patching or compiler runtime dependency is needed.
- Windows x86_64 imports `kernel32.dll` only; no Visual C++ runtime DLL is required.
- `xim:git` is an explicit runtime dependency on every supported platform because
  git-bug runs Git to persist issues. Linux Git has both native architectures;
  Windows Git 2.51.1 has only `git-2.51.1-windows-x86_64.zip`.

## What the hooks do

- install: move the raw binary to `git-bug` / `git-bug.exe` in its own install directory;
  chmod the Unix executable and assert the expected file exists.
- installed: check for the executable, never merely its directory.
- config: register `git-bug` with xvm using its install directory.
- uninstall: remove the xvm registration; xlings removes its managed payload and shim.
- System impact: no shell/profile edits, PATH mutation, Git global configuration,
  services, credentials, bridges, or network remotes are created by the hooks.
- Native version command is `git-bug version`; v0.12.0 rejects `--version`.

## Verification

- `tests/g/test_git_bug.py` covers static metadata, Lua syntax, shared isolation
  policy, index registration/search, install/reinstall/list, version,
  actual offline issue creation/list/read/close in a temporary local Git repository,
  and remove/re-remove plus xvm shim/workspace cleanup.
- The functional workflow uses only the managed Git shim on PATH, disables system/global
  Git config, and sets identity only in the temporary repository. It creates no remote.
- Local native execution is Linux x86_64; Linux ARM64 and Windows execution require CI
  or their native hosts. Byte/header/hash inspection is not native installation testing.
- PR verification records the exact targeted pytest, policy, updater and mirror results.

## Revision log

- 2026-11-28 — added v0.12.0 with managed-Git-compatible platforms and raw binaries.
