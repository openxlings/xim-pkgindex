# vegeta

HTTP load testing tool and library (`tsenart/vegeta`); provides `vegeta`, `status = "stable"`.

- Upstream: https://github.com/tsenart/vegeta (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes 32-bit x86, ARMv6/7, FreeBSD, and OpenBSD builds, which are outside xlings' `archs` matrix.

## Source

- Tier: upstream release (`https://github.com/tsenart/vegeta/releases`)
- GLOBAL:
  - `linux`: `https://github.com/tsenart/vegeta/releases/download/v${version}/vegeta_${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/tsenart/vegeta/releases/download/v${version}/vegeta_${version}_darwin_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/tsenart/vegeta/releases/download/v${version}/vegeta_${version}_windows_${arch_alias}.zip` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `vegeta_12.13.0_checksums.txt` and verified locally via `sha256sum` against all six downloaded release archives and GitHub release asset digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}` across all six platform/arch targets).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables (`file` reports `statically linked`; `readelf -d` reports `There is no dynamic section in this file.`; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): Mach-O 64-bit `x86_64` and `arm64` executables (`vegeta_12.13.0_darwin_{amd64,arm64}.tar.gz`).
- Windows (`x86_64`, `aarch64`): PE32+ console (`CUI`) executables importing only `kernel32.dll`; no VCRUNTIME or external DLL deps. `vegeta -version` prints `Version: v12.13.0` and exits `0`; `vegeta /?` prints `Unknown command: /?` and exits `1` offline without blocking (compatible with `windows-test.ps1`'s bounded probe).

## What the hooks do

- install: upstream archives contain only the single binary at root (`vegeta` / `vegeta.exe`). Extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`libs/shell.lua` `shell.exec` `tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows, with pre-extracted binary fallback) and asserts the binary via `payload.require`.
- config: registers `vegeta` via `xvm.add("vegeta", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `vegeta` via `xvm.remove("vegeta")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation: `pytest tests/v/test_vegeta.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only vegeta`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-vegeta` & `XLINGS_HOME=/tmp/xlings-vegeta`): `xlings config --add-xpkg`, `xlings search vegeta`, `xlings install local:vegeta@12.13.0 -y`, `vegeta -version`, `vegeta -h`, loopback HTTP attack + report against `127.0.0.1`, `xlings list vegeta`, idempotent reinstall, `xlings remove vegeta -y`, `xlings config --remove-xpkg vegeta`, and `pytest tests/v/test_vegeta.py`.
- Not run locally: `linux` `aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) live installs (x86_64 Linux host); delegated to GitHub Actions CI (`linux-test`, `macos-install-test`, `windows-test`).

## Revision log

- 2026-11-26 — added at `12.13.0`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`, `aarch64`).
