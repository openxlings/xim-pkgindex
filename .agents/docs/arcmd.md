# arcmd

Native local-first Markdown and rich-text editor built with Go and MyGo Native UI (`arcmd`), `status = "dev"` (upstream preview).

- Upstream: https://github.com/Ciao1019/ArcMD (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream release `v0.4.0` publishes no Windows ARM64 archive.

## Source

- Tier: upstream repository release (`Ciao1019/ArcMD` GitHub Releases)
- GLOBAL: `https://github.com/Ciao1019/ArcMD/releases/download/v${version}/arcmd-${version}-<os>-<arch_alias>.(tar.gz|zip)`
- CN: none yet (`ci = { mirror = true }` declared for `xlings-res` mirroring)
- Checksums: all 5 archive SHA-256 digests match upstream `SHA256SUMS.txt`, GitHub Release asset digests, and local `sha256sum` over downloaded archives.
- Auto-update: yes (`extensions.autoupdate` tracking `Ciao1019/ArcMD/releases` with `${tag}` and `${version}`).

## Linking

- `linux/x86_64` & `linux/aarch64`: dynamically linked Go + MyGo ELF (`PT_INTERP` `/lib64/ld-linux-x86-64.so.2` and `/lib/ld-linux-aarch64.so.1`; `DT_NEEDED`: `libdl.so.2`, `libpthread.so.0`, `libc.so.6`). Intentionally kept on the host loader with no `deps` because MyGo Native UI dynamically `dlopen()`s host desktop libraries (`libgtk-3.so.0`, `libgdk-3.so.0`, `libwayland-client.so.0`, `libcairo.so.2`, `libpango-1.0.so.0`, `libharfbuzz.so.0`, `libfontconfig.so.1`, `libepoxy.so.0`, `libwebkit2gtk-4.1.so.0`, `libpoppler-glib.so.8`, `libsecret-1.so.0`, `libappindicator3.so.1`, etc.); declaring `xim:glibc` would remove host `/etc/ld.so.cache` fallback and break GUI launch (same design as `blender.lua` and `zed.lua`).
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`) inside signed `ArcMD.app/`.
- `windows/x86_64`: PE32+ GUI executable (`ArcMD.exe`) whose PE Import Directory names only `kernel32.dll` (no `VCRUNTIME140.dll` / `MSVCP140.dll`). Declares no `deps`.

## What the hooks do

- `installed`: checks real payload files per platform (`arcmd`/`ArcMD.app/Contents/MacOS/ArcMD`/`ArcMD.exe`, `LICENSE`, icons/metadata) via `payload.present`.
- `install`: unpacks directly from the downloaded archive into `pkginfo.install_dir()` (`tar -xzf` on POSIX so flat Linux archives never pull stray files from the shared runtime directory; `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows), runs `chmod +x` on POSIX binaries, and asserts extracted files via `payload.require`.
- `config`: registers `arcmd` via `xvm.add` (pointing at `ArcMD.app/Contents/MacOS` with `alias = "ArcMD"` on macOS, `alias = "ArcMD.exe"` on Windows, and `pkginfo.install_dir()` on Linux), and creates a Windows Start Menu shortcut (`ArcMD.lnk`, best-effort, no Desktop icon) via `xim.pkgindex.shortcut`. `programs = {}` is left empty deliberately because unrecognized positional args (such as Windows CI's `/?` and `--version` probes) launch the desktop GUI and block.
- `uninstall`: removes the Start Menu shortcut (Windows) and unregisters `arcmd` via `xvm.remove`.
- System impact: none on Linux/macOS outside `$XLINGS_HOME`; best-effort Start Menu `.lnk` on Windows removed on uninstall.

## Verification

- Verified locally on Linux `x86_64` in isolated `$XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search arcmd`, `xlings install local:arcmd@0.4.0 -y`, `which arcmd`, `arcmd --help`, `arcmd status -json` and `arcmd doc create`/`list` in isolated `ARCMD_HOME`, `ls` of payload dir, idempotent reinstall, `dep-closure-check.sh`, `xlings remove` (plus idempotent repeat removal and shim cleanup), `pytest tests/a/test_arcmd.py` (`static`, `isolation`, `index`, `lifecycle`, `verify`), repo-wide static/isolation tests, policy scripts, `tools/lint_exec_quoting.sh`, `tools/xpkg_mirror_queue.py precheck`, and `xpkgindex-update inspect/check`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (verified via archive layout, binary header/import inspection, checksum agreement, Lua sandbox hook tests, and GitHub Actions CI).

## Revision log

- 2026-11-26 — added at `0.4.0`: Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), Windows (`x86_64`).
