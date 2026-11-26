# dive

A tool for exploring each layer in a docker image; provides `dive`, status `stable`.

- Upstream: https://github.com/wagoodman/dive (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also builds `linux_ppc64le`, which is outside xlings' `archs` matrix.

## Source

- Tier: upstream release
- GLOBAL: `https://github.com/wagoodman/dive/releases/download/v${version}/dive_${version}_<os>_<arch_alias>.<ext>` (`linux`/`darwin` `.tar.gz`, `windows` `.zip`)
- CN: none yet (declares `ci = { mirror = true }`)
- Checksums: taken from upstream `dive_0.13.1_checksums.txt` and verified with `sha256sum` across all six downloaded release archives (100% match).
- Auto-update: yes (`extensions.autoupdate` with `${tag}` and `${version}` across all 6 platform/arch targets).

## Linking

- Linux `x86_64` and `aarch64`: static Go ELF executables (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Declares no `xim:glibc` or other runtime deps.
- macOS `x86_64` and `aarch64`: official Mach-O 64-bit executables.
- Windows `x86_64` and `aarch64`: PE32+ console executables (`0x8664` / `0xaa64`), importing `kernel32.dll` only; no VCRUNTIME or external DLL deps.

## What the hooks do

- install: upstream archives are flat at root (`dive` / `dive.exe`, `CHANGELOG.md`, `LICENSE`, `README.md`). Extracts directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows) and verifies the binary with `payload.require`.
- config: registers `dive` via `xvm.add("dive", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `dive` via `xvm.remove("dive")`.
- System impact: none.

## Verification

- Static & isolation: `pytest tests/d/test_dive.py -m "static or isolation" -v`, repo-wide static checks, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect` / `materialize`.
- Linux `x86_64` (isolated `XLINGS_HOME` & `HOME`): `xlings install local:dive -y`, `dive --version` (`dive 0.13.1`), `dive --help`, `pytest tests/d/test_dive.py -m "index or lifecycle or verify" -v`, `xlings remove dive -y`, and clean removal check.
- Not run locally: `linux` `aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) live installs (x86_64 Linux host); delegated to GitHub Actions CI (`linux/aarch64`, `macosx/aarch64`, `windows/x86_64`; `macosx/x86_64` and `windows/aarch64` are resource-verified).

## Revision log

- 2026-11-26 — added at `0.13.1`: flat-root archive extraction into `install_dir` for all 6 platform/arch targets; verified static Go ELFs on Linux and `kernel32.dll`-only PEs on Windows.
