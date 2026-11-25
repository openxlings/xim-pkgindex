# atuin

Magical shell history CLI (`atuin`), `status = "stable"`.

- Upstream: https://github.com/atuinsh/atuin (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64` resource-only, `aarch64`), `windows` (`x86_64`). Windows ARM64 is omitted because upstream release `v18.25.1` publishes no `aarch64-pc-windows-msvc` archive.

## Source

- Tier: upstream release (`atuinsh/atuin`)
- GLOBAL: `https://github.com/atuinsh/atuin/releases/download/v18.25.1/atuin-<target>.(tar.gz|zip)`
- CN: none yet (`ci = { mirror = true }` declared)
- Checksums: taken from upstream per-asset `.sha256` files and `sha256.sum` in `v18.25.1`, and verified locally with `sha256sum -c` on all 5 downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` for `atuinsh/atuin/releases`)

## Linking

- `linux/x86_64`: `atuin-x86_64-unknown-linux-musl` ELF 64-bit LSB static-pie executable (`PT_INTERP` absent, `DT_NEEDED` empty, `ldd` reports `statically linked`). Declares no runtime deps.
- `linux/aarch64`: `atuin-aarch64-unknown-linux-musl` ELF 64-bit LSB statically linked executable (`PT_INTERP` absent, `DT_NEEDED` empty). Declares no runtime deps.
- `windows/x86_64`: `atuin.exe` PE32+ x86-64 binary built with static CRT; `objdump -p` shows only Windows OS system DLLs (`kernel32.dll`, `ntdll.dll`, `ws2_32.dll`, `bcrypt.dll`, `crypt32.dll`, `user32.dll`, etc.) and no `VCRUNTIME140.dll` / `MSVCP140.dll`. Declares no `xim:vcruntime` dep.

## What the hooks do

- install: POSIX tarballs unpack into `atuin-<target>/` and are moved into `pkginfo.install_dir()` via `payload.unpack{ extracted = stem }`; Windows zip is flat (no enclosing dir), so `payload.unpack{ extracted = nil }` extracts it directly via `%SystemRoot%\System32\tar.exe` without `--strip-components`. Asserts `atuin` (`atuin.exe` on Windows) and `LICENSE` via `payload.require`.
- config: registers `atuin` via `xvm.add("atuin", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `atuin` via `xvm.remove("atuin")`.
- System impact: none (self-contained in `pkginfo.install_dir()` and xvm shim).

## Verification

- Verified `linux/x86_64` locally under `$XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search`, `xlings install local:atuin@18.25.1 -y`, `which atuin`, `atuin --version`, `atuin init bash`, `atuin history start/end/search/stats`, idempotent reinstall, `xlings remove local:atuin -y`, plus `pytest` static/isolation/index/verify suites and repo-wide checks.
- `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` were not run locally (x86_64 Linux host); archive checksums, directory layouts, `linux/aarch64` ELF linking, and `windows/x86_64` PE imports were verified locally on downloaded upstream archives.

## Revision log

- 2026-11-25 — added at 18.25.1: static musl builds on Linux (x86_64, aarch64), both Darwin archs on macOS, static-CRT flat zip on Windows x86_64.
