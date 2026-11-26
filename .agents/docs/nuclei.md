# nuclei

Fast and customizable vulnerability scanner based on simple YAML-based DSL (`projectdiscovery/nuclei`); provides `nuclei`, `status = "stable"`.

- Upstream: https://github.com/projectdiscovery/nuclei (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream also publishes 32-bit x86 (`linux_386`, `windows_386`) and 32-bit ARM (`linux_arm`) builds, which are outside xlings' `archs` matrix, and does not publish a `windows/aarch64` asset.

## Source

- Tier: upstream release (`https://github.com/projectdiscovery/nuclei/releases`)
- GLOBAL:
  - `linux`: `https://github.com/projectdiscovery/nuclei/releases/download/v${version}/nuclei_${version}_linux_${arch_alias}.zip` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/projectdiscovery/nuclei/releases/download/v${version}/nuclei_${version}_macOS_${arch_alias}.zip` (`amd64` / `arm64`)
  - `windows`: `https://github.com/projectdiscovery/nuclei/releases/download/v${version}/nuclei_${version}_windows_${arch_alias}.zip` (`amd64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `nuclei_3.11.1_checksums.txt` and verified locally via `sha256sum` against all five downloaded release archives and GitHub release asset digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}` across all five platform/arch targets).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables (`file` reports `statically linked`; `readelf -d` reports `There is no dynamic section in this file.`; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): Mach-O 64-bit `x86_64` and `arm64` executables (`nuclei_3.11.1_macOS_{amd64,arm64}.zip`).
- Windows (`x86_64`): PE32+ console (`CUI`) executable importing only `kernel32.dll`; no VCRUNTIME or external DLL deps.
- Offline probe (`HOME` isolated, `unshare -rn` / dead proxy): `nuclei /? </dev/null` prints banner/version/no-templates error and exits `1` in ~0.07s without blocking (`windows-test.ps1` bounded probe compatible); `nuclei -version </dev/null` and `nuclei -disable-update-check -version </dev/null` exit `0` in ~0.07s.

## What the hooks do

- install: upstream archives are flat `.zip` files (`nuclei` / `nuclei.exe`, `LICENSE.md`, `README.md`, and localized `README_*.md`). Extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`unzip -q -o` + `chmod +x` via `xim.pkgindex.shell` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows, with pre-extracted fallback) and asserts `nuclei`/`nuclei.exe`, `LICENSE.md`, and `README.md` via `payload.require`.
- config: registers `nuclei` via `xvm.add("nuclei", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `nuclei` via `xvm.remove("nuclei")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation: `pytest tests/n/test_nuclei.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only nuclei`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-nuclei` & `XLINGS_HOME=/tmp/xlings-nuclei`): `xlings config --add-xpkg`, `xlings search nuclei`, `xlings install local:nuclei@3.11.1 -y`, `nuclei -disable-update-check -version`, `nuclei -disable-update-check -h`, offline loopback HTTP template scan against `127.0.0.1`, `xlings list nuclei`, idempotent reinstall, `xlings remove nuclei -y`, `xlings config --remove-xpkg nuclei`, and `pytest tests/n/test_nuclei.py`.
- Not run locally: `linux` `aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`) live installs (x86_64 Linux host); delegated to GitHub Actions CI (`install (linux)`, `install (macosx)`, `install (windows)`).

## Revision log

- 2026-11-26 — added at `3.11.1`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
