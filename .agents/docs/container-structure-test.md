# container-structure-test

Validate the structure of your container images (`GoogleContainerTools/container-structure-test`); provides the `container-structure-test` CLI (status: `stable`).

- Upstream: https://github.com/GoogleContainerTools/container-structure-test (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v1.22.1` publishes no `windows-arm64` binary.

## Source

- Tier: upstream official repository release (`https://github.com/GoogleContainerTools/container-structure-test/releases`)
- GLOBAL:
  - `linux`: `https://github.com/GoogleContainerTools/container-structure-test/releases/download/v${version}/container-structure-test-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/GoogleContainerTools/container-structure-test/releases/download/v${version}/container-structure-test-darwin-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/GoogleContainerTools/container-structure-test/releases/download/v${version}/container-structure-test-windows-${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge; every asset has a distinct filename with zero `materialize` basename collision)
- Checksums: matched upstream `checksums.txt`, GitHub release digests, and locally computed `sha256sum` across all 5 `v1.22.1` release binaries.
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/GoogleContainerTools/container-structure-test/releases`)

## Linking

- `linux/x86_64` and `linux/aarch64`: statically linked Go ELF64 executables (`readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`). PE import inspection shows only `kernel32.dll`, with no `VCRUNTIME140.dll` or `MSVCP140.dll`, so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, clears and creates `pkginfo.install_dir()`, moves the downloaded raw binary to `<install_dir>/container-structure-test` (or `container-structure-test.exe` on Windows), runs `chmod +x` on Unix, and verifies the target file exists.
- `config`: registers `container-structure-test` via `xvm.add("container-structure-test", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `container-structure-test` via `xvm.remove("container-structure-test")`.
- System impact: none (no shell profile, `PATH`, or host configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/c/test_container_structure_test.py -m "static or isolation"`
  - `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `python3 tools/xpkg_ci.py inspect --only container-structure-test`
  - Isolated `HOME=/tmp/xlings-cst XLINGS_HOME=/tmp/xlings-cst`: `xlings self init`, `xlings config --add-xpkg pkgs/c/container-structure-test.lua`, `xlings search container-structure-test`, `xlings install local:container-structure-test@1.22.1 -y`, `container-structure-test version`, `container-structure-test --help`, `pytest tests/c/test_container_structure_test.py -m "index or lifecycle or verify"`, `xlings remove local:container-structure-test -y`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (covered by CI; SHA-256 checksums, ELF dynamic sections, PE imports, and `xpkg_ci.py inspect` verified locally for all 5 assets).

## Revision log

- 2026-11-26 — added at 1.22.1: initial spec-2 recipe using upstream single-file binaries for linux (x86_64, aarch64), macosx (x86_64, aarch64), and windows (x86_64).
