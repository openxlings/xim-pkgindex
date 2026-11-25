# trivy

Trivy (`trivy`) is Aqua Security's all-in-one security scanner for containers, filesystems, git repositories, Kubernetes, IaC misconfigurations, secrets, and SBOMs (`status = "stable"`).

- Upstream: https://github.com/aquasecurity/trivy (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream `v0.76.2` publishes no `windows-ARM64` archive.

## Source

- Tier: upstream release (GitHub Releases of `aquasecurity/trivy`)
- GLOBAL:
  - `linux`: `https://github.com/aquasecurity/trivy/releases/download/v${version}/trivy_${version}_Linux-${arch_alias}.tar.gz` (`64bit` / `ARM64`)
  - `macosx`: `https://github.com/aquasecurity/trivy/releases/download/v${version}/trivy_${version}_macOS-${arch_alias}.tar.gz` (`64bit` / `ARM64`)
  - `windows`: `https://github.com/aquasecurity/trivy/releases/download/v${version}/trivy_${version}_windows-64bit.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `trivy_0.76.2_checksums.txt` from the `v0.76.2` release; all 5 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports `not a dynamic executable` — zero runtime dependencies (`xim:glibc` is not declared). On Windows x86-64, `objdump -p` shows `trivy.exe` (PE32+ console) imports only `kernel32.dll`.

## What the hooks do

- install: Every upstream archive is flat at root (`trivy` / `trivy.exe`, `LICENSE`, `README.md`, `contrib/*.tpl`). To avoid leaking files from other flat archives in shared `runtimedir`, `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`payload.unpack{}` on Windows `.zip`; `tar -xzf` + `chmod +x` on POSIX `.tar.gz`), then asserts all 8 files via `payload.require(...)`.
- config: Registers `trivy` via `xvm.add("trivy", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `trivy` via `xvm.remove("trivy")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/t/test_trivy.py`, `test_shortcut.py`, `test_platform_version_parity.py`, `test_no_compiler_runtime_in_payloads.py`, `test_xpkg_spec.py`), `tools/lint_exec_quoting.sh`, and `.github/scripts/check-*.sh` passed locally.
- Isolated/local `xlings` install/verify/remove on Linux `x86_64` passed (`trivy --version`, `trivy config` offline Dockerfile scan, `tests/t/test_trivy.py -m verify`, `tests/t/test_trivy.py -m index`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime execution (tested via Lua hook unit mocks; real execution delegated to CI).

## Revision log

- 2026-11-25 — added at 0.76.2: initial packaging with flat-archive direct extraction and full payload file verification (`contrib/*.tpl`).
