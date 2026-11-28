# nushell

A new type of shell (`nushell/nushell`, binary `nu`), `status = "stable"`.

- Upstream: https://www.nushell.sh (`https://github.com/nushell/nushell`, MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Windows `aarch64` is omitted because upstream `nu-0.117.0-aarch64-pc-windows-msvc.zip` imports `VCRUNTIME140.dll` and `api-ms-win-crt-*` while `xim:vcruntime` currently supports `x86_64` only.

## Source

- Tier: upstream release (`nushell/nushell`)
- GLOBAL: `https://github.com/nushell/nushell/releases/download/${version}/nu-${version}-<target>.(tar.gz|zip)`
- CN: none yet (`ci = { mirror = true }` declared)
- Checksums: taken from upstream `SHA256SUMS` at release `0.117.0` and verified locally with `sha256sum -c` on all downloaded archives (`linux` x86_64/aarch64, `macosx` x86_64/aarch64, `windows` x86_64/aarch64).
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}` against `nushell/nushell/releases`)

## Linking

- `linux/x86_64`: `nu` and all 8 `nu_plugin_*` binaries in `nu-0.117.0-x86_64-unknown-linux-musl` are static-pie musl ELFs (`PT_INTERP` absent, `ldd` reports `statically linked`, zero `DT_NEEDED`). Declares no runtime deps.
- `linux/aarch64`: `nu` and all 8 `nu_plugin_*` binaries in `nu-0.117.0-aarch64-unknown-linux-musl` are statically linked musl ELFs (`PT_INTERP` absent, no dynamic section). Declares no runtime deps.
- `windows/x86_64`: `nu.exe`, `less.exe`, and all 8 `nu_plugin_*.exe` binaries use static CRT and import only Windows OS system DLLs (`kernel32.dll`, `ntdll.dll`, `bcryptprimitives.dll`, `advapi32.dll`, `ws2_32.dll`, etc.; no `VCRUNTIME140.dll`). Declares no `xim:vcruntime` dep.

## What the hooks do

- install: POSIX tarballs unpack into `nu-<version>-<target>/` and move into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem }`; Windows zip is flat (no enclosing directory), so `payload.unpack{ extracted = nil }` extracts via `%SystemRoot%\System32\tar.exe` without `--strip-components`. Ensures `+x` on `nu` and bundled `nu_plugin_*` binaries on POSIX and asserts `nu`/`nu.exe` and `LICENSE` via `payload.require`.
- config: registers `nushell` as `type = "group"`, `nu` at `pkginfo.install_dir()`, and bundled `nu_plugin_*` binaries bound to `nushell@<version>` (`programs = {"nu"}` so Windows `/?` checks probe only `nu`).
- uninstall: removes all registered `nu_plugin_*` nodes, `nu`, and `nushell`.
- System impact: none (self-contained in `pkginfo.install_dir()` and xvm shims).

## Verification

- Verified `linux/x86_64` locally under isolated `XLINGS_HOME` & `HOME`: `xlings config --add-xpkg`, `xlings search nushell`, `xlings install local:nushell -y`, `nu --version`, `nu -c "1 + 2"`, `dep-closure-check.sh`, `xlings remove`, repo-wide static/isolation/policy checks, `tools/xpkg_ci.py inspect/materialize`, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` were not run locally (`x86_64` Linux host); archive checksums, directory layouts, `linux/aarch64` ELF linking, and `windows/x86_64` PE imports were inspected locally on downloaded upstream archives, and `windows`/`macosx` installs are exercised by PR CI.

## Revision log

- 2026-11-26 — added at `0.117.0`: static musl builds on Linux (`x86_64`, `aarch64`), Darwin tarballs on macOS (`x86_64`, `aarch64`), static-CRT flat zip on Windows `x86_64`.
