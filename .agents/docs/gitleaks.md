# gitleaks

Gitleaks (`gitleaks`) is a SAST tool for detecting and preventing hardcoded secrets like passwords, API keys, and tokens in git repositories (`status = "stable"`).

- Upstream: https://github.com/gitleaks/gitleaks (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (GitHub Releases of `gitleaks/gitleaks`)
- GLOBAL:
  - `linux`: `https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_linux_${arch_alias}.tar.gz` (`x64` / `arm64`)
  - `macosx`: `https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_darwin_${arch_alias}.tar.gz` (`x64` / `arm64`)
  - `windows`: `https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_windows_${arch_alias}.zip` (`x64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `gitleaks_8.30.1_checksums.txt` from the `v8.30.1` release; all 6 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports not a dynamic executable — zero runtime dependencies (`xim:glibc` is not declared). On Windows (`x86_64` and `aarch64`), PE32+ console binaries import only `kernel32.dll`.

## What the hooks do

- install: Every upstream archive is flat at root (`gitleaks` / `gitleaks.exe`, `LICENSE`, `README.md`). To avoid leaking files from other flat archives in shared `runtimedir`, `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`payload.unpack{}` on Windows `.zip`; `tar -xzf` + `chmod +x` on POSIX `.tar.gz`), then asserts all 3 files via `payload.require(...)`.
- config: Registers `gitleaks` via `xvm.add("gitleaks", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `gitleaks` via `xvm.remove("gitleaks")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/g/test_gitleaks.py`, repo-wide `static or isolation`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect/materialize` passed locally.
- Isolated/local `xlings` install/verify/remove on Linux `x86_64` passed (`gitleaks version`, `gitleaks dir` offline clean & leak detection, `tests/g/test_gitleaks.py -m "index or verify"`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (tested via Lua hook unit mocks; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 8.30.1: initial packaging with flat-archive direct extraction and full payload file verification (`gitleaks`/`gitleaks.exe`, `LICENSE`, `README.md`).
