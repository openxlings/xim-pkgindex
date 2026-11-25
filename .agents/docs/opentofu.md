# opentofu

OpenTofu is an open-source infrastructure-as-code tool providing the `tofu` CLI (`status = "stable"`).

- Upstream: https://github.com/opentofu/opentofu (MPL-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). 32-bit (`386`/`arm`) and BSD/Solaris upstream builds are omitted.

## Source

- Tier: upstream GitHub release (`opentofu/opentofu`)
- GLOBAL: `https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_${os}_${arch_alias}.${ext}` (with `darwin` for `macosx`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: all six SHA256 digests match upstream `tofu_1.13.10_SHA256SUMS` and `sha256sum` of the downloaded archives
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`)

## Linking

Static Go binaries (`CGO_ENABLED=0` style): `readelf -d` on `linux_amd64` and `linux_arm64` reports no dynamic section (`ldd`: not a dynamic executable). Windows `amd64` and `arm64` PE32+ binaries import only `kernel32.dll`. No runtime dependencies declared.

## What the hooks do

- install: all upstream archives are flat (`tofu[.exe]`, `LICENSE`, `README.md`, `CHANGELOG.md`). Extracts directly from `install_file` into `install_dir` (`payload.unpack{}` on Windows `.zip` via `System32\tar.exe`; `tar -xzf` on POSIX `.tar.gz`), sets `+x` on POSIX, and checks `tofu[.exe]` + `LICENSE`.
- config: registers `tofu` with `bindir = pkginfo.install_dir()` and `opentofu` with `type = "group"` (since binary name != package name).
- uninstall: removes both `tofu` and `opentofu` from xvm.
- System impact: none.

## Verification

- Static + isolation pytest suites (`tests/o/test_opentofu.py`, repo-wide static checks, `lint_exec_quoting.sh`, `.github/scripts/check-*.sh`).
- Isolated `xlings install` / `tofu version` / offline `tofu init` + `validate` + `apply` / `xlings remove` on `linux` `x86_64`.
- `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) not executed locally; archives and hashes verified.

## Revision log

- 2026-11-25 — added at 1.13.10: flat archive extraction and `tofu` + `opentofu` (`type = "group"`) registration.
