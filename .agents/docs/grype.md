# grype

Grype (`grype`) is Anchore's vulnerability scanner for container images, filesystems, and SBOMs (`status = "stable"`).

- Upstream: https://github.com/anchore/grype (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream `v0.122.1` publishes no `windows_arm64` archive.

## Source

- Tier: upstream release (GitHub Releases of `anchore/grype`)
- GLOBAL:
  - `linux`: `https://github.com/anchore/grype/releases/download/v${version}/grype_${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/anchore/grype/releases/download/v${version}/grype_${version}_darwin_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/anchore/grype/releases/download/v${version}/grype_${version}_windows_amd64.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `grype_0.122.1_checksums.txt` from the `v0.122.1` release; all 5 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports not a dynamic executable — zero runtime dependencies (`xim:glibc` is not declared). On Windows `x86_64`, `objdump -p` shows `grype.exe` (PE32+ console) imports only `kernel32.dll`.

Note on Windows `/?` check: `grype /?` interprets `/?` as a scan target and initiates a vulnerability database check/download (which timed out in 3s offline); `windows-test.ps1` falls back to `grype --version` if `/?` exceeds 30s, and `grype --version` exits `0` immediately offline.

## What the hooks do

- install: Every upstream archive is flat at root (`grype` / `grype.exe`, `CHANGELOG.md`, `LICENSE`, `README.md`). To avoid leaking files from other flat archives in shared `runtimedir`, `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`payload.unpack{}` on Windows `.zip`; `tar -xzf` + `chmod +x` on POSIX `.tar.gz`), then asserts all 4 files via `payload.require(...)`.
- config: Registers `grype` via `xvm.add("grype", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `grype` via `xvm.remove("grype")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/g/test_grype.py`, repo-wide `static or isolation`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only grype` passed locally.
- Isolated/local `xlings` install/verify/remove on Linux `x86_64` passed (`grype --version`, `grype version -o json`, `grype config`, `tests/g/test_grype.py -m "index or lifecycle or verify"`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime execution (tested via Lua hook unit mocks; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 0.122.1: initial packaging with flat-archive direct extraction and full payload file verification (`grype`/`grype.exe`, `CHANGELOG.md`, `LICENSE`, `README.md`).
