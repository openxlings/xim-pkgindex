# kubeseal

Client-side CLI tool for Bitnami Sealed Secrets (`kubeseal`), `status = "stable"`.

- Upstream: https://github.com/bitnami/sealed-secrets (formerly `bitnami-labs/sealed-secrets`, Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream also publishes `linux-arm` and `linux-ppc64le` (omitted because `archs` targets `x86_64` and `aarch64`), and does not publish a `windows-arm64` build.

## Source

- Tier: official upstream GitHub release (`https://github.com/bitnami/sealed-secrets/releases`)
- GLOBAL: `kubeseal-${version}-{linux,darwin,windows}-${arch_alias}.tar.gz` (note Windows also ships `.tar.gz`, not `.zip`; every archive is flat at root containing `LICENSE`, `README.md`, and `kubeseal` / `kubeseal.exe`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `sealed-secrets_0.41.2_checksums.txt` on `v0.41.2` and verified locally against downloaded bytes for all 5 archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`).

## Linking

- `linux/x86_64` and `linux/aarch64`: statically linked Go ELF executables (`readelf -d`: no `.dynamic` section; `ldd`: not a dynamic executable). No `xim:glibc` or `xim:gcc-runtime` dependency.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`kubeseal.exe`) importing only `kernel32.dll` (no `xim:vcruntime` dependency).

## What the hooks do

- `installed`: checks `payload.present` for `kubeseal` or `kubeseal.exe`.
- `install`: extracts the flat `.tar.gz` directly into `pkginfo.install_dir()` (using `%SystemRoot%\System32\tar.exe` on Windows because `libs/payload.lua` only handles `.zip`, and system `tar -xzf` + `chmod +x` on POSIX; falls back to moving a pre-extracted binary from the download directory), then asserts `kubeseal` / `kubeseal.exe` via `payload.require`.
- `config`: registers `kubeseal` with `xvm.add("kubeseal", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `kubeseal` with `xvm.remove("kubeseal")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `HOME` & `XLINGS_HOME` (`/tmp/xlings-kubeseal`): `xlings config --add-xpkg`, `xlings search kubeseal`, `xlings install local:kubeseal@0.41.2 -y`, `kubeseal --version`, offline `kubeseal --cert` + `--recovery-unseal` round-trip, `kubeseal /?` non-blocking exit, `xlings list kubeseal`, idempotent reinstall, `xlings remove local:kubeseal@0.41.2 -y`, and `xlings config --remove-xpkg kubeseal`.
- Ran `pytest tests/k/test_kubeseal.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), full `pytest tests/ -m "static or isolation" -q`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only kubeseal`.
- Not run locally: `macosx` (`x86_64`, `aarch64`), `linux/aarch64`, and `windows/x86_64` native execution (Windows `.tar.gz` hook path verified via Lua unit test; CI validates `linux`, `macosx`, and `windows`).

## Revision log

- 2026-11-26 — added at `0.41.2`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
