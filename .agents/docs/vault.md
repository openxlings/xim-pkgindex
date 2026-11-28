# vault

- Upstream: https://www.vaultproject.io (repo: https://github.com/hashicorp/vault)
- Source: HashiCorp official releases (`https://releases.hashicorp.com/vault/${version}/vault_${version}_<os>_<arch>.zip`), verified against `vault_2.2.2_SHA256SUMS`.
- Platforms:
  - `linux` (`x86_64`, `aarch64`): statically linked Go ELF64 binaries (`readelf -d`: no dynamic section, `ldd`: not a dynamic executable).
  - `macosx` (`x86_64`, `aarch64`): `.zip` archives.
  - `windows` (`x86_64`): `.zip` archive (`vault.exe`).
- Installed payload: `vault` (or `vault.exe`) and `LICENSE.txt` via `payload.unpack{}` and `payload.require(...)`.
- Registered program: `vault` via `xvm.add("vault", { bindir = pkginfo.install_dir() })`.
