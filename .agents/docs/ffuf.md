# ffuf

Fast web fuzzer written in Go (`ffuf`, "Fuzz Faster U Fool"); provides `ffuf`, `status = "stable"`.

- Upstream: https://github.com/ffuf/ffuf (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes 32-bit x86, ARMv6, FreeBSD, and OpenBSD builds, which are outside xlings' `archs` matrix.

## Source

- Tier: upstream release (`https://github.com/ffuf/ffuf/releases`)
- GLOBAL:
  - `linux`: `https://github.com/ffuf/ffuf/releases/download/v${version}/ffuf_${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/ffuf/ffuf/releases/download/v${version}/ffuf_${version}_macOS_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/ffuf/ffuf/releases/download/v${version}/ffuf_${version}_windows_${arch_alias}.zip` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `ffuf_2.3.0_checksums.txt` and verified locally via `sha256sum` against all six downloaded release archives and GitHub release asset digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}` across all six platform/arch targets).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables (`file` reports `statically linked`; `readelf -d` reports `There is no dynamic section in this file.`; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): Mach-O 64-bit `x86_64` and `arm64` executables (`ffuf_2.3.0_macOS_{amd64,arm64}.tar.gz`).
- Windows (`x86_64`, `aarch64`): PE32+ console (`CUI`) executables importing only `kernel32.dll`; no VCRUNTIME or external DLL deps. `ffuf -V` prints `ffuf version: 2.3.0` and exits `0`; `ffuf /?` prints missing-flag errors plus full help text and exits `1` offline without blocking (compatible with `windows-test.ps1`'s bounded probe).

## What the hooks do

- install: upstream archives are flat at root (`ffuf` / `ffuf.exe`, `CHANGELOG.md`, `LICENSE`, `README.md`). Extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows) and asserts all four files via `payload.require`.
- config: registers `ffuf` via `xvm.add("ffuf", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `ffuf` via `xvm.remove("ffuf")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation: `pytest tests/f/test_ffuf.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only ffuf`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-ffuf` & `XLINGS_HOME=/tmp/xlings-ffuf`): `xlings config --add-xpkg`, `xlings search ffuf`, `xlings install local:ffuf@2.3.0 -y`, `ffuf -V`, `ffuf -h`, loopback HTTP fuzzing against `127.0.0.1`, `xlings list ffuf`, idempotent reinstall, `xlings remove ffuf -y`, `xlings config --remove-xpkg ffuf`, and `pytest tests/f/test_ffuf.py`.
- Not run locally: `linux` `aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) live installs (x86_64 Linux host); delegated to GitHub Actions CI (`linux-test`, `macos-install-test`, `windows-test`).

## Revision log

- 2026-11-26 — added at `2.3.0`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`, `aarch64`).
