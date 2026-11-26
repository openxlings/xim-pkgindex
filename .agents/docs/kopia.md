# kopia

Fast and secure open source backup (`kopia/kopia`).

## Packaging notes

- **Version**: `0.23.1` (upstream tag `v0.23.1`).
- **Platforms & architectures**:
  - `linux`: `x86_64` (`x64`), `aarch64` (`arm64`) — `.tar.gz` containing static Go ELF64 `kopia` (no `.dynamic` section, zero `DT_NEEDED` entries).
  - `macosx`: `x86_64` (`x64`), `aarch64` (`arm64`) — `.tar.gz` containing Mach-O `kopia`.
  - `windows`: `x86_64` (`x64`) — `.zip` containing PE32+ `kopia.exe` (imports only `kernel32.dll`, no VCRUNTIME dependency). Upstream does not publish a `windows-arm64` asset.
- **Mirror**: `ci = { mirror = true }` (no CN mirror declared).
- **Autoupdate**: `extensions.autoupdate` configured against `https://github.com/kopia/kopia/releases`.
