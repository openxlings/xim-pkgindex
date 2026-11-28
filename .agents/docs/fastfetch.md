# fastfetch

- **Upstream**: https://github.com/fastfetch-cli/fastfetch
- **Version**: 2.71.0
- **Platforms**: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64` universal), `windows` (`x86_64`)

## Closure & Linking

- **Linux (`x86_64`, `aarch64`)**: Dynamically linked ELF (`libm.so.6`, `libc.so.6`, plus `ld-linux-aarch64.so.1` on `aarch64`), max `GLIBC_2.34`. Declares `xim:glibc@>=2.39` runtime dependency so xlings `elfpatch` stamps `PT_INTERP` and `RPATH` to the SubOS closure.
- **macOS (`x86_64`, `aarch64`)**: Universal tarball (`fastfetch-macos-universal.tar.gz`).
- **Windows (`x86_64`)**: Standalone zip (`fastfetch-windows-amd64.zip`) containing `fastfetch.exe`, `flashfetch.exe`, `lua55.dll`, and `presets/`.

## Verification

- Verified `fastfetch` installation, `fastfetch --version` execution, and uninstallation in an isolated `XLINGS_HOME`.
- Checked `dep-closure-check.sh`, `lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only fastfetch`.
