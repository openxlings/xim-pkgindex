# httpx

Fast and multi-purpose HTTP toolkit written in Go (`projectdiscovery/httpx`); provides `httpx`, `status = "stable"`.

- Upstream: https://github.com/projectdiscovery/httpx (MIT)
- Docs: https://docs.projectdiscovery.io/tools/httpx/
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream also publishes 32-bit `linux_386`, `linux_arm`, and `windows_386` builds (outside xlings' `archs` matrix) and publishes no Windows ARM64 archive.

## Source

- Tier: upstream release (`https://github.com/projectdiscovery/httpx/releases`)
- GLOBAL:
  - `linux`: `https://github.com/projectdiscovery/httpx/releases/download/v${version}/httpx_${version}_linux_${arch_alias}.zip` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/projectdiscovery/httpx/releases/download/v${version}/httpx_${version}_macOS_${arch_alias}.zip` (`amd64` / `arm64`)
  - `windows`: `https://github.com/projectdiscovery/httpx/releases/download/v${version}/httpx_${version}_windows_${arch_alias}.zip` (`amd64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `httpx_1.12.0_checksums.txt` and verified locally via `sha256sum` against all five downloaded release archives and GitHub release asset digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}` across all five platform/arch targets).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables (`file` reports `statically linked`; `readelf -d` reports `There is no dynamic section in this file.`; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): Mach-O 64-bit `x86_64` and `arm64` executables (`httpx_1.12.0_macOS_{amd64,arm64}.zip`).
- Windows (`x86_64`): PE32+ console (`CUI`) executable importing only `kernel32.dll`; no `VCRUNTIME140.dll`, `MSVCP140.dll`, or delay-loaded DLLs. Offline probe: `httpx -version </dev/null` and `httpx --version </dev/null` print `v1.12.0` and exit `0`; `httpx /? </dev/null` prints version info and exits `0` immediately (if stdin is an unclosed pipe, `httpx /?` waits on stdin, in which case `windows-test.ps1`'s bounded probe falls back to `--version`, which exits `0` immediately).

## What the hooks do

- `installed()`: checks `payload.present({ "httpx", "LICENSE.md", "README.md" })` or `payload.present({ "httpx.exe", "LICENSE.md", "README.md" })`.
- `install()`: upstream archives are flat `.zip` files (`httpx` / `httpx.exe`, `LICENSE.md`, `README.md` at archive root). Extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`shell.exec({ "unzip", "-q", "-o", archive, "-d", dir })` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows, with fallback moves if pre-extracted) and asserts all three files via `payload.require`.
- `config()`: registers `httpx` via `xvm.add("httpx", { bindir = pkginfo.install_dir() })`.
- `uninstall()`: removes `httpx` via `xvm.remove("httpx")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation: `pytest tests/h/test_httpx.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only httpx`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-httpx` & `XLINGS_HOME=/tmp/xlings-httpx`): `xlings config --add-xpkg`, `xlings search httpx`, `xlings install local:httpx@1.12.0 -y`, `httpx -version`, `httpx -h`, loopback HTTP probe against `127.0.0.1`, `xlings list httpx`, idempotent reinstall, `xlings remove httpx -y`, idempotent re-remove, `xlings config --remove-xpkg httpx`, and `pytest tests/h/test_httpx.py`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` live installs (running on Linux `x86_64` host); delegated to GitHub Actions CI (`linux-test`, `macos-install-test`, `windows-test`).

## Revision log

- 2026-11-26 — added at `1.12.0`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
