# evans

More expressive universal gRPC client (`evans`), `status = "stable"`.

- Upstream: https://github.com/ktr0731/evans (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `386` and `arm` builds, which are omitted as xlings targets `x86_64` and `aarch64`.

## Source

- Tier: upstream release (`https://github.com/ktr0731/evans/releases`)
- GLOBAL: `evans_{linux,darwin,windows}_{amd64,arm64}.tar.gz` (note Windows ships `.tar.gz`, not `.zip`; every archive is flat at root containing only the single `evans` / `evans.exe` binary)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `checksums.txt` for `v0.10.11` and verified locally across all six archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}`).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`, `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- Windows (`x86_64`, `aarch64`): PE32+ console executables (`evans.exe`) importing only `kernel32.dll` (no VCRUNTIME or MinGW DLL dependencies).

## What the hooks do

- `installed`: checks `payload.present` for `evans` or `evans.exe`.
- `install`: extracts the flat `.tar.gz` directly into `pkginfo.install_dir()` (using `%SystemRoot%\System32\tar.exe` on Windows because `libs/payload.lua` only dispatches `.zip`, and system `tar` on POSIX; falls back to moving a pre-extracted binary from the cache directory), `chmod +x` on POSIX, and asserts `evans` / `evans.exe` via `payload.require`.
- `config`: registers `evans` via `xvm.add("evans", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `evans` via `xvm.remove("evans")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME` & `HOME` (`/tmp/xlings-evans`): `xlings config --add-xpkg`, `xlings search evans`, `xlings install local:evans@0.10.11 -y`, `evans --version`, `evans cli desc` and `evans cli list` against a local `.proto`, `evans /?` exiting cleanly without blocking, `xlings list evans`, idempotent reinstall, `xlings remove local:evans@0.10.11 -y`, and `xlings config --remove-xpkg evans`.
- Ran `pytest tests/e/test_evans.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repo checks (`test_docs.py`, `test_agent_files.py`, `test_shortcut.py`, `test_platform_version_parity.py`, `test_no_compiler_runtime_in_payloads.py`, `test_xpkg_spec.py`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only evans`.
- Not run locally: `macosx` (`x86_64`, `aarch64`), `linux` (`aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (Windows `.tar.gz` hook was exercised via Lua unit tests, and CI validates Linux, macOS, and Windows).

## Revision log

- 2026-11-26 — added at 0.10.11: initial `spec = "2"` recipe covering Linux, macOS, and Windows (`x86_64`, `aarch64`).
