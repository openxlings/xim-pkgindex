# packer

- **Upstream**: https://www.packer.io / https://github.com/hashicorp/packer
- **Latest packaged version**: `1.16.3`
- **Source**: Official HashiCorp releases (`https://releases.hashicorp.com/packer/${version}/packer_${version}_<os>_<arch>.zip`), verified against `packer_1.16.3_SHA256SUMS`.
- **Platforms**: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`).
- **Notes**:
  - All archives are flat `.zip` files containing `packer` (or `packer.exe`) and `LICENSE.txt`.
  - Linux binaries are statically linked Go executables (`readelf -d`: no dynamic section); the Windows PE32+ binary imports only `kernel32.dll`.
  - Uses `ci = { mirror = true }` for xlings-res mirroring.
