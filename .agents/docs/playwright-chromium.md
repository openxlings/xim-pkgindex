# playwright-chromium

Chrome for Testing build of Chromium that Playwright drives (`playwright-chromium` shim, `status = "stable"`). Version `159.0.8154.6` is the browser's own version; Playwright 1.65.1 pins it as revision `1255`.

- Upstream: https://github.com/microsoft/playwright (Apache-2.0); the browser is `BSD-3-Clause`
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Playwright publishes no Windows ARM64 build of any of these.

## Source

- Tier: the Playwright project's own build (Google's Chrome for Testing, rebuilt per Playwright release (the `builds/cft/<version>` tree)).
- GLOBAL: `https://cdn.playwright.dev/builds/...` (the host Playwright's registry downloads from).
- CN: `https://gitcode.com/xlings-res/playwright-chromium/releases/download/159.0.8154.6/<file>`, the upstream bytes under the upstream file names, published with `gtc`, each file with a `.sha256` sidecar.
- Checksums: Playwright publishes none. Each was computed from a first download and equals a second download of Google's `chrome-for-testing-public` bucket. The CN copy was downloaded back and compared with `cmp`.
- Auto-update: no. There is no release feed; versions move with Playwright's `browsers.json`. `ci.mirror` is not declared because the CN copy already exists.

## Linking

Dynamic glibc binaries on the host's loader and libraries; no `deps`, as `zed.lua` and `blender.lua`. Declaring `xim:glibc` would make elfpatch rewrite the loader and the browser would lose the host's `ld.so.cache`.
`chrome` needs the usual NSS, GLib, ATK, ALSA, X11 and Mesa libraries from the host (`readelf -d`: `libnss3`, `libgbm`, `libasound`, `libcups`, ...).

## What the hooks do

- install: `payload.unpack` moves the archive's one top-level directory into place, `chmod +x` on the executable, and an assertion that the platform's executable exists; on macOS also that the app bundle's `Versions/Current` symlink survived.
- config: registers one shim `playwright-chromium` (`xvm.add` with `alias`) for the platform's executable.
- uninstall: `xvm.remove("playwright-chromium")`.
- System impact: none outside the package's own directory. No `/etc`, shell profile, `PATH` or host package manager.
- `programs` is empty on purpose: `chrome.exe --version` prints nothing on Windows and a GUI browser would open a window under CI's probe.

## Using it with Playwright

These are the builds Playwright itself would download into `~/.cache/ms-playwright/`. Point Playwright at the shim's target with `executablePath`; matching the driver version (1.65.x) matters for Firefox and WebKit, whose patches speak Playwright's protocol. Not tested here.

## Verification

- Linux `x86_64`, isolated `XLINGS_HOME`: install, shim runs (`--version` prints `Google Chrome for Testing 159.0.8154.6`), remove leaves no shim.
- Not run: `linux` `aarch64`, `macosx`, `windows`. CI installs on all three platforms.

## Revision log

- 2026-11-26 — added at 159.0.8154.6 (Playwright 1.65.1, revision 1255): initial `spec = "2"` recipe, CN published to GitCode with gtc.
