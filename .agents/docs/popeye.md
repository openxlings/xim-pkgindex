# popeye

Kubernetes cluster resource sanitizer (`popeye`), `status = "stable"`.

- Upstream: https://github.com/derailed/popeye (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes FreeBSD, ppc64le, s390x, and distro packages (`.apk`, `.deb`, `.rpm`), which are omitted as outside xlings' `archs` matrix.

## Source

- Tier: upstream release (`https://github.com/derailed/popeye/releases`)
- GLOBAL: `popeye_{linux,darwin,windows}_{amd64,arm64}.tar.gz` (note Windows ships `.tar.gz`, not `.zip`; every archive is flat at root containing `popeye` / `popeye.exe`, `LICENSE`, and `README.md`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `checksums.sha256` for `v0.22.1` and verified locally across all six downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` across all six platform/arch targets).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`; `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- macOS (`x86_64`, `aarch64`): Mach-O 64-bit `x86_64` and `arm64` executables.
- Windows (`x86_64`, `aarch64`): PE32+ console (`CUI`) executables importing only `kernel32.dll` (no VCRUNTIME or external DLL deps). `popeye version`, `popeye --help`, and `popeye /?` exit `0` immediately offline without launching an interactive TUI or blocking on Kubernetes API discovery.

## What the hooks do

- `installed`: checks `payload.present` for `{ "popeye" | "popeye.exe", "LICENSE", "README.md" }`.
- `install`: extracts the flat `.tar.gz` directly into `pkginfo.install_dir()` (using `%SystemRoot%\System32\tar.exe` via `winpath.native` on Windows because `libs/payload.lua` only dispatches `.zip`, and `tar -xzf` + `chmod +x` on POSIX; falls back to moving pre-extracted files from the cache directory), and asserts all three payload files via `payload.require`.
- `config`: registers `popeye` via `xvm.add("popeye", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `popeye` via `xvm.remove("popeye")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Static & isolation: `pytest tests/p/test_popeye.py -m "static or isolation" -v`, repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only popeye`.
- Linux `x86_64` (isolated `HOME=/tmp/xlings-popeye` & `XLINGS_HOME=/tmp/xlings-popeye`): `xlings config --add-xpkg`, `xlings search popeye`, `xlings install local:popeye@0.22.1 -y`, `popeye version`, `popeye --help`, `popeye info`, `popeye /?`, `xlings list popeye`, idempotent reinstall, `xlings remove local:popeye@0.22.1 -y`, `xlings config --remove-xpkg popeye`, and `pytest tests/p/test_popeye.py`.
- Not run locally: `linux` `aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (x86_64 Linux host); Windows `.tar.gz` extraction was exercised via Lua unit tests, and GitHub Actions CI validates Linux, macOS, and Windows.

## Revision log

- 2026-11-26 — added at `0.22.1`: initial `spec = "2"` recipe covering Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`, `aarch64`).
