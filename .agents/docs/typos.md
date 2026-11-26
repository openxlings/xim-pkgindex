# typos

Source code spell checker written in Rust (`crate-ci/typos`). Provides the `typos` CLI (`status = "stable"`).

- Upstream: https://github.com/crate-ci/typos (MIT OR Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`).
  `windows/aarch64` is omitted: upstream's `typos-v1.52.2-aarch64-pc-windows-msvc.zip` PE imports `VCRUNTIME140.dll` and `api-ms-win-crt-*-l1-1-0.dll`, while `xim:vcruntime` currently ships `x86_64` DLLs only.

## Source

- Tier: upstream release (`crate-ci/typos`)
- GLOBAL: `https://github.com/crate-ci/typos/releases/download/${tag}/typos-${tag}-<target>.<ext>`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: upstream publishes no `.sha256` sidecar files; digests were computed from locally downloaded bytes and confirmed against a second independent download for all 5 targets of `1.52.2`.
- Auto-update: yes (`extensions.autoupdate`, matching the 5 supported targets with `${tag}`).

## Linking

- `linux/x86_64`: `typos-v1.52.2-x86_64-unknown-linux-musl.tar.gz` — `ELF 64-bit LSB pie executable, x86-64, static-pie linked`, no `.interp`, zero `DT_NEEDED` (`ldd`: `statically linked`).
- `linux/aarch64`: `typos-v1.52.2-aarch64-unknown-linux-musl.tar.gz` — `ELF 64-bit LSB executable, ARM aarch64, statically linked`, no `.interp`, no dynamic section, zero `DT_NEEDED`.
- `windows/x86_64`: PE32+ executable (`machine=0x8664`) importing only Windows OS system DLLs (`kernel32.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `ntdll.dll`, `userenv.dll`, `advapi32.dll`, `oleaut32.dll`, `bcryptprimitives.dll`); statically links MSVC CRT, no `VCRUNTIME140.dll`.
- Declares no `deps` on any platform.

## What the hooks do

- `install`: all upstream archives are flat at root (`typos` / `typos.exe`, `README.md`, `LICENSE-MIT`, `LICENSE-APACHE`, `doc/`); extracts directly into `pkginfo.install_dir()` (`tar -xzf` on POSIX, `System32\tar.exe -xf` on Windows) so files never mix in shared `runtimedir`, ensures executable permission on POSIX, and checks the binary with `payload.require`.
- `config`: registers `typos` via `xvm.add("typos", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `typos` via `xvm.remove("typos")`.
- System impact: none; self-contained under `pkginfo.install_dir()` and subos xvm shims.

## Verification

- Verified locally on Linux `x86_64`: static/isolation tests, repo-wide checks, lints, `tools/xpkg_ci.py inspect/materialize`, isolated `xlings install local:typos -y`, `typos --version`, typo detection on a temp file, `dep-closure-check.sh`, `pytest` (`index`, `lifecycle`, `verify`), and `xlings remove`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`/`aarch64`), `windows` (`x86_64`) runtime installs (deferred to CI).

## Revision log

- 2026-11-26 — added at 1.52.2: initial spec-2 recipe covering Linux musl (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), and Windows (`x86_64`).
