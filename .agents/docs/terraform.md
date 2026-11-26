# terraform

- **Package**: `pkgs/t/terraform.lua` (`spec = "2"`, `ci = { mirror = true }`)
- **Upstream**: HashiCorp official releases (`https://releases.hashicorp.com/terraform/1.17.2/terraform_1.17.2_<os>_<arch>.zip`)
- **Version**: `1.17.2` (`linux`, `macosx`, `windows`; `x86_64` / `aarch64`)
- **Binary**: `terraform` (static Go ELF on Linux, `kernel32.dll`-only PE on Windows x86_64)
- **Notes**:
  - `extensions.autoupdate` is omitted because HashiCorp's release API is not GitHub Releases.
  - All six archives are flat `.zip` files containing `terraform[.exe]` and `LICENSE.txt`.
