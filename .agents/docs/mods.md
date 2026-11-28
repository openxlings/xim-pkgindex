# mods

GPT on the command line. Built for pipelines. (`charmbracelet/mods`, status: `stable`).

- Upstream: https://github.com/charmbracelet/mods (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: official GitHub release (`https://github.com/charmbracelet/mods/releases`)
- GLOBAL:
  - `linux`: `mods_${version}_Linux_{x86_64,arm64}.tar.gz`
  - `macosx`: `mods_${version}_Darwin_{x86_64,arm64}.tar.gz`
  - `windows`: `mods_${version}_Windows_{x86_64,arm64}.zip`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL to `xlings-res` after merge)
- Checksums: taken from upstream `checksums.txt` for `v1.8.1` and verified by downloading all six archives and running `sha256sum`.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking & CLI Behavior

- `linux/x86_64`: statically linked Go ELF (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Zero runtime dependencies declared.
- `linux/aarch64`: statically linked Go ELF (`readelf -d`: no dynamic section). Zero runtime dependencies declared.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64` and `windows/aarch64`: PE32+ console executables (`x86-64` and `ARM64`).
- Tested `timeout --foreground -k 2 5 ./mods /? </dev/null`: fails fast with `OpenAI authentication failed` (exit 1) without launching an interactive TUI.

## What the hooks do

- `install`: unpacks the archive's single top-level directory (`mods_<ver>_<OS>_<arch>/`) directly into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem, strip = 1 }`, runs `chmod +x` on POSIX via `xim.pkgindex.shell`, and asserts `mods` / `mods.exe` and `LICENSE` via `payload.require`.
- `config`: registers `mods` (`bindir = pkginfo.install_dir()`) via `xvm.add`.
- `uninstall`: removes `mods` via `xvm.remove`.
- System impact: none outside `$XLINGS_HOME` (no shell profile, `PATH`, or host config modified).

## Verification

- Verified locally on Linux `x86_64` in an isolated `HOME` and `XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search mods`, `xlings install local:mods -y`, `mods --version`, `mods --help`, `timeout --foreground -k 2 5 mods /? </dev/null`, `xlings list`, idempotent reinstall, `xlings remove local:mods -y`, and `xlings config --remove-xpkg mods`.
- Verified `pytest tests/m/test_mods.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only mods`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (archive checksums, ELF/PE inspection, and Windows `payload.unpack` hook behavior in Lua sandbox were verified locally; runtime installs are covered by CI).

## Revision log

- 2026-11-26 — added at 1.8.1: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`, `aarch64`).
