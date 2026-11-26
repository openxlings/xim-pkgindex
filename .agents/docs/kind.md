# kind

Kubernetes IN Docker — CLI for running local Kubernetes clusters using Docker container 'nodes' (`kubernetes-sigs/kind`); provides the `kind` CLI (`status = "stable"`).

- Upstream: https://github.com/kubernetes-sigs/kind (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v0.33.0` publishes no `windows-arm64` binary.

## Source

- Tier: upstream official repository release (`https://github.com/kubernetes-sigs/kind/releases`)
- GLOBAL:
  - `linux`: `https://github.com/kubernetes-sigs/kind/releases/download/v${version}/kind-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/kubernetes-sigs/kind/releases/download/v${version}/kind-darwin-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/kubernetes-sigs/kind/releases/download/v${version}/kind-windows-${arch_alias}` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI mirrors to `xlings-res` after merge; all 5 asset filenames are distinct with zero `materialize` basename collision).
- Checksums: taken from upstream `*.sha256sum` files for `v0.33.0` and verified locally via `sha256sum -c` and GitHub release digests on all 5 downloaded binaries.
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/kubernetes-sigs/kind/releases`).

## Linking

- `linux/x86_64` and `linux/aarch64`: static Go ELF executables (`CGO_ENABLED=0`). Verified with `readelf -d` (no dynamic section) and `ldd` ("not a dynamic executable"). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`), published upstream as `kind-windows-amd64` without a `.exe` suffix. PE import inspection shows only `kernel32.dll` (no `VCRUNTIME140.dll` or `MSVCP140.dll`), so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, detects Windows payloads by filename (`*.exe` or `kind-windows*`), `OS=Windows_NT`, or Windows drive/backslash in `install_dir()` (essential because `kind-windows-amd64` lacks `.exe` upstream), cleans and creates `pkginfo.install_dir()`, moves the raw binary to `kind.exe` on Windows or `kind` on POSIX, runs `chmod +x` on POSIX, and asserts the target file exists.
- `config`: registers `kind` with `xvm.add("kind", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("kind")`.
- System impact: none (no shell profile, `PATH`, or system configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/k/test_kind.py -m "static or isolation" -v` (14 passed)
  - `pytest tests/ -m "static or isolation" -q` (8540 passed, 43 skipped, 1645 deselected, 3 xpassed)
  - `tools/xpkg_ci.py inspect --only kind` and `tools/xpkg_ci.py materialize kind` (all 5 assets downloaded, hashed, and validated)
  - `tools/lint_exec_quoting.sh`, `.github/scripts/check-no-direct-ld-libpath.sh`, `.github/scripts/check-no-blocking-input.sh`, `.github/scripts/check-no-gnu-only-stat.sh`, `.github/scripts/check-dep-namespace.sh`, `.github/scripts/check-revision.sh`
  - Isolated `XLINGS_HOME` & `HOME`: `xlings self init`, `xlings config --add-xpkg pkgs/k/kind.lua`, `xlings search kind`, `xlings install local:kind@0.33.0 -y`, `kind version` (`kind v0.33.0 go1.26.7 linux/amd64`), `kind --help`, `kind completion bash`, `kind /?` (exits immediately with code 1), `pytest tests/k/test_kind.py -m "index or lifecycle or verify" -v` (5 passed), and `xlings remove local:kind@0.33.0 -y` (shim removed, `workspace` empty).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (not on host; covered by CI runners plus SHA-256, `materialize`, ELF/PE inspection, and Lua sandbox hook tests).

## Revision log

- 2026-11-26 — added at `0.33.0`: initial spec-2 recipe using upstream single-file binaries for linux (`x86_64`, `aarch64`), macosx (`x86_64`, `aarch64`), and windows (`x86_64`).
