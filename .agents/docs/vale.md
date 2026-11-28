# vale

A markup-aware linter for prose built with speed and extensibility in mind. Provides the `vale` CLI command; status `stable`.

- Upstream: https://github.com/vale-cli/vale (`MIT`; `errata-ai/vale` redirects here)
- Homepage / Docs: https://vale.sh / https://docs.vale.sh
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `vale_<ver>_wasm.tar.gz`, which is outside `package.archs`.

## Source

- Tier: upstream release (`vale-cli/vale` GitHub Releases)
- GLOBAL: `https://github.com/vale-cli/vale/releases/download/${tag}/vale_${version}_<OS>_<arch>.(tar.gz|zip)` (`Linux`/`macOS`/`Windows`, `64-bit`/`arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against upstream `vale_3.28.1_checksums.txt` and confirmed with `sha256sum -c` across all six downloaded archives (`Linux`/`macOS`/`Windows` x `64-bit`/`arm64`).
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}` for all six platform/arch targets).

## Linking

- Linux (`x86_64` and `aarch64`): statically linked Go ELF executables (`readelf -d` shows no dynamic section; `readelf -l` shows no `INTERP` or `DYNAMIC` segment; `ldd` on `x86_64` reports not a dynamic executable). Zero `DT_NEEDED` entries, so no `xim:glibc` runtime dependency is declared.
- Windows (`x86_64` and `aarch64`): PE32+ executables with zero delay-load imports and importing only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`), so no `xim:vcruntime` runtime dependency is needed.

## CLI behavior

- `vale --version` exits 0 (`vale version 3.28.1`).
- `vale /?` exits immediately with code 2 (`E100 [.vale.ini not found] Runtime error`), compatible with Windows CI's bounded `/?` probe.

## What the hooks do

- `install`: extracts the flat upstream archive directly into `pkginfo.install_dir()` (using `shell.exec({"tar", "-xzf", ...})` + `chmod +x` on POSIX, or `xim.pkgindex.payload.unpack{}` via `System32\tar.exe` on Windows, with pre-extracted binary fallback), then asserts `vale` / `vale.exe` with `payload.require`.
- `config`: registers `vale` via `xvm.add("vale", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `vale` via `xvm.remove("vale")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/v/test_vale.py` and repo-wide `tests/`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect --only vale` run on Linux `x86_64`.
- End-to-end isolated `XLINGS_HOME` & `HOME` lifecycle (`xlings config --add-xpkg`, `xlings search vale`, `xlings install local:vale@3.28.1 -y`, `vale --version`, custom style Markdown linting, `pytest -m "index or verify"`, `xlings remove local:vale@3.28.1 -y`, `xlings config --remove-xpkg vale`) verified on Linux `x86_64`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64`, `windows/aarch64` runtime installs (covered by archive layout, checksum, ELF/PE inspection, Lua sandbox hook tests, and GitHub Actions CI).

## Revision log

- 2026-11-26 — added at `3.28.1`: verified all six upstream release archives, checksums, ELF/PE linkage, `/?` exit behavior, and Linux `x86_64` lifecycle.
