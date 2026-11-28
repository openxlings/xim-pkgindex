# playwright-webkit

WebKit build with the patches that let Playwright drive it (`playwright-webkit` shim, `status = "stable"`). Version `27.2` is the browser's own version; Playwright 1.65.1 pins it as revision `2388`.

- Upstream: https://github.com/microsoft/playwright (Apache-2.0); the browser is `LGPL-2.0-or-later`, `BSD-2-Clause`
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Playwright publishes no Windows ARM64 build of any of these.

## Source

- Tier: the Playwright project's own build (Playwright's patched WebKit (`builds/webkit/<revision>`), not Apple's Safari).
- GLOBAL: `https://cdn.playwright.dev/builds/...` (the host Playwright's registry downloads from).
- CN: `https://gitcode.com/xlings-res/playwright-webkit/releases/download/27.2/<file>`, the upstream bytes under the upstream file names, published with `gtc`, each file with a `.sha256` sidecar.
- Checksums: Playwright publishes none. Each was computed from a first download and equals a second download from `playwright.download.prss.microsoft.com`. The CN copy was downloaded back and compared with `cmp`.
- Auto-update: no. There is no release feed; versions move with Playwright's `browsers.json`. `ci.mirror` is not declared because the CN copy already exists.

## Linking

Dynamic glibc binaries on the host's loader and libraries; no `deps`, as `zed.lua` and `blender.lua`. Declaring `xim:glibc` would make elfpatch rewrite the loader and the browser would lose the host's `ld.so.cache`.
The Linux bundle starts through a wrapper that puts `lib/` and `sys/lib/` on `LD_LIBRARY_PATH`. `sys/lib/` already carries `libjxl`, `libbacktrace`, `libsoup`, `libbrotli` and `libdrm`. Run through the wrapper, `MiniBrowser` then misses exactly one library on a Debian host: `libavif.so.13` (Ubuntu 22.04's `libavif13`, libavif 0.9.3). That one is supplied by the xlings ecosystem: `deps.runtime = { "xim:libavif@0.9.3" }` (a conda-forge repack, which brings `xim:aom`), and `install()` links it into the `sys/lib/` of the GTK and WPE variants. Nothing in the payload is patched. GTK 4, GStreamer and the rest of the closure still come from the host; Playwright's `install-dependencies.sh` names about 120 apt packages for them. Only the library found missing is supplied here.

## What the hooks do

- install: the archive is flat, so Linux and macOS extract it again with `unzip` into the payload alone (the shared runtime directory may hold another flat archive); Windows uses `System32\tar.exe`. Then `chmod +x` on the executable and an assertion that one of the three expected executables exists.
- config: registers one shim `playwright-webkit` (`xvm.add` with `alias`) for the platform's executable.
- uninstall: `xvm.remove("playwright-webkit")`.
- System impact: none outside the package's own directory. No `/etc`, shell profile, `PATH` or host package manager.
- `programs` is empty on purpose: `chrome.exe --version` prints nothing on Windows and a GUI browser would open a window under CI's probe.

## Using it with Playwright

These are the builds Playwright itself would download into `~/.cache/ms-playwright/`. Point Playwright at the shim's target with `executablePath`; matching the driver version (1.65.x) matters for Firefox and WebKit, whose patches speak Playwright's protocol. Not tested here.

## Verification

- Linux `x86_64`, isolated `XLINGS_HOME`: install, shim runs, remove leaves no shim.
- Not run: `linux` `aarch64`, `macosx`, `windows` (WebKit's Linux payload is checked for the linked `libavif.so.13`; the browser window itself is not opened). CI installs on all three platforms.

## Revision log

- 2026-11-26 — added at 27.2 (Playwright 1.65.1, revision 2388): initial `spec = "2"` recipe, CN published to GitCode with gtc.
