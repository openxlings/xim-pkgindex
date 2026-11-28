# miller

Miller (`mlr`) is a command-line tool like `awk`, `sed`, `cut`, `join`, and `sort` for name-indexed data formats such as CSV, TSV, and tabular JSON; status is `stable`.

- Upstream: https://github.com/johnkerl/miller (BSD-2-Clause)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `linux-386`/`armv6`/`armv7`/`ppc64le`/`riscv64`/`s390x`, `windows-386`, `freebsd-*`, and `aix-ppc64`, which are outside `archs`.

## Source

- Tier: upstream repository release (`https://github.com/johnkerl/miller/releases`)
- GLOBAL:
  - `linux`: `https://github.com/johnkerl/miller/releases/download/v${version}/miller-${version}-linux-${arch_alias}.tar.gz`
  - `macosx`: `https://github.com/johnkerl/miller/releases/download/v${version}/miller-${version}-darwin-${arch_alias}.tar.gz`
  - `windows`: `https://github.com/johnkerl/miller/releases/download/v${version}/miller-${version}-windows-${arch_alias}.zip`
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge)
- Checksums: all 6 SHA256s taken from upstream `miller-6.23.0-checksums.txt` and verified against downloaded archives with `sha256sum`.
- Auto-update: yes (`extensions.autoupdate`)

## Linking

- Linux `x86_64` and `aarch64`: statically linked Go ELF executables (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Declares no runtime dependencies (`xim:glibc` not required).
- Windows `x86_64` and `aarch64`: PE32+ executables importing only `kernel32.dll`. Declares no `xim:vcruntime` dependency.

## What the hooks do

- `install`: unpacks the top-level `miller-<version>-<os>-<arch>/` directory into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem, strip = 1 }`, runs `chmod +x` on POSIX `mlr`, and asserts `mlr` / `mlr.exe` and `LICENSE.txt` via `payload.require`.
- `config`: registers `miller` as `type = "group"` and `mlr` with `bindir = pkginfo.install_dir()` in xvm.
- `uninstall`: removes both `mlr` and `miller` from xvm.
- System impact: none; only writes inside `pkginfo.install_dir()` and registers xvm entries.

## Verification

- Verified `6.23.0` on `linux/x86_64` in an isolated `XLINGS_HOME`: `xlings install local:miller -y`, `mlr --version`, `mlr --icsv --ojson cat`, `xlings remove miller -y`, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64`, and `windows/aarch64` were not run locally; their archive layouts, SHA256s, Linux ARM64 ELF (`readelf -d`, `ldd`), and Windows AMD64/ARM64 PE imports were inspected locally, and native CI runners cover `linux/x86_64`, `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64` (`macosx/x86_64` and `windows/aarch64` are resource-only in CI).

## Revision log

- 2026-11-26 — added at 6.23.0: initial xpkg (`mlr` binary under `miller` group placeholder, static Go / `kernel32.dll`-only binaries across Linux, macOS, and Windows `x86_64`/`aarch64`).
