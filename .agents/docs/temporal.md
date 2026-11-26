# temporal

Temporal CLI (`temporal`) is the official command-line interface for running a local Temporal Server and managing, monitoring, and debugging Temporal Workflows, Activities, Namespaces, and Schedules (`status = "stable"`).

- Upstream: https://github.com/temporalio/cli (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (GitHub Releases of `temporalio/cli`)
- GLOBAL:
  - `linux`: `https://github.com/temporalio/cli/releases/download/v${version}/temporal_cli_${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://github.com/temporalio/cli/releases/download/v${version}/temporal_cli_${version}_darwin_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://github.com/temporalio/cli/releases/download/v${version}/temporal_cli_${version}_windows_${arch_alias}.zip` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `checksums.txt` from the `v1.10.1` release; all 6 downloaded archives matched their published SHA-256 digests.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports `not a dynamic executable` — zero runtime dependencies (`xim:glibc` is not declared). On Windows (`x86_64` and `aarch64`), PE32+ console binaries (`0x8664`, `0xaa64`) import only `kernel32.dll` (no VCRUNTIME dependency).

## Offline CLI behavior

- `temporal --version` exits `0` immediately (`temporal version 1.10.1 (Server 1.32.2, UI 2.56.4)`).
- `temporal --help` exits `0` immediately; `temporal completion bash` exits `0` immediately.
- `temporal /?` prints usage and `Error: unknown command`, exiting `1` immediately without blocking (`timeout --foreground -k 2 5 ./temporal /? </dev/null`).

## What the hooks do

- install: Every upstream archive is flat at root (`temporal` / `temporal.exe`, `LICENSE`). To avoid leaking unrelated files from the shared download directory, `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`payload.unpack{}` on Windows `.zip`; `tar -xzf` + `chmod +x` on POSIX `.tar.gz`), then asserts the executable via `payload.require({ exe })`.
- config: Registers `temporal` via `xvm.add("temporal", { bindir = pkginfo.install_dir() })`.
- uninstall: Removes `temporal` via `xvm.remove("temporal")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/t/test_temporal.py` and repo-wide static/isolation), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only temporal` verified locally.
- Isolated `xlings` (`HOME=/tmp/xlings-temporal XLINGS_HOME=/tmp/xlings-temporal`) lifecycle (`add-xpkg`, `search`, `install`, `temporal --version`, `temporal --help`, `temporal completion bash`, `list`, idempotent re-install, `remove`, `list`, `remove-xpkg`) and pytest `index`/`lifecycle`/`verify` on Linux `x86_64` verified locally.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (tested via Lua hook unit mocks; real execution delegated to CI).

## Revision log

- 2026-11-26 — added at 1.10.1: initial packaging across `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`).
