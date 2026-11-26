# step

Smallstep CLI (`step`), a zero trust swiss army knife for working with X.509 certificates, OAuth, JWT, OATH OTP, and SSH certificates (`smallstep/cli`). Status: `stable`.

- Upstream: https://github.com/smallstep/cli (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`) — covers all primary desktop/server architectures published by upstream `v0.31.0`.

## Source

- Tier: official GitHub release (`https://github.com/smallstep/cli/releases`)
- GLOBAL:
  - `linux`: `step_linux_${version}_{amd64,arm64}.tar.gz`
  - `macosx`: `step_darwin_${version}_{amd64,arm64}.tar.gz`
  - `windows`: `step_windows_${version}_{amd64,arm64}.zip`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res` after merge).
- Checksums: verified SHA256 against upstream `checksums.txt`, GitHub release asset digests, and locally downloaded bytes of all 6 archives (exact match).
- Auto-update: yes (`extensions.autoupdate`, GLOBAL required across all 6 platform/arch targets using `${tag}` and `${version}`).

## Linking & CLI Behavior

- `linux/x86_64` and `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d`: no dynamic section; `ldd` on x86_64: not a dynamic executable). Declares no runtime `deps`.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64` and `windows/aarch64`: PE32+ console executables importing only `kernel32.dll` (no `VCRUNTIME140.dll` or MSVC runtime dependency).
- Archive layout: all 6 archives unpack under `step_${version}/` containing `bin/step` (or `bin/step.exe`), `LICENSE`, `README.md`, and `autocomplete/`.
- Tested `timeout --foreground -k 2 5 ./step /? </dev/null`: prints `No help topic for '/?'` and exits cleanly with status 3 without hanging or opening a TUI. `step version` prints `Smallstep CLI/0.31.0 (linux/amd64)`.

## What the hooks do

- `install`: unpacks `step_${version}/` into `pkginfo.install_dir()` via `payload.unpack{ extracted = "step_" .. pkginfo.version(), strip = 1 }` and verifies `bin/step` (or `bin/step.exe`) and `LICENSE` via `payload.require(...)`.
- `config`: registers `step` with `xvm.add("step", { bindir = pkginfo.install_dir() .. "/bin" })`.
- `uninstall`: removes `step` via `xvm.remove("step")`.
- System impact: none; isolated under `pkginfo.install_dir()` and xvm shims inside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `HOME=/tmp/xlings-step` and `XLINGS_HOME=/tmp/xlings-step`:
  - `xlings config --add-xpkg pkgs/s/step.lua`, `xlings search step`, `xlings install local:step@0.31.0 -y`, `step version`, `step --version`, `step certificate create` + `step certificate inspect`, `xlings list step`, idempotent reinstall, `xlings remove step -y`, and `xlings config --remove-xpkg step`.
  - `pytest tests/s/test_step.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
  - Repository-wide `pytest tests/ -m "static or isolation" -q`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only step`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (archive checksums, ELF/PE linkage, and Windows/macOS Lua sandbox hook tests were verified locally; runtime installs are covered by GitHub Actions CI).

## Revision log

- 2026-11-26 — added at `0.31.0`: initial `spec = "2"` recipe covering `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`), `ci = { mirror = true }`, and `extensions.autoupdate`.
