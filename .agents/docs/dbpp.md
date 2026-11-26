# dbpp

SQLite-first ADBC database manager & CLI (`db++` / `dbpp`), `status = "dev"`.

- Upstream: https://github.com/FarnaHerry/dbpp (MIT)
- Namespace: `farnaherry` (`farnaherry:dbpp`, matching `tinynext`, `clash-flux`, `llm-switch`)
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`aarch64` only — upstream `v0.2.3` publishes `macos-arm64` only), `windows` (`x86_64` only — upstream publishes no Windows ARM64 archive).

## Source

- Tier: upstream repository release (`FarnaHerry/dbpp`, tag `v0.2.3`)
- GLOBAL: `https://github.com/FarnaHerry/dbpp/releases/download/v${version}/dbpp-${version}-<platform>-<arch>.(tar.gz|zip)`
- CN: none yet (`ci = { mirror = true }` declared)
- Checksums: sha256 taken from GitHub release `v0.2.3` asset digests and verified locally with `sha256sum` on all 4 downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` for `FarnaHerry/dbpp/releases`).

## Archive layouts

- `linux/x86_64`: `build-linux-x86_64/` (`dbpp`, `dbpp.resources/`, `lib/libhuxerui.so`, `lib/libadbc_driver_manager.so.113`, `lib/libadbc_driver_manager.so.113.0.0`, `lib/libadbc_driver_sqlite.so.113.0.0`).
- `linux/aarch64`: `build-linux-arm64/` (same structure).
- `macosx/aarch64`: `build-macos-arm64/dbpp.app/` (`Contents/MacOS/dbpp`, `Contents/Frameworks/lib{huxerui,adbc_driver_manager.,adbc_driver_sqlite.}.dylib`, `Contents/Resources/HuxerUI/huxerui/resources.bin`, ad-hoc signed).
- `windows/x86_64`: flat zip (no enclosing directory) containing `dbpp.exe` (Windows GUI subsystem), `dbpp.resources/`, `huxerui.dll`, `adbc_driver_manager.dll`, `adbc_driver_sqlite.dll`, and app-local MSVC runtime DLLs (`vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, `msvcp140_atomic_wait.dll`).

## Linking

- `linux/x86_64` & `linux/aarch64`:
  - `dbpp`: `PT_INTERP` `/lib64/ld-linux-x86-64.so.2` (`x86_64`) / `/lib/ld-linux-aarch64.so.1` (`aarch64`), `RUNPATH [$ORIGIN:$ORIGIN/lib]`; `DT_NEEDED` = bundled `libadbc_driver_manager.so.113`, `libhuxerui.so`, plus `libstdc++.so.6`, `libgcc_s.so.1`, `libm.so.6`, `libc.so.6` (max `GLIBC_2.38`, `GLIBCXX_3.4.31`).
  - `lib/libadbc_driver_manager.so.113(.0.0)` & `lib/libadbc_driver_sqlite.so.113.0.0`: `libstdc++.so.6`, `libgcc_s.so.1`, `libm.so.6`, `libc.so.6`.
  - `lib/libhuxerui.so`: `libgtk-4.so.1`, `libpangocairo-1.0.so.0`, `libpangoft2-1.0.so.0`, `libpango-1.0.so.0`, `libgdk_pixbuf-2.0.so.0`, `libcairo.so.2`, `libgraphene-1.0.so.0`, `libepoxy.so.0`, `libfontconfig.so.1`, `libsoup-3.0.so.0`, `libgio-2.0.so.0`, `libgobject-2.0.so.0`, `libglib-2.0.so.0`, `libX11.so.6`, `libstdc++.so.6`, `libm.so.6`, `libgcc_s.so.1`, `libc.so.6`.
  - On `linux/x86_64`, `xpm.linux.deps.runtime` declares all 12 direct `xim:*` providers (`glibc@>=2.38`, `gcc-runtime@>=15.1.0`, `gtk4@>=4.16`, `pango@>=1.52`, `gdk-pixbuf@>=2.44`, `cairo@>=1.18.4`, `graphene@>=1.10`, `libepoxy@>=1.5`, `fontconfig@>=2.15`, `libsoup@>=3.0`, `glib@>=2.88`, `libX11@>=1.8`), and `install()` seals `lib/` with `selfcontain.seal(dir, { "lib" })`.
  - Because those GTK4/GNOME/X11 packages currently publish `x86_64` only, `linux/aarch64` clears `package.xpm.linux.deps` at load time via `os.arch()` so `aarch64` installs against the host loader.
- `windows/x86_64`: `objdump -p` on `dbpp.exe` and bundled DLLs shows imports of `MSVCP140.dll`, `MSVCP140_ATOMIC_WAIT.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`, which are already bundled app-local inside the upstream zip, plus Windows OS system/API-set DLLs (`KERNEL32.dll`, `USER32.dll`, `WS2_32.dll`, `d2d1.dll`, `d3d11.dll`, `DWrite.dll`, `dwmapi.dll`, `dcomp.dll`, `WINHTTP.dll`, etc.). No `xim:vcruntime` dep is needed.

## What the hooks do

- `installed`: checks platform-specific required files via `payload.present`.
- `install`: unpacks via `payload.unpack{ extracted = { "build-linux-x86_64", "build-linux-arm64", "build-macos-arm64" } }` (system `tar.exe` extracts the flat Windows zip directly), ensures `+x` on POSIX binaries, verifies core payload files via `payload.require`, and calls `selfcontain.seal(dir, { "lib" })` on Linux.
- `config`: registers `dbpp` via `xvm.add` (pointing at `dbpp.app/Contents/MacOS` on macOS, `alias = "dbpp.exe"` on Windows). `programs = {}` omits `dbpp` from Windows `/?` probing because unrecognized positional args launch the desktop GUI and block.
- `uninstall`: removes `dbpp` via `xvm.remove`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Local `linux/x86_64` isolated `$XLINGS_HOME` verification:
  - `xlings config --add-xpkg pkgs/d/dbpp.lua`, `xlings search dbpp`, `xlings install farnaherry:dbpp@0.2.3 -y`, `dbpp --version`, `dbpp --help`, `dbpp doctor --json`, `dbpp exec`/`query --sqlite`, idempotent reinstall, `dep-closure-check.sh`, `pytest` static/isolation/index/verify suites, `xlings remove farnaherry:dbpp@0.2.3 -y`, and repo-wide policy checks.
- Not run locally (on an `x86_64` Linux host): `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64` runtime execution; verified via downloaded archive inspection (`readelf -d`, `readelf -V`, `objdump -p`, `sha256sum`) and deferred to GitHub Actions macOS/Windows CI runners.

## Revision log

- 2026-11-26 — added at 0.2.3 (`farnaherry:dbpp`): Linux x86_64/aarch64, macOS arm64, Windows x86_64.
