# trufflehog

TruffleHog (`trufflehog`) is a CLI tool for finding, verifying, and analyzing leaked credentials across git repositories, filesystems, and other sources (`status = "stable"`).

- Upstream: https://github.com/trufflesecurity/trufflehog (AGPL-3.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (`https://github.com/trufflesecurity/trufflehog/releases`)
- GLOBAL:
  - `linux`: `https://github.com/trufflesecurity/trufflehog/releases/download/v${version}/trufflehog_${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/trufflesecurity/trufflehog/releases/download/v${version}/trufflehog_${version}_darwin_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/trufflesecurity/trufflehog/releases/download/v${version}/trufflehog_${version}_windows_${arch_alias}.tar.gz` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `trufflehog_3.100.1_checksums.txt` from the `v3.100.1` release; all 6 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports not a dynamic executable — zero runtime dependencies (`xim:glibc` is not declared). On Windows (`x86_64` and `aarch64`), PE32+ console binaries (`trufflehog.exe`) import only `kernel32.dll`.

## What the hooks do

- `installed`: checks `payload.present` for `trufflehog` / `trufflehog.exe`, `LICENSE`, `README.md`, and `docs/man/trufflehog.1`.
- `install`: every upstream archive is a flat `.tar.gz` at root containing `trufflehog` / `trufflehog.exe`, `LICENSE`, `README.md`, and `docs/man/trufflehog.1`. To avoid leaking files from other flat archives in shared `runtimedir`, `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (using `%SystemRoot%\System32\tar.exe` on Windows because `libs/payload.lua` only handles `.zip`, and system `tar` on POSIX with `chmod +x`), then asserts all 4 files via `payload.require`.
- `config`: registers `trufflehog` via `xvm.add("trufflehog", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `trufflehog` via `xvm.remove("trufflehog")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation pytest suites (`tests/t/test_trufflehog.py`, repo-wide `tests/ -m "static or isolation"`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only trufflehog` run locally.
- Isolated `xlings` install/verify/remove on Linux `x86_64` (`HOME=/tmp/xlings-trufflehog XLINGS_HOME=/tmp/xlings-trufflehog`) including `trufflehog --version`, `trufflehog /?` exit check, offline `trufflehog filesystem` clean and synthetic-secret scan, idempotent reinstall, and removal.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (tested via Lua hook unit mocks; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 3.100.1: initial `spec = "2"` packaging with flat `.tar.gz` direct extraction (POSIX `tar` + Windows `System32\tar.exe`) and full payload file verification.
