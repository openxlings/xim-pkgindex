# skaffold

Easy and Repeatable Kubernetes Development (`GoogleContainerTools/skaffold`); provides the `skaffold` CLI (status: `stable`).

- Upstream: https://github.com/GoogleContainerTools/skaffold (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v2.25.0` publishes no `windows-arm64` binary.

## Source

- Tier: upstream official repository release (`https://github.com/GoogleContainerTools/skaffold/releases`)
- GLOBAL:
  - `linux`: `https://github.com/GoogleContainerTools/skaffold/releases/download/v${version}/skaffold-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/GoogleContainerTools/skaffold/releases/download/v${version}/skaffold-darwin-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/GoogleContainerTools/skaffold/releases/download/v${version}/skaffold-windows-${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge; every asset has a distinct filename with zero `materialize` basename collision)
- Checksums: matched upstream `*.sha256` sidecars, GitHub release digests, and locally computed `sha256sum` across all 5 `v2.25.0` release binaries.
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/GoogleContainerTools/skaffold/releases`)

## Linking

- `linux/x86_64` and `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`). PE import inspection shows only `kernel32.dll`, with no `VCRUNTIME140.dll` or `MSVCP140.dll`, so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, clears and creates `pkginfo.install_dir()`, moves the downloaded raw binary to `<install_dir>/skaffold` (or `skaffold.exe` on Windows), runs `chmod +x` on Unix, and verifies the target file exists.
- `config`: registers `skaffold` via `xvm.add("skaffold", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `skaffold` via `xvm.remove("skaffold")`.
- System impact: none (no shell profile, `PATH`, or host configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/s/test_skaffold.py -m "static or isolation"`
  - Repo-wide `pytest tests/ -m "static or isolation"`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `python3 tools/xpkg_ci.py inspect --only skaffold`
  - Isolated `HOME=/tmp/xlings-skaffold XLINGS_HOME=/tmp/xlings-skaffold`: `xlings self init`, `xlings config --add-xpkg pkgs/s/skaffold.lua`, `xlings search skaffold`, `xlings install local:skaffold@2.25.0 -y` (using `--add-archives` with the locally verified upstream binary after `xlings` built-in download stalled on local proxy/TUN), `skaffold version`, `skaffold --help`, `skaffold completion bash`, `pytest tests/s/test_skaffold.py -m "index or lifecycle or verify"`, idempotent reinstall, `xlings remove local:skaffold -y`, and clean uninstall check.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (covered by CI; SHA-256 checksums, ELF dynamic sections, PE imports, and `xpkg_ci.py inspect` verified locally for all 5 assets).

## Revision log

- 2026-11-26 — added at 2.25.0: initial spec-2 recipe using upstream single-file binaries for linux (x86_64, aarch64), macosx (x86_64, aarch64), and windows (x86_64).
