# lazysql

A cross-platform TUI database management tool written in Go. Provides the `lazysql` CLI/TUI command; status `stable`.

- Upstream: https://github.com/jorgerojas26/lazysql (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (`jorgerojas26/lazysql` GitHub Releases)
- GLOBAL: `https://github.com/jorgerojas26/lazysql/releases/download/${tag}/lazysql_<os>_<arch>.(tar.gz|zip)` (unversioned asset filenames under each versioned release tag)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against upstream `lazysql_0.7.0_checksums.txt` and confirmed with `sha256sum -c` across all six downloaded archives (`Linux`/`Darwin`/`Windows` x `x86_64`/`arm64`).
- Auto-update: yes (`extensions.autoupdate` using `${tag}` for all six platform/arch targets).

## Linking

- Linux (`x86_64` and `arm64`): statically linked Go ELF executables (`readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). Zero `DT_NEEDED` entries, so no `xim:glibc` runtime dependency is declared.
- Windows (`x86_64` and `arm64`): PE32+ console executables importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`), so no `xim:vcruntime` runtime dependency is needed.

## What the hooks do

- `install`: extracts the flat upstream archive directly into `pkginfo.install_dir()` (using `tar -xzf` on POSIX + `chmod +x`, or `xim.pkgindex.payload.unpack{}` via `System32\tar.exe` on Windows, with pre-extracted binary fallback), then asserts `lazysql` / `lazysql.exe` with `payload.require`.
- `config`: registers `lazysql` via `xvm.add("lazysql", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `lazysql` via `xvm.remove("lazysql")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/l/test_lazysql.py`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only lazysql` run on Linux `x86_64`.
- End-to-end isolated `HOME` & `XLINGS_HOME` lifecycle (`xlings install local:lazysql -y`, `lazysql --version`, `lazysql --help`, `lazysql /? </dev/null`, `pytest -m "index or verify"`, `xlings remove lazysql -y`) verified on Linux `x86_64`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64`, `windows/aarch64` (covered by CI and verified via archive layout, checksum, ELF/PE inspection).

## Revision log

- 2026-11-26 — added at `0.7.0`: verified all six upstream release archives, checksums, ELF/PE linkage, and Linux `x86_64` lifecycle.
