# k0sctl

A bootstrapping and management tool for k0s clusters (`k0sproject/k0sctl`); provides the `k0sctl` CLI (`status = "stable"`).

- Upstream: https://github.com/k0sproject/k0sctl (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v0.33.1` publishes no `win-arm64` binary.

## Source

- Tier: upstream official repository release (`https://github.com/k0sproject/k0sctl/releases`)
- GLOBAL:
  - `linux`: `https://github.com/k0sproject/k0sctl/releases/download/v${version}/k0sctl-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/k0sproject/k0sctl/releases/download/v${version}/k0sctl-darwin-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/k0sproject/k0sctl/releases/download/v${version}/k0sctl-win-${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI mirrors to `xlings-res` after merge; all 5 asset filenames are distinct with zero `materialize` basename collision).
- Checksums: taken from upstream `checksums.txt` for `v0.33.1` and verified locally via `sha256sum` on all 5 downloaded binaries.
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/k0sproject/k0sctl/releases`).

## Linking

- `linux/x86_64` and `linux/aarch64`: static Go ELF executables. Verified with `readelf -d` (no dynamic section) and `ldd` ("not a dynamic executable"). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`). PE import inspection (`objdump -p`) shows only `kernel32.dll` (no `VCRUNTIME140.dll` or `MSVCP140.dll`), so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, detects Windows payloads by filename (`*.exe` or `k0sctl-win*`), `OS=Windows_NT`, or Windows drive/backslash in `install_dir()`, cleans and creates `pkginfo.install_dir()`, moves the raw binary to `k0sctl.exe` on Windows or `k0sctl` on POSIX, runs `chmod +x` on POSIX, and asserts the target file exists.
- `config`: registers `k0sctl` with `xvm.add("k0sctl", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("k0sctl")`.
- System impact: none (no shell profile, `PATH`, or system configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/k/test_k0sctl.py -m "static or isolation" -v`
  - `pytest tests/ -m "static or isolation" --tb=short -q`
  - `python3 tools/xpkg_ci.py inspect --only k0sctl`
  - `tools/lint_exec_quoting.sh` and `.github/scripts/check-*.sh`
  - Isolated `XLINGS_HOME` & `HOME`: `xlings self init`, `xlings config --add-xpkg pkgs/k/k0sctl.lua`, `xlings install local:k0sctl@0.33.1 -y`, `k0sctl version`, `k0sctl --help`, `pytest tests/k/test_k0sctl.py -m "index or lifecycle or verify" -v`, and `xlings remove local:k0sctl@0.33.1 -y`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (not on host; covered by CI runners plus SHA-256 and ELF/PE inspection).

## Revision log

- 2026-11-26 — added at `0.33.1`: initial spec-2 recipe using upstream single-file binaries for linux (`x86_64`, `aarch64`), macosx (`x86_64`, `aarch64`), and windows (`x86_64`).
