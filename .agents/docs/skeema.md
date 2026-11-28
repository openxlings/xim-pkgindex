# skeema

Declarative pure-SQL schema management for MySQL and MariaDB (`skeema` CLI, `status = "stable"`).

- Upstream: https://github.com/skeema/skeema (Apache-2.0)
- Homepage: https://www.skeema.io
- Docs: https://www.skeema.io/docs/commands
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`). `windows` is omitted because upstream does not publish Windows binaries.

## Source

- Tier: upstream release (`https://github.com/skeema/skeema/releases`)
- GLOBAL:
  - Linux: `skeema_${version}_linux_{amd64,arm64}.tar.gz`
  - macOS: `skeema_${version}_mac_{amd64,arm64}.tar.gz`
- CN: none yet (`ci = { mirror = true }` requested for `xlings-res` mirroring)
- Checksums: all 4 SHA-256 hashes match upstream `skeema_checksums_1.14.2.txt` and locally downloaded archives (`sha256sum`).
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- Linux (`x86_64`, `aarch64`): statically linked Go ELF64 executables with no `DYNAMIC` section or external libc dependency (`readelf -d` shows no `NEEDED` / `INTERP`). Zero `runtime` dependencies declared.

## What the hooks do

- `installed`: checks `payload.present({ "skeema", "LICENSE", "README.md" })`.
- `install`: cleans `pkginfo.install_dir()`, extracts the flat `.tar.gz` directly into `install_dir` (`tar -xf ... -C ...` + `chmod +x`, with a pre-extracted fallback), and asserts `skeema`, `LICENSE`, `README.md` via `payload.require`.
- `config`: registers `skeema` with `xvm.add("skeema", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `skeema` via `xvm.remove("skeema")`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `HOME` & `XLINGS_HOME`:
  - `xlings config --add-xpkg pkgs/s/skeema.lua`
  - `xlings search skeema`
  - `xlings install local:skeema@1.14.2 -y`
  - `skeema --version`, `skeema version`, `skeema help lint`, `skeema /?` (exits immediately with code 78)
  - `xlings list skeema`, idempotent reinstall, `xlings remove local:skeema -y`, idempotent re-remove, `xlings config --remove-xpkg skeema`
- Ran `pytest tests/s/test_skeema.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repo-wide `static or isolation`, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only skeema`.
- Not run locally: `linux/aarch64` and `macosx` (`x86_64`, `aarch64`) runtime installs (checked all 4 release archives, checksums, layouts, Linux ELF headers, and Lua sandbox hooks instead; CI validates Linux and macOS).

## Revision log

- 2026-11-26 — added at `1.14.2`: initial spec-2 recipe with `extensions.autoupdate` and `ci = { mirror = true }`.
