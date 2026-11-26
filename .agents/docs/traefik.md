# traefik

Traefik (`traefik`) is a modern HTTP reverse proxy and load balancer (`status = "stable"`).

- Upstream: https://github.com/traefik/traefik (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (GitHub Releases of `traefik/traefik`)
- GLOBAL:
  - `linux`: `https://github.com/traefik/traefik/releases/download/v${version}/traefik_v${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/traefik/traefik/releases/download/v${version}/traefik_v${version}_darwin_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/traefik/traefik/releases/download/v${version}/traefik_v${version}_windows_${arch_alias}.zip` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `traefik_v3.8.0_checksums.txt` from the `v3.8.0` release; all 6 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports not a dynamic executable — zero runtime dependencies (`xim:glibc` is not declared). On Windows (`amd64` `0x8664` and `arm64` `0xaa64`), PE32+ CUI `traefik.exe` imports only `kernel32.dll` (no `VCRUNTIME140.dll`).

## What the hooks do

- install: Every upstream archive is flat at root (`traefik` / `traefik.exe`, `CHANGELOG.md`, `LICENSE.md`). `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`payload.unpack{}` on Windows `.zip`; `tar -xzf` + `chmod +x` on POSIX `.tar.gz`), then asserts all 3 files via `payload.require(...)`.
- config: Registers `traefik` via `xvm.add("traefik", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `traefik` via `xvm.remove("traefik")`.
- System impact: none.

## Verification

- Static & isolation pytest suites, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect` / `materialize` verified locally.
- Isolated `xlings` install/verify/remove on Linux `x86_64` verified (`traefik version`, `traefik --help`, `tests/t/test_traefik.py`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (hooks tested via Lua unit mocks; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 3.8.0: initial packaging with flat-archive direct extraction and full payload verification (`traefik`/`traefik.exe`, `CHANGELOG.md`, `LICENSE.md`).
