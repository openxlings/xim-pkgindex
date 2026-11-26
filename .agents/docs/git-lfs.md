# git-lfs

Git extension for versioning large files (`git-lfs/git-lfs`), `status = "stable"`.

- Upstream: https://git-lfs.com (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Covers all 6 upstream `amd64`/`arm64` release assets for `v3.8.1`.

## Source

- Tier: upstream GitHub release (`git-lfs/git-lfs`)
- GLOBAL:
  - `linux`: `https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-linux-${arch_alias}-v${version}.tar.gz`
  - `macosx`: `https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-darwin-${arch_alias}-v${version}.zip`
  - `windows`: `https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-windows-${arch_alias}-v${version}.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified locally via `sha256sum` against all 6 archives downloaded from `git-lfs/git-lfs` release `v3.8.1` and confirmed against upstream `sha256sums.asc` and GitHub release digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}`).

## Linking & Archive Layout

- Archive layout: all 6 archives pack a single top-level directory `git-lfs-3.8.1/` (`git-lfs-${version}/`, not the archive stem) containing `git-lfs` (or `git-lfs.exe` on Windows), `README.md`, `CHANGELOG.md`, `man/`, and `install.sh` (Unix only).
- `linux/x86_64`, `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d` reports no `.dynamic` section; `ldd` reports not a dynamic executable). Zero runtime dependencies declared.
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables (`x86_64`, `arm64`).
- `windows/x86_64`, `windows/aarch64`: PE32+ console executables (`0x8664`, `0xaa64`) importing only `kernel32.dll`. Zero runtime dependencies declared.

## What the hooks do

- `installed`: checks `payload.present({ "git-lfs", "README.md" })` or `payload.present({ "git-lfs.exe", "README.md" })`.
- `install`: detects Windows via path/environment (never by `.zip`, since macOS also ships `.zip`), unpacks `git-lfs-<version>/` via `payload.unpack` (or `unzip`/`tar` fallback on POSIX when not pre-extracted) into `pkginfo.install_dir()`, runs `chmod +x` on Unix, and verifies `git-lfs`/`git-lfs.exe` and `README.md` exist.
- `config`: registers `git-lfs` via `xvm.add("git-lfs", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `git-lfs` via `xvm.remove("git-lfs")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation checks: `pytest tests/g/test_git_lfs.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation" -q`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `python3 tools/xpkg_ci.py inspect --only git-lfs`.
- Isolated `HOME=/tmp/xlings-git-lfs XLINGS_HOME=/tmp/xlings-git-lfs` (`linux/x86_64`): `xlings config --add-xpkg pkgs/g/git-lfs.lua`, `xlings search git-lfs`, `xlings install local:git-lfs -y`, `git-lfs version`, `xlings remove local:git-lfs -y`, and `pytest tests/g/test_git_lfs.py -m "index or lifecycle or verify" -v`.
- Not run locally: `linux/aarch64`, `macosx`, and `windows` runtime installs (covered by CI; binary SHA256s, archive layouts, ELF dynamic sections, Mach-O headers, and PE imports verified locally for all 6 assets).

## Revision log

- 2026-11-26 — added at `3.8.1`: initial `spec = "2"` recipe covering all 6 upstream targets (`linux` `.tar.gz`, `macosx` `.zip`, `windows` `.zip` x `x86_64`/`aarch64`).
