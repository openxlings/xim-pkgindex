# yt-dlp

- **Upstream**: https://github.com/yt-dlp/yt-dlp
- **Package**: `pkgs/y/yt-dlp.lua` (Spec 2)
- **Test**: `tests/y/test_yt_dlp.py`

## Notes

- Linux (`x86_64`, `aarch64`): uses `yt-dlp_linux` and `yt-dlp_linux_aarch64` (glibc-linked PyInstaller binaries) with `xim:glibc@>=2.39` and `xim:zlib` runtime dependencies.
- macOS (`x86_64`, `aarch64`): uses `yt-dlp_macos.zip` (universal archive containing `yt-dlp_macos` and `_internal/`).
- Windows (`x86_64`, `aarch64`): uses `yt-dlp.exe` and `yt-dlp_arm64.exe`.
