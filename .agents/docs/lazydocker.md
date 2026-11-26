# lazydocker

The lazier way to manage everything docker (`jesseduffield/lazydocker`); provides the `lazydocker` CLI/TUI (status: `stable`).

- Upstream: https://github.com/jesseduffield/lazydocker (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `armv6`/`armv7`/`x86` assets, which are outside xlings' `archs` matrix.

## Source

- Tier: upstream official repository release (`https://github.com/jesseduffield/lazydocker/releases`)
- GLOBAL:
  - `linux`: `https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_${arch_alias}.tar.gz` (`x86_64`, `arm64`)
  - `macosx`: `https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Darwin_${arch_alias}.tar.gz` (`x86_64`, `arm64`)
  - `windows`: `https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Windows_${arch_alias}.zip` (`x86_64`, `arm64`)
- CN: none yet (`ci = { mirror = true }`; CI will mirror GLOBAL assets to `xlings-res` after merge; every asset has a distinct filename with zero basename collision)
- Checksums: taken from upstream `checksums.txt` for `v0.25.2` and verified locally via `sha256sum` across all 6 downloaded release archives
- Auto-update: yes (`extensions.autoupdate` with `${tag}` and `${version}` pointing to `https://github.com/jesseduffield/lazydocker/releases`)

## Linking

- `linux/x86_64` and `linux/aarch64`: static Go ELF executables (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: official Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64` and `windows/aarch64`: PE32+ console executables (`0x8664` and `0xaa64`), importing `kernel32.dll` only; no `VCRUNTIME140.dll` or external DLL dependencies.
- CLI probe check: `lazydocker --version` exits 0, `lazydocker --help` exits 0, `lazydocker --config` prints default YAML and exits 0, and `lazydocker /?` prints help and exits immediately (exit 2, `Unexpected argument: /?`) without launching the TUI or requiring a Docker daemon.

## What the hooks do

- `install`: upstream archives are flat at root (`lazydocker` / `lazydocker.exe`, `LICENSE`, `README.md`). Extracts directly from the archive into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows, with pre-extracted fallback) and verifies the binary with `payload.require`.
- `config`: registers `lazydocker` via `xvm.add("lazydocker", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `lazydocker` via `xvm.remove("lazydocker")`.
- System impact: none (no shell profile, `PATH`, or system configuration edits).

## Verification

- Static & isolation: `pytest tests/l/test_lazydocker.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `python3 .github/scripts/version-check.py --workspace .`, and `python3 tools/xpkg_ci.py inspect --only lazydocker`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-lazydocker XLINGS_HOME=/tmp/xlings-lazydocker`): `xlings config --add-xpkg pkgs/l/lazydocker.lua`, `xlings search lazydocker`, `xlings install local:lazydocker -y`, `lazydocker --version` (`Version: 0.25.2`), `lazydocker --help`, `lazydocker --config`, `pytest tests/l/test_lazydocker.py -m "index or lifecycle or verify" -v`, `xlings remove local:lazydocker -y`, and clean removal check.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (x86_64 Linux host); delegated to GitHub Actions CI (`linux/aarch64`, `macosx/aarch64`, `windows/x86_64`; `macosx/x86_64` and `windows/aarch64` are archive/checksum-verified).

## Revision log

- 2026-11-26 — added at `0.25.2`: initial spec-2 recipe for linux (`x86_64`, `aarch64`), macosx (`x86_64`, `aarch64`), and windows (`x86_64`, `aarch64`) with verified static Go ELFs and `kernel32.dll`-only Windows PEs.
