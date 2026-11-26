# direnv

- **Package**: `direnv` (`pkgs/d/direnv.lua`)
- **Upstream**: https://github.com/direnv/direnv
- **Homepage**: https://direnv.net
- **License**: MIT
- **Platforms**: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`)

## Packaging Notes

- `direnv` is distributed as standalone raw single-file binaries on GitHub Releases (`direnv.linux-amd64`, `direnv.linux-arm64`, `direnv.darwin-amd64`, `direnv.darwin-arm64`).
- `install()` moves `pkginfo.install_file()` to `<install_dir>/direnv` and marks it executable (`chmod +x`).
- `config()` registers `direnv` via `xvm.add("direnv", { bindir = pkginfo.install_dir() })`.
- `ci = { mirror = true }` and `extensions.autoupdate` are enabled for `linux` and `macosx`.
