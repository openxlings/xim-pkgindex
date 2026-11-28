# sops

Simple and flexible tool for managing encrypted files (`sops` CLI, `status = "stable"`).

- Upstream: https://github.com/getsops/sops (MPL-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). All 6 targets publish distinct raw binary filenames.

## Source

- Tier: upstream release (`https://github.com/getsops/sops/releases`)
- GLOBAL:
  - `linux`: `https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.linux.{amd64,arm64}`
  - `macosx`: `https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.darwin.{amd64,arm64}`
  - `windows`: `https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.{amd64,arm64}.exe`
- CN: none yet (`ci = { mirror = true }` requested for `xlings-res` mirroring)
- Checksums: all 6 SHA-256 digests matched `sops-v3.13.3.checksums.txt`, GitHub release digests, and locally downloaded binaries (`sha256sum`).
- Auto-update: yes (`extensions.autoupdate` with `${tag}` and `${version}`)

## Linking

Statically linked Go binaries on Linux (`readelf -d` shows no dynamic section and `ldd` reports "not a dynamic executable" on both `linux.amd64` and `linux.arm64`). Both Windows PE32+ executables (`amd64.exe` / `arm64.exe`) import only `kernel32.dll`. No runtime `deps` declared.

## What the hooks do

- `install`: cleans `install_dir`, creates `install_dir` via `fs.mkdir_p`, moves `pkginfo.install_file()` to `sops` (or `sops.exe` on Windows), runs `chmod +x` on Unix, and asserts the target file exists.
- `config`: registers `sops` with `xvm.add("sops", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `sops` via `xvm.remove("sops")`.
- System impact: none outside the package install directory and xvm registration.

## Verification

- Static & isolation tests (`pytest tests/s/test_sops.py -m "static or isolation" -v`), repository-wide static checks, `lint_exec_quoting.sh`, `.github/scripts/check-revision.sh`, `.github/scripts/check-dep-namespace.sh`, and `tools/xpkg_ci.py inspect/materialize` on Linux x86_64.
- Real isolated `XLINGS_HOME` & `HOME`: `xlings config --add-xpkg`, `xlings search sops`, `xlings install local:sops -y`, `sops --version --disable-version-check`, offline age encrypt/decrypt smoke test, `pytest -m "index or lifecycle or verify"`, and `xlings remove local:sops -y` on Linux x86_64.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) live installs (checked raw binaries, checksums, ELF/PE headers, and Lua sandbox hooks instead).

## Revision log

- 2026-11-26 — added at `3.13.3`: initial spec-2 recipe with `extensions.autoupdate` and `ci = { mirror = true }`.
