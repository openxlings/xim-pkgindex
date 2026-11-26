# ko

Build and deploy Go applications (`ko`), `status = "stable"`.

- Upstream: https://github.com/ko-build/ko (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `i386`, `mips64le`, `ppc64le`, `riscv64`, and `s390x` archives, which are omitted as outside xlings' `archs` matrix.

## Source

- Tier: upstream release (`https://github.com/ko-build/ko/releases`)
- GLOBAL: `ko_{version}_{Linux,Darwin,Windows}_{x86_64,arm64}.tar.gz` (Windows ships `.tar.gz`, not `.zip`; every archive is flat at root containing `ko` / `ko.exe`, `LICENSE`, and `README.md`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `checksums.txt` for `v0.19.1` and verified locally across all six downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}` across all six platform/arch targets).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): Mach-O 64-bit `x86_64` and `arm64` executables.
- Windows (`x86_64`, `aarch64`): PE32+ console (`CUI`) executables importing only `kernel32.dll` (no VCRUNTIME or external DLL deps). `ko version`, `ko --help`, and `ko /?` exit immediately offline without blocking.

## What the hooks do

- `installed`: checks `payload.present` for `{ "ko" | "ko.exe", "LICENSE", "README.md" }`.
- `install`: extracts the flat `.tar.gz` directly into `pkginfo.install_dir()` (using `%SystemRoot%\System32\tar.exe` via `winpath.native` on Windows because `libs/payload.lua` only dispatches `.zip`, and `tar -xzf` + `chmod +x` on POSIX; falls back to moving pre-extracted files from the cache directory), and asserts all three payload files via `payload.require`.
- `config`: registers `ko` via `xvm.add("ko", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `ko` via `xvm.remove("ko")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation: `pytest tests/k/test_ko.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only ko`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-ko` & `XLINGS_HOME=/tmp/xlings-ko`): `xlings config --add-xpkg`, `xlings search ko`, `xlings install local:ko@0.19.1 -y`, `ko version`, `ko --help`, `ko /?`, `xlings list ko`, idempotent reinstall, `xlings remove local:ko@0.19.1 -y`, `xlings config --remove-xpkg ko`, and `pytest tests/k/test_ko.py`.
- Not run locally: `linux` `aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (x86_64 Linux host); Windows `.tar.gz` extraction was exercised via Lua unit tests, and GitHub Actions CI validates Linux, macOS, and Windows.

## Revision log

- 2026-11-26 — added at `0.19.1`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`, `aarch64`).
