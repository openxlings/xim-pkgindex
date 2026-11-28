# subfinder

Fast passive subdomain discovery tool written in Go, providing the `subfinder` CLI (`stable`).

- Upstream: https://github.com/projectdiscovery/subfinder (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `linux_386`, `linux_arm`, and `windows_386`, which are outside `archs`.

## Source

- Tier: upstream release
- GLOBAL: `https://github.com/projectdiscovery/subfinder/releases/download/v${version}/subfinder_${version}_${os}_${arch_alias}.zip` (`macOS` for `macosx`)
- CN: none yet (`ci = { mirror = true }` declared so CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: `subfinder_2.17.0_checksums.txt` from the `v2.17.0` GitHub release; all 6 downloaded `.zip` archives matched byte-for-byte.
- Auto-update: yes (`extensions.autoupdate` tracking `https://github.com/projectdiscovery/subfinder/releases`, `GLOBAL` required = true).

## Linking

Static Go binaries with zero declared runtime dependencies:
- `linux/x86_64`, `linux/aarch64`: static ELF executables (`readelf -d` reports no `.dynamic` section).
- `macosx/x86_64`, `macosx/aarch64`: Mach-O 64-bit executables (`DYLDLINK|PIE`).
- `windows/x86_64`, `windows/aarch64`: PE32+ console executables importing `kernel32.dll` only.

## What the hooks do

- `install`: cleans `pkginfo.install_dir()` and unpacks the flat `.zip` archive directly into `pkginfo.install_dir()` (`unzip -q -o` + `chmod +x` on POSIX; `payload.unpack{}` on Windows) to prevent shared `runtimedir` contents from leaking in, then verifies `subfinder` / `subfinder.exe`, `LICENSE.md`, and `README.md` via `payload.require`.
- `config`: registers `subfinder` via `xvm.add("subfinder", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `subfinder` via `xvm.remove("subfinder")`.
- System impact: none (self-contained under `XLINGS_HOME`; never touches shell profiles, `PATH`, or system package managers).

## Verification

- Verified on `linux/x86_64` in an isolated `XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search`, `xlings install subfinder@2.17.0 -y`, `subfinder -disable-update-check -version`, `subfinder -disable-update-check -h`, `subfinder -disable-update-check -ls`, idempotent reinstall, and `xlings remove subfinder -y`.
- Ran `pytest tests/s/test_subfinder.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only subfinder`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64`, `windows/aarch64` runtime execution (archives downloaded, SHA-256 verified, and binary headers/imports inspected; runtime execution left to CI).

## Revision log

- 2026-11-26 — added at `2.17.0`: initial spec-2 xpkg covering all 6 `x86_64`/`aarch64` upstream archives.
