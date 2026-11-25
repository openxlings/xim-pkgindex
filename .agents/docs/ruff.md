# ruff

An extremely fast Python linter and code formatter, written in Rust. Provides the `ruff` CLI (`status = "stable"`).

- Upstream: https://github.com/astral-sh/ruff (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`) — full 3-platform, 2-architecture matrix from official upstream releases.

## Source

- Tier: upstream release (`astral-sh/ruff`)
- GLOBAL: `https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-<target>.<ext>`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: taken from upstream `.sha256` / `sha256.sum` assets and verified against locally downloaded bytes for all 6 archives of `0.17.6`.
- Auto-update: yes (`extensions.autoupdate`, matching all 6 targets with `${tag}`).

## Linking

- `linux/x86_64`: `ruff-x86_64-unknown-linux-musl.tar.gz` — `ELF 64-bit LSB pie executable, x86-64, static-pie linked, stripped`, no `.interp`, zero `DT_NEEDED`.
- `linux/aarch64`: `ruff-aarch64-unknown-linux-musl.tar.gz` — `ELF 64-bit LSB executable, ARM aarch64, statically linked, stripped`, no `.interp`, no dynamic section, zero `DT_NEEDED`.
- `windows/x86_64` & `windows/aarch64`: PE32+ executables importing only Windows OS system DLLs (`kernel32.dll`, `bcryptprimitives.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `shell32.dll`, `combase.dll`, `ntdll.dll`, `userenv.dll`, `advapi32.dll`); no `VCRUNTIME140.dll`.
- Declares no `deps` on any platform.

## What the hooks do

- `install`: Linux/macOS tarballs enclose `ruff` inside `ruff-<target>/` (`payload.unpack{ extracted = stem }`); Windows zips are flat archives containing `ruff.exe` directly at the root (`payload.unpack{ extracted = nil }`, extracted cleanly via `System32\tar.exe` into `pkginfo.install_dir()`). Verifies `ruff` / `ruff.exe` via `payload.require`.
- `config`: registers `ruff` via `xvm.add("ruff", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `ruff` via `xvm.remove("ruff")`.
- System impact: none; self-contained under `pkginfo.install_dir()` and subos xvm shims.

## Verification

- Verified locally on Linux `x86_64`: static/isolation tests, repo-wide checks, lints, `xlings install local:ruff -y`, `ruff --version`, `ruff check` / `ruff format`, `dep-closure-check.sh`, `verify` & `index` tests, and `xlings remove local:ruff -y`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), `windows` (`x86_64`/`aarch64`) runtime installs (deferred to CI).

## Revision log

- 2026-11-25 — added at 0.17.6: initial spec-2 recipe covering Linux musl, macOS, and Windows across `x86_64` and `aarch64`.
