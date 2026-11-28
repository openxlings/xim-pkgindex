# devspace

The Fastest Developer Tool for Kubernetes (`devspace-sh/devspace`); provides the `devspace` CLI (`status = "stable"`).

- Upstream: https://github.com/devspace-sh/devspace (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v6.3.21` publishes no `windows-arm64` binary.

## Source

- Tier: upstream official repository release (`https://github.com/devspace-sh/devspace/releases`)
- GLOBAL:
  - `linux`: `https://github.com/devspace-sh/devspace/releases/download/v${version}/devspace-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/devspace-sh/devspace/releases/download/v${version}/devspace-darwin-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/devspace-sh/devspace/releases/download/v${version}/devspace-windows-${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI mirrors to `xlings-res` after merge; all 5 asset filenames are distinct with zero `materialize` basename collision).
- Checksums: matched upstream `*.sha256` sidecars, GitHub release digests, and locally computed `sha256sum` across all 5 `v6.3.21` release binaries.
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/devspace-sh/devspace/releases`).

## Linking

- `linux/x86_64` and `linux/aarch64`: static Go ELF64 executables (`readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`). PE import inspection shows only `kernel32.dll` (no `VCRUNTIME140.dll` or `MSVCP140.dll`), so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, detects Windows payloads by filename (`*.exe` or `devspace-windows*`), `OS=Windows_NT`, or Windows drive/backslash in `install_dir()`, cleans and creates `pkginfo.install_dir()`, moves the raw binary to `devspace.exe` on Windows or `devspace` on POSIX, runs `chmod +x` on POSIX, and asserts the target file exists.
- `config`: registers `devspace` with `xvm.add("devspace", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("devspace")`.
- System impact: none (no shell profile, `PATH`, or system configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/d/test_devspace.py -m "static or isolation"`
  - `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, `python3 tools/xpkg_ci.py inspect --only devspace`
  - Isolated `HOME=/tmp/xlings-devspace XLINGS_HOME=/tmp/xlings-devspace`: `xlings self init`, `xlings config --add-xpkg pkgs/d/devspace.lua`, `xlings search devspace`, `xlings install local:devspace@6.3.21 -y`, `devspace version`, `devspace --help`, `devspace completion bash`, `devspace /?` (exits immediately with code 1), `pytest tests/d/test_devspace.py -m "index or lifecycle or verify"`, and `xlings remove local:devspace@6.3.21 -y` (shim removed, `workspace` empty).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (not on host; covered by CI runners plus SHA-256, ELF/PE inspection, `xpkg_ci.py inspect`, and Lua sandbox hook tests).

## Revision log

- 2026-11-26 — added at `6.3.21`: initial spec-2 recipe using upstream single-file binaries for linux (`x86_64`, `aarch64`), macosx (`x86_64`, `aarch64`), and windows (`x86_64`).
