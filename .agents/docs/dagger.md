# dagger

Dagger (`dagger`) is an automation engine to build, test, and ship any codebase in containers, running locally, in CI, or in the cloud (`status = "stable"`).

- Upstream: https://github.com/dagger/dagger (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `linux_armv7`, which is outside xlings' `archs` matrix.

## Source

- Tier: upstream release (GitHub Releases of `dagger/dagger`)
- GLOBAL:
  - `linux`: `https://github.com/dagger/dagger/releases/download/v${version}/dagger_v${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/dagger/dagger/releases/download/v${version}/dagger_v${version}_darwin_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/dagger/dagger/releases/download/v${version}/dagger_v${version}_windows_${arch_alias}.zip` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `checksums.txt` from the `v0.21.12` release; all 6 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports `not a dynamic executable` — zero runtime dependencies (`xim:glibc` is not declared). On Windows (`x86_64` and `aarch64`), PE32+ console binaries (`0x8664`, `0xaa64`) import only `kernel32.dll` (no VCRUNTIME dependency).

## Offline CLI behavior

- `dagger version` exits `0` in ~18ms (`dagger v0.21.12 (image://registry.dagger.io/engine:v0.21.12) linux/amd64`) without connecting to an engine.
- `dagger --help` exits `0` immediately; `dagger completion bash` exits `0` immediately.
- `dagger "/?"` exits `1` in ~1s (`Error: unknown command or file "/?" for "dagger"`) without blocking to start an engine. (Note: running under `timeout` without `--foreground` in a PTY places the child in a background process group, which can trigger `SIGTTOU`; under normal pipes/foreground execution it completes immediately.)

## What the hooks do

- install: Every upstream archive is flat at root (`dagger` / `dagger.exe`, `LICENSE`). To avoid leaking files from other flat archives in shared `runtimedir`, `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`payload.unpack{}` on Windows `.zip`; `tar -xzf` + `chmod +x` on POSIX `.tar.gz`), then asserts the executable via `payload.require({ exe })`.
- config: Registers `dagger` via `xvm.add("dagger", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `dagger` via `xvm.remove("dagger")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/d/test_dagger.py` and repo-wide static/isolation), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only dagger` verified locally.
- Isolated `xlings` (`HOME=/tmp/xlings-dagger XLINGS_HOME=/tmp/xlings-dagger`) lifecycle (`add-xpkg`, `search`, `install`, `dagger version`, `dagger --help`, `dagger completion bash`, `list`, idempotent re-install, `remove`, `list`, `remove-xpkg`) and pytest `index`/`lifecycle`/`verify` on Linux `x86_64` verified locally.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (tested via Lua hook unit mocks; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 0.21.12: initial packaging across `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`).
