# carapace

A multi-shell completion binary (`carapace`), `status = "stable"`.

- Upstream: https://github.com/carapace-sh/carapace-bin (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream 32-bit x86, Termux, Android, and distro packages (`.deb`, `.rpm`, `.apk`) are omitted because `archs` only declares `x86_64` and `aarch64`.

## Source

- Tier: upstream release (`carapace-sh/carapace-bin` GitHub Releases)
- GLOBAL: `https://github.com/carapace-sh/carapace-bin/releases/download/v${version}/carapace-bin_${version}_${os_or_darwin}_${arch_alias}.${ext}`
- CN: none yet (`ci = { mirror = true }` so CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: matched `carapace-bin_1.8.5_checksums.txt` and `sha256sum` of all six downloaded archives
- Auto-update: yes (`extensions.autoupdate`, `GLOBAL`, `required = true`)

## Linking

Static Go binaries across all supported platforms:
- `linux/x86_64` and `linux/aarch64`: `file` reports statically linked ELF64 executables; `readelf -d` reports no dynamic section.
- `windows/x86_64` and `windows/aarch64`: PE32+ executables importing `kernel32.dll` only.
- Declares no `deps`.

## What the hooks do

- install: extracts the flat archive directly into a clean `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `payload.unpack{}` using `System32\tar.exe` on Windows) and verifies `carapace` / `carapace.exe`, `LICENSE`, and `README.md` with `payload.require`.
- config: registers `carapace` with `xvm.add("carapace", { bindir = pkginfo.install_dir() })`.
- uninstall: removes the `xvm` registration via `xvm.remove("carapace")`.
- System impact: none; does not touch shell profiles, `PATH`, or system package managers.

## Verification

- Downloaded all six `v1.8.5` archives, verified SHA-256 against `carapace-bin_1.8.5_checksums.txt`, inspected Linux ELF (`x86_64`, `aarch64`) and Windows PE (`x86_64`, `aarch64`) linkage.
- Verified `carapace --version`, `carapace --help`, and completion output on `linux/x86_64` in an isolated `XLINGS_HOME`.
- Ran `pytest tests/c/test_carapace.py -m "static or isolation" -v`, `pytest tests/c/test_carapace.py -m index -v`, `pytest tests/c/test_carapace.py -m "lifecycle or verify" -v`, `pytest tests/ -m "static or isolation" --tb=short -q`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only carapace`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (no local hosts for those targets; left to CI).

## Revision log

- 2026-11-26 — added at 1.8.5: static Go binaries for Linux, macOS, and Windows (`x86_64` / `aarch64`), flat archive extraction into `pkginfo.install_dir()`.
