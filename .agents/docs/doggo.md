# doggo

Command-line DNS client for humans (supports UDP, TCP, DoH, DoT, DoQ, and DNSCrypt); provides `doggo`, `status = "stable"`.

- Upstream: https://github.com/mr-karan/doggo (GPL-3.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream also publishes `windows-i386`, BSD, and 32-bit ARM builds, which are outside xlings' `archs` matrix, and publishes no Windows ARM64 archive.

## Source

- Tier: upstream release (`https://github.com/mr-karan/doggo/releases`)
- GLOBAL: `https://github.com/mr-karan/doggo/releases/download/v${version}/doggo-<os>-${arch}.<ext>` (`linux`/`darwin` `.tar.gz`, `windows` `.zip`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `doggo_1.4.2_checksums.txt` and verified locally via `sha256sum -c` across all five downloaded release archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` across all five platform/arch targets).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): official Darwin archives (`doggo-darwin-{x86_64,aarch64}.tar.gz`).
- Windows (`x86_64`): PE32+ console executable (`x86-64`), importing `kernel32.dll` only (`objdump -p`); no VCRUNTIME or external DLL deps. `doggo /?` treats `/?` as a hostname query against the system resolver and exits cleanly (`EXIT=0` in ~3.3s on Linux).

## What the hooks do

- install: upstream archives are flat at root (`doggo` / `doggo.exe`, `LICENSE`, `README.md`). Extracts directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows, with pre-extracted fallback) and asserts `doggo`/`doggo.exe` plus `LICENSE` via `payload.require`.
- config: registers `doggo` via `xvm.add("doggo", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `doggo` via `xvm.remove("doggo")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation: `pytest tests/d/test_doggo.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only doggo`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-doggo` & `XLINGS_HOME=/tmp/xlings-doggo`): `xlings config --add-xpkg`, `xlings search doggo`, `xlings install local:doggo@1.4.2 -y`, `doggo --version`, `doggo completions bash`, `xlings list doggo`, idempotent reinstall, `xlings remove doggo -y`, `xlings config --remove-xpkg doggo`, and `pytest tests/d/test_doggo.py`.
- Not run locally: `linux` `aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`) live installs (x86_64 Linux host); delegated to GitHub Actions CI (`linux-test`, `macos-install-test`, `windows-test`).

## Revision log

- 2026-11-26 — added at `1.4.2`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
