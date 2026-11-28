# pkl

A configuration as code language with rich validation and tooling. Provides the `pkl` CLI command; status `stable`.

- Upstream: <https://github.com/apple/pkl> (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`aarch64`), `windows` (`x86_64`). `macosx/x86_64` is omitted because upstream dropped `pkl-macos-amd64` starting in `0.33.0`; `windows/aarch64` is omitted because upstream publishes no `pkl-windows-aarch64.exe` asset.

## Source

- Tier: official repository release (`apple/pkl`, tag `0.33.1`)
- GLOBAL: `https://github.com/apple/pkl/releases/download/${tag}/pkl-<platform>-<arch>[.exe]`
- CN: none yet (`ci = { mirror = true }` declared; a maintainer/mirror job handles `xlings-res`)
- Checksums: verified against GitHub release asset `digest` metadata and local `sha256sum` on downloaded assets for `linux/x86_64`, `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64`.
- Auto-update: yes (`extensions.autoupdate`, GitHub releases with bare `${tag}` matching `${version}`).

## Linking

- `linux/x86_64`: dynamically linked GraalVM Native Image PIE ELF (`PT_INTERP`: `/lib64/ld-linux-x86-64.so.2`; `DT_NEEDED`: `libz.so.1`, `libpthread.so.0`, `libdl.so.2`, `librt.so.1`, `libc.so.6`). Declares runtime deps `xim:glibc@>=2.39` and `xim:zlib`.
- `linux/aarch64`: dynamically linked GraalVM Native Image PIE ELF (`PT_INTERP`: `/lib/ld-linux-aarch64.so.1`; `DT_NEEDED`: `libz.so.1`, `libpthread.so.0`, `libdl.so.2`, `librt.so.1`, `libc.so.6`, `ld-linux-aarch64.so.1`). Declares runtime deps `xim:glibc@>=2.39` and `xim:zlib`.
- `windows/x86_64`: PE32+ console executable importing `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`, UCRT API-set DLLs, and Windows system DLLs. Declares runtime dependency `xim:vcruntime` and copies its CRT DLLs app-local beside `pkl.exe`.

## What the hooks do

- install: moves the downloaded standalone binary into `pkginfo.install_dir()` as `pkl` (or `pkl.exe` on Windows), copies `xim:vcruntime/bin` DLLs beside `pkl.exe` on Windows, and runs `chmod +x` on POSIX.
- config: registers `pkl` with `xvm.add("pkl", { bindir = pkginfo.install_dir() })`.
- uninstall: removes the `pkl` xvm registration with `xvm.remove("pkl")`.
- System impact: none; stays completely inside `XLINGS_HOME`.

## Verification

- Verified locally on `linux/x86_64` in an isolated `XLINGS_HOME`: `xlings config --add-xpkg pkgs/p/pkl.lua`, `xlings search pkl`, `xlings install local:pkl -y`, `pkl --version`, `pkl eval -f json` on a `.pkl` config, `xlings list pkl`, idempotent reinstall, `xlings remove pkl -y`, `dep-closure-check.sh`, `lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `tools/xpkg_ci.py inspect/materialize`, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not executed locally: `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64` runtime installs (covered by GitHub Actions CI after PR creation).

## Revision log

- 2026-11-26 — added at `0.33.1`: official GraalVM Native Image CLI binaries for `linux/{x86_64,aarch64}` (`xim:glibc` + `xim:zlib`), `macosx/aarch64`, and `windows/x86_64` (`xim:vcruntime`).
