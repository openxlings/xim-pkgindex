# q

Tiny command-line DNS client with support for UDP, TCP, DoT, DoH, DoQ and ODoH; provides `q`, `status = "stable"`.

- Upstream: https://github.com/natesales/q (GPL-3.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes FreeBSD, `.deb`, and `.rpm` artifacts, which are outside xlings' supported platform/archive matrix.

## Source

- Tier: upstream release (`https://github.com/natesales/q/releases`)
- GLOBAL: `https://github.com/natesales/q/releases/download/v${version}/q_${version}_<os>_${arch_alias}.<ext>` (`linux`/`darwin` `.tar.gz`, `windows` `.zip`; `arch_alias` maps `x86_64 -> amd64`, `aarch64 -> arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `q_0.19.12_checksums.txt` and verified locally via `sha256sum` across all six downloaded release archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}` across all six platform/arch targets).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): official Darwin archives (`q_0.19.12_darwin_{amd64,arm64}.tar.gz`).
- Windows (`x86_64`, `aarch64`): PE32+ console executables (`x86-64` and `ARM64`); `windows/x86_64` imports `kernel32.dll` only (`objdump -p`). `q /?` treats `/?` as a root NS query and exits cleanly (`EXIT=0`). Note that `q -v` enables verbose debug output rather than printing the version; `q --version` prints the version.

## What the hooks do

- install: upstream archives are flat at root (`q` / `q.exe`, `LICENSE`, `README.md`). Extracts directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows, with pre-extracted fallback) and asserts `q`/`q.exe` plus `LICENSE` via `payload.require`.
- config: registers `q` via `xvm.add("q", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `q` via `xvm.remove("q")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation: `pytest tests/q/test_q.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only q`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-q` & `XLINGS_HOME=/tmp/xlings-q`): `xlings config --add-xpkg`, `xlings search q`, `xlings install local:q@0.19.12 -y`, `q --version`, `q --help`, `xlings list q`, idempotent reinstall, `xlings remove q -y`, `xlings config --remove-xpkg q`, and `pytest tests/q/test_q.py`.
- Not run locally: `linux` `aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) live installs (x86_64 Linux host); delegated to GitHub Actions CI.

## Revision log

- 2026-11-26 — added at `0.19.12`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`, `aarch64`).
