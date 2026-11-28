# k3d

Little helper to run CNCF's k3s in Docker (`k3d-io/k3d`); provides the `k3d` CLI (`status = "stable"`).

- Upstream: https://github.com/k3d-io/k3d (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v5.9.0` publishes no `windows-arm64` binary.

## Source

- Tier: upstream official repository release (`https://github.com/k3d-io/k3d/releases`)
- GLOBAL:
  - `linux`: `https://github.com/k3d-io/k3d/releases/download/v${version}/k3d-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/k3d-io/k3d/releases/download/v${version}/k3d-darwin-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/k3d-io/k3d/releases/download/v${version}/k3d-windows-${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI mirrors to `xlings-res` after merge; all 5 asset filenames are distinct with zero `materialize` basename collision).
- Checksums: taken from upstream `checksums.txt` for `v5.9.0` and verified locally via `sha256sum` and GitHub release digests on all 5 downloaded binaries.
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/k3d-io/k3d/releases`).

## Linking

- `linux/x86_64` and `linux/aarch64`: static Go ELF executables. Verified with `readelf -d` (no dynamic section) and `ldd` ("not a dynamic executable"). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`). PE import inspection shows only `kernel32.dll` (no `VCRUNTIME140.dll` or `MSVCP140.dll`), so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, detects Windows payloads by filename (`*.exe` or `k3d-windows*`), `OS=Windows_NT`, or Windows drive/backslash in `install_dir()`, cleans and creates `pkginfo.install_dir()`, moves the raw binary to `k3d.exe` on Windows or `k3d` on POSIX, runs `chmod +x` on POSIX, and asserts the target file exists.
- `config`: registers `k3d` with `xvm.add("k3d", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("k3d")`.
- System impact: none (no shell profile, `PATH`, or system configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/k/test_k3d.py -m "static or isolation" -v` (14 passed)
  - `pytest tests/ -m "static or isolation" --tb=short -q` (9305 passed, 43 skipped, 1860 deselected, 3 xpassed)
  - `python3 tools/xpkg_ci.py inspect --only k3d` and `python3 tools/xpkg_ci.py materialize k3d`
  - `tools/lint_exec_quoting.sh`, `.github/scripts/check-no-direct-ld-libpath.sh`, `.github/scripts/check-no-blocking-input.sh`, `.github/scripts/check-no-gnu-only-stat.sh`, `.github/scripts/check-dep-namespace.sh`, `.github/scripts/check-revision.sh`
  - Isolated `XLINGS_HOME` & `HOME`: `xlings self init`, `xlings config --add-xpkg pkgs/k/k3d.lua`, `xlings search k3d`, `xlings install local:k3d@5.9.0 -y`, `k3d version` (`k3d version v5.9.0` / `k3s version v1.35.5-k3s1 (default)`), `k3d --help`, `k3d completion bash`, `k3d /?` (exits immediately with code 1), `pytest tests/k/test_k3d.py -m "index or lifecycle or verify" -v` (5 passed), and `xlings remove local:k3d@5.9.0 -y` (shim removed, `workspace` empty).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (not on host; covered by CI runners plus SHA-256, `materialize`, ELF/PE inspection, and Lua sandbox hook tests).

## Revision log

- 2026-11-26 — added at `5.9.0`: initial spec-2 recipe using upstream single-file binaries for linux (`x86_64`, `aarch64`), macosx (`x86_64`, `aarch64`), and windows (`x86_64`).
