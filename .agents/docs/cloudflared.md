# cloudflared

Cloudflare Tunnel client (`cloudflared`), `status = "stable"`.

- Upstream: https://github.com/cloudflare/cloudflared (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream also ships `386`, `arm`, `armhf`, `.deb`, `.rpm`, `.msi`, and FIPS builds, omitted here; no `windows-arm64` asset is published upstream.

## Source

- Tier: upstream GitHub release (`cloudflare/cloudflared`)
- GLOBAL:
  - Linux: `https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-linux-{amd64,arm64}`
  - macOS: `https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-{amd64,arm64}.pkg` (chosen over `.tgz` because `tools/xpkg_ci.py` mirror validation does not support `.tgz`)
  - Windows: `https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-windows-amd64.exe`
- CN: none yet (declares `ci = { mirror = true }`)
- Checksums: verified against GitHub release asset digests and locally computed SHA-256 hashes of all five downloaded `2026.11.2` assets.
- Auto-update: yes (`extensions.autoupdate`, `GLOBAL` required across all 5 platform/arch targets; release tags are bare `YYYY.MM.N` without a `v` prefix).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF64 executables (`readelf -d` shows no `.dynamic` section, `readelf -l` shows no `INTERP`). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): signed component `.pkg` (`xar` archive whose `Payload` gzip/cpio holds `./cloudflared`, a 64-bit Mach-O executable for `x86_64` or `arm64`).
- Windows (`x86_64`): PE32+ console executable importing `KERNEL32.dll` and Windows 10 Universal CRT API sets (`api-ms-win-crt-*.dll`) only; no `VCRUNTIME140.dll` or `MSVCP140.dll`.

## What the hooks do

- install:
  - macOS: expands `.pkg` via `pkgutil --expand-full` into `<install_dir>/._pkg`, moves `Payload/cloudflared` to `<install_dir>/cloudflared`, deletes `._pkg`, and runs `chmod +x`.
  - Linux & Windows: moves the downloaded standalone binary (`pkginfo.install_file()`) to `<install_dir>/cloudflared` (or `cloudflared.exe` on Windows), running `chmod +x` on Linux.
  - All platforms assert `payload.require({ exe })`.
- config: registers `cloudflared` via `xvm.add("cloudflared", { bindir = pkginfo.install_dir() })` (plus `alias = "cloudflared.exe"` on Windows).
- uninstall: removes `cloudflared` via `xvm.remove("cloudflared")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified `linux/x86_64` locally in an isolated `HOME` and `XLINGS_HOME` (`/tmp/xlings-cloudflared`): `xlings config --add-xpkg`, `xlings install local:cloudflared -y`, `cloudflared --version`, `cloudflared --help`, `xlings remove local:cloudflared -y`, and `posix-test.sh`-style checks.
- Ran `pytest tests/c/test_cloudflared.py -m "static or isolation" -v`, repo-wide static checks (`test_docs.py`, `test_agent_files.py`, `test_shortcut.py`, `test_platform_version_parity.py`, `test_no_compiler_runtime_in_payloads.py`, `test_xpkg_spec.py`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect --only cloudflared`.
- `linux/aarch64`, `macosx/*`, and `windows/x86_64` runtime installs were not executed locally (verified via `readelf` on `linux/aarch64`, xar TOC + cpio `Payload` + Mach-O checks on `macosx/*`, PE import inspection on `windows/x86_64`, and Lua unit tests; CI validates Linux, macOS, and Windows).

## Revision log

- 2026-11-26 — added at `2026.11.2`.
