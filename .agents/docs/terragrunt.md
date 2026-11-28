# terragrunt

- **Upstream**: `gruntwork-io/terragrunt` (`https://terragrunt.gruntwork.io`)
- **Version**: `1.2.3` (`v1.2.3`)
- **License**: `MIT`
- **Platforms**:
  - `linux`: `x86_64`, `aarch64` (`terragrunt_linux_{amd64,arm64}.tar.gz`)
  - `macosx`: `x86_64`, `aarch64` (`terragrunt_darwin_{amd64,arm64}.tar.gz`)
  - `windows`: `x86_64` (`terragrunt_windows_amd64.exe.zip`; no `windows_arm64` asset upstream)
- **Notes**:
  - Each upstream archive contains a single arch-suffixed binary (`terragrunt_<os>_<arch>[.exe]`); `install()` renames it to `terragrunt` (or `terragrunt.exe` on Windows) inside `pkginfo.install_dir()`.
  - Linux ELF binaries (`x86_64`, `aarch64`) are statically linked Go executables with no dynamic section.
  - Windows PE32+ binary (`x86_64`) imports only `kernel32.dll`.
