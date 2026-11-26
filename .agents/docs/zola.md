# zola

- **Upstream**: <https://github.com/getzola/zola> (`getzola/zola`)
- **Latest packaged version**: `0.23.6` (`spec = "2"`, `ci = { mirror = true }`)
- **Platforms & artifacts**:
  - `linux` `x86_64`: `zola-v0.23.6-x86_64-unknown-linux-musl.tar.gz` (static musl ELF, no `NEEDED`)
  - `linux` `aarch64`: `zola-v0.23.6-aarch64-unknown-linux-gnu.tar.gz` (dynamic ELF: `GLIBC_2.35`, `GCC_4.2.0`; declares `xim:glibc`, `xim:gcc-runtime`)
  - `macosx` `x86_64`: `zola-v0.23.6-x86_64-apple-darwin.tar.gz`
  - `macosx` `aarch64`: `zola-v0.23.6-aarch64-apple-darwin.tar.gz`
  - `windows` `x86_64`: `zola-v0.23.6-x86_64-pc-windows-msvc.zip` (imports `VCRUNTIME140.dll`; declares `xim:vcruntime`)
- **Notes**:
  - Upstream tarballs are flat (no top-level wrapper directory), so `install()` extracts directly into `pkginfo.install_dir()` via `tar -xzf`.
  - Verified on `linux/x86_64` in isolated `XLINGS_HOME`.
