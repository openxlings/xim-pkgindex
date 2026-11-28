# crane

CLI tool for interacting with remote container images and OCI registries (`crane`, plus bundled `gcrane` and `krane`), `status = "stable"`.

- Upstream: https://github.com/google/go-containerregistry (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes Linux `armv6`, `i386`, `loong64`, `ppc64le`, `riscv64`, `s390x`, which are omitted as xlings targets `x86_64` and `aarch64`.

## Source

- Tier: upstream release (`https://github.com/google/go-containerregistry/releases`)
- GLOBAL: `go-containerregistry_{Linux,Darwin,Windows}_{x86_64,arm64}.tar.gz` (note Windows ships `.tar.gz`, not `.zip`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `checksums.txt` for `v0.22.1` and verified locally via `sha256sum -c checksums.txt` across all six archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}`).

## Linking

- Linux (`x86_64`, `aarch64`): all three binaries (`crane`, `gcrane`, `krane`) are statically linked Go ELF executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`, `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- Windows (`x86_64`, `aarch64`): all three PE32+ executables (`crane.exe`, `gcrane.exe`, `krane.exe`) import only `kernel32.dll` (no VCRUNTIME or MinGW DLL dependencies).

## What the hooks do

- install: extracts the flat `.tar.gz` directly into `pkginfo.install_dir()` (using `%SystemRoot%\System32\tar.exe` on Windows because `libs/payload.lua` only dispatches `.zip`, and system `tar` on POSIX; falls back to moving the five known files if pre-extracted), `chmod +x` on POSIX binaries, and asserts `crane`, `gcrane`, `krane` (with `.exe` on Windows) plus `LICENSE` via `payload.require`.
- config: registers `crane` as the root program (`xvm.add("crane", { bindir = pkginfo.install_dir() })`) and `gcrane` and `krane` with `binding = "crane@" .. pkginfo.version()`. `programs = {"crane"}` is kept minimal so CI probes `crane` directly.
- uninstall: removes `krane`, `gcrane`, and `crane` via `xvm.remove`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` & `HOME`: `xlings config --add-xpkg`, `xlings install local:crane -y`, `crane version`, `gcrane version`, `krane version`, `crane completion bash`, `xlings list`, idempotent reinstall, `xlings remove local:crane -y`, and `xlings config --remove-xpkg crane`.
- Ran `pytest tests/c/test_crane.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repo-wide `static or isolation`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect/materialize`.
- Not run locally: `macosx` (`x86_64`, `aarch64`), `linux` (`aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (Windows `.tar.gz` hook was exercised via Lua unit tests, and CI validates Linux, macOS, and Windows).

## Revision log

- 2026-11-26 — added at 0.22.1: initial `spec = "2"` recipe covering Linux, macOS, and Windows (`x86_64`, `aarch64`) with `crane`, `gcrane`, and `krane`.
