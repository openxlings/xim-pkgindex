# glow

Render markdown on the CLI, with pizzazz! (`charmbracelet/glow`, status: `stable`).

- Upstream: https://github.com/charmbracelet/glow (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream v3.0.0 does not publish a `windows/aarch64` archive.

## Source

- Tier: official GitHub release (`https://github.com/charmbracelet/glow/releases`)
- GLOBAL:
  - `linux`: `glow_${version}_Linux_{x86_64,arm64}.tar.gz`
  - `macosx`: `glow_${version}_Darwin_{x86_64,arm64}.tar.gz`
  - `windows`: `glow_${version}_Windows_x86_64.zip`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL to `xlings-res` after merge)
- Checksums: taken from upstream `checksums.txt` for `v3.0.0` and verified by downloading all five archives and running `sha256sum -c --ignore-missing checksums.txt`.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking & CLI Behavior

- `linux/x86_64`: statically linked Go ELF (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Zero runtime dependencies declared.
- `linux/aarch64`: statically linked Go ELF (`readelf -d`: no dynamic section). Zero runtime dependencies declared.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ executable importing only `kernel32.dll` (no `VCRUNTIME140.dll` or MinGW DLL dependencies).
- Tested `timeout 5 ./glow /? </dev/null`: treats `/?` as a file path, prints `Error: unable to open file: open /?: no such file or directory`, and exits cleanly with status 1 without launching an interactive TUI.

## What the hooks do

- `install`: unpacks the archive's single top-level directory (`glow_<ver>_<OS>_<arch>/`) directly into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem, strip = 1 }`, runs `chmod +x` on POSIX via `xim.pkgindex.shell`, and asserts `glow` / `glow.exe` and `LICENSE` via `payload.require`.
- `config`: registers `glow` (`bindir = pkginfo.install_dir()`) via `xvm.add`.
- `uninstall`: removes `glow` via `xvm.remove`.
- System impact: none outside `$XLINGS_HOME` (no shell profile, `PATH`, or host config modified).

## Verification

- Verified locally on Linux `x86_64` in an isolated `HOME` and `XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search glow`, `xlings install local:glow -y`, `glow --version`, `glow README.md`, `timeout 5 glow /? </dev/null`, `xlings list`, idempotent reinstall, `xlings remove local:glow -y`, and `xlings config --remove-xpkg glow`.
- Verified `pytest tests/g/test_glow.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `.github/scripts/dep-closure-check.sh`, and `python3 tools/xpkg_ci.py inspect --only glow`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (archive checksums, ELF/PE linkage, and Windows `payload.unpack` hook behavior in Lua sandbox were verified locally; runtime installs are covered by CI).

## Revision log

- 2026-11-26 — added at 3.0.0: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
