# syft

Syft (`syft`) is Anchore's CLI tool and Go library for generating a Software Bill of Materials (SBOM) from container images and filesystems (`status = "stable"`).

- Upstream: https://github.com/anchore/syft (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (GitHub Releases of `anchore/syft`)
- GLOBAL:
  - `linux`: `https://github.com/anchore/syft/releases/download/v${version}/syft_${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/anchore/syft/releases/download/v${version}/syft_${version}_darwin_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/anchore/syft/releases/download/v${version}/syft_${version}_windows_${arch_alias}.zip` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `syft_1.57.2_checksums.txt` from the `v1.57.2` release; all 6 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports not a dynamic executable — zero runtime dependencies (`xim:glibc` is not declared). On Windows (`x86_64` and `aarch64`), PE32+ console binaries import only `kernel32.dll`.

## What the hooks do

- install: Every upstream archive is flat at root (`syft` / `syft.exe`, `CHANGELOG.md`, `LICENSE`, `README.md`). To avoid leaking files from other flat archives in shared `runtimedir`, `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`payload.unpack{}` on Windows `.zip`; `tar -xzf` + `chmod +x` on POSIX `.tar.gz`), then asserts all 4 files via `payload.require(...)`.
- config: Registers `syft` via `xvm.add("syft", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `syft` via `xvm.remove("syft")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/s/test_syft.py`, repo-wide `static or isolation`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect --only syft` passed locally.
- Isolated `xlings` install/verify/remove on Linux `x86_64` passed (`syft version`, `syft dir:` offline SBOM generation for `requirements.txt`, `tests/s/test_syft.py -m "index or lifecycle or verify"`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (tested via Lua hook unit mocks; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 1.57.2: initial packaging with flat-archive direct extraction and full payload file verification (`syft`/`syft.exe`, `CHANGELOG.md`, `LICENSE`, `README.md`).
