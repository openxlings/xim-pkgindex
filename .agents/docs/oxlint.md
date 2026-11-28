# oxlint

Fast JavaScript and TypeScript linter written in Rust, from the Oxc project. Provides the `oxlint` CLI (`status = "stable"`).

- Upstream: https://github.com/oxc-project/oxc (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `gnu`, `armv7`, `i686`, `powerpc64le`, `riscv64gc`, `s390x`, and `freebsd` builds, omitted to match `archs = {"x86_64", "aarch64"}` with static musl on Linux.

## Source

- Tier: official repository release (`oxc-project/oxc`, monorepo tag `oxlint_v<version>`)
- GLOBAL: `https://github.com/oxc-project/oxc/releases/download/oxlint_v${version}/oxlint-<target>.<ext>` (`linux`/`darwin` `.tar.gz`, `windows` `.zip`)
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: verified against GitHub release asset digests and locally downloaded archives for all 6 targets of `1.95.0`.
- Auto-update: yes (`extensions.autoupdate` with `tag = "oxlint_v${version}"`, ignoring sibling monorepo tags `oxfmt_v*` and `crates_v*`).

## Linking

- `linux/x86_64`: `oxlint-x86_64-unknown-linux-musl.tar.gz` — `ELF 64-bit LSB pie executable, x86-64, static-pie linked, stripped`, no `.interp`, zero `DT_NEEDED`.
- `linux/aarch64`: `oxlint-aarch64-unknown-linux-musl.tar.gz` — `ELF 64-bit LSB executable, ARM aarch64, statically linked, stripped`, no `.interp`, no `.dynamic` section, zero `DT_NEEDED`.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit executables.
- `windows/x86_64` & `windows/aarch64`: PE32+ console executables importing only Windows OS system and UCRT DLLs (`kernel32.dll`, `ntdll.dll`, `advapi32.dll`, `bcryptprimitives.dll`, `userenv.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `api-ms-win-crt-*-l1-1-0.dll`); no `VCRUNTIME140.dll`.
- Declares no `deps` on any platform.

## What the hooks do

- `install`: extracts the flat upstream archive directly into `pkginfo.install_dir()` (`tar -xzf` on POSIX; `libs/payload.lua` `payload.unpack{}` -> `%SystemRoot%\System32\tar.exe` on Windows), renames the target-triple binary (`oxlint-<triple>` / `oxlint-<triple>.exe`) to `oxlint` / `oxlint.exe`, sets `+x` on POSIX, and asserts the binary with `payload.require`.
- `config`: registers `oxlint` via `xvm.add("oxlint", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `oxlint` via `xvm.remove("oxlint")`.
- System impact: none; self-contained under `pkginfo.install_dir()` and subos `xvm` shims.

## Verification

- Verified `oxlint_v1.95.0` download URLs, SHA256s, archive layouts, ELF headers (`readelf -lW`, `readelf -dW`), PE import tables, and `oxlint --version` / `oxlint /?` / JS linting behavior.
- Verified locally on Linux `x86_64`: static/isolation/spec/index/lifecycle/verify pytest suites, repository checks, `tools/lint_exec_quoting.sh`, `tools/xpkg_ci.py inspect --only oxlint`, `autoupdate-ci.py audit`, and isolated `XLINGS_HOME` install/run/remove.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (covered by CI runners for `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64`).

## Revision log

- 2026-11-26 — added at `1.95.0`: monorepo release tags `oxlint_v1.95.0` with flat target-triple binaries and static Linux/Windows payloads.
