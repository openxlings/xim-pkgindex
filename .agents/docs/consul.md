# consul

HashiCorp Consul service networking CLI (provides `consul`, status `stable`).

- Upstream: https://www.consul.io (repo: https://github.com/hashicorp/consul, license: `BSL-1.1`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Upstream does not publish `windows/arm64` for `2.1.0`.

## Source

- Tier: upstream release (`https://api.releases.hashicorp.com/v1/releases/consul/latest`)
- GLOBAL: `https://releases.hashicorp.com/consul/${version}/consul_${version}_<os>_<arch>.zip`
- CN: none yet (`ci = { mirror = true }` — a maintainer/CI will mirror to `xlings-res`)
- Checksums: verified against `consul_2.1.0_SHA256SUMS` and `sha256sum` of all 5 downloaded `.zip` archives.
- Auto-update: no (not configured yet)

## Linking

- `linux` (`x86_64`, `aarch64`): statically linked Go ELF64 binaries (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable). Declares no `deps`.
- `windows` (`x86_64`): standard Go Windows PE32+ executable (`consul.exe`).

## What the hooks do

- `install`: unpacks the flat `.zip` archive (`unzip -q -o` on POSIX, `payload.unpack{}` on Windows), marks `consul` executable on POSIX, and verifies `consul`/`consul.exe` and `LICENSE.txt` via `payload.require`.
- `config`: registers `consul` via `xvm.add("consul", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `consul` via `xvm.remove("consul")`.
- System impact: none outside the package install directory and xvm registration.

## Verification

- Verified `consul` `2.1.0` on `linux` `x86_64` in isolated `XLINGS_HOME=/tmp/xlings-consul`: `xlings install`, `consul version`, `consul /?`, pytest (`tests/c/test_consul.py`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only consul`.
- Not run locally: `linux/aarch64` execution, `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`) — verified archive SHA256s, archive layout, and `linux/aarch64` ELF dynamic section only.

## Revision log

- 2026-11-26 — added at `2.1.0`: initial spec-2 package from HashiCorp official releases.
