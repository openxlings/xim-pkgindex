# infracost

- **Package**: `pkgs/i/infracost.lua` (`spec = "2"`, `ci = { mirror = true }`)
- **Upstream**: Infracost GitHub Releases (`https://github.com/infracost/infracost/releases/download/v0.10.51/infracost-<os>-<arch>.{tar.gz,zip}`)
- **Version**: `0.10.51` (`linux`, `macosx`, `windows`; `x86_64` / `aarch64`)
- **Binary**: `infracost` (static Go ELF on Linux x86_64/aarch64 with no `NEEDED`; `kernel32.dll`-only PE32+ on Windows x86_64/arm64)
- **Notes**:
  - `extensions.autoupdate` tracks `https://github.com/infracost/infracost/releases` for all 6 platform/arch targets.
  - POSIX `.tar.gz` archives contain a single binary named `infracost-<os>-<arch>`, which `install()` renames to `infracost`.
  - Windows `.zip` archives contain a flat `infracost.exe`.
