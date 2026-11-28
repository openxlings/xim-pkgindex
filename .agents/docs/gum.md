# gum

A tool for glamorous shell scripts (`charmbracelet/gum`), providing the `gum` command (`status = "stable"`).

- Upstream: https://github.com/charmbracelet/gum (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream release `v2.0.2` publishes no Windows ARM64 archive.

## Source

- Tier: upstream GitHub release (`charmbracelet/gum`)
- GLOBAL: `https://github.com/charmbracelet/gum/releases/download/v${version}/gum_${version}_<OS>_<arch>.{tar.gz,zip}`
- CN: none yet (`ci = { mirror = true }` declared for `xlings-res` mirroring)
- Checksums: all five `v2.0.2` archives verified with `sha256sum` against upstream `checksums.txt` and GitHub Release asset digests
- Auto-update: yes (`extensions.autoupdate`, `GLOBAL` required across all 5 platform/arch targets)

## Linking

- `linux/x86_64`: statically linked Go ELF64 x86-64 executable (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Declares no `deps`.
- `linux/aarch64`: statically linked Go ELF64 ARM aarch64 executable (`readelf -d`: no dynamic section). Declares no `deps`.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: `gum.exe` PE32+ console x86-64 executable importing `kernel32.dll` only (no `VCRUNTIME140.dll` / `MSVCP140.dll` dependency). Declares no `xim:vcruntime`.

## What the hooks do

- `installed`: checks `gum` (or `gum.exe`) and `LICENSE` via `payload.present` (with `os.isfile` fallback when `payload` stub is loaded without `libs/`).
- `install`: every upstream archive packs a single top-level directory `gum_<version>_<OS>_<arch>/`. Moves the extracted directory (or extracts with `--strip-components=1`) into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem, strip = 1 }` (with local fallback), ensures `+x` on POSIX, and verifies `gum`/`gum.exe` and `LICENSE`.
- `config`: registers `gum` with `xvm.add("gum", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `gum` via `xvm.remove("gum")`.
- System impact: none.

## Verification

- Verified locally on Linux `x86_64` in isolated `HOME` / `XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search gum`, `xlings install local:gum -y`, `gum --version`, `gum --help`, `gum style "hello"`, `gum /? </dev/null` (exits immediately with code 80, does not block on TTY), idempotent reinstall, `xlings remove gum -y`, `pytest tests/g/test_gum.py`, repo-wide static/isolation pytest checks, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only gum`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (covered by archive checksum/binary linkage inspection, Lua sandbox hook tests, and GitHub Actions CI).

## Revision log

- 2026-11-26 — added at `2.0.2`.
