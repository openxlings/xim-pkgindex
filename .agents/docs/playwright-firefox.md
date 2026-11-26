# playwright-firefox

Firefox build with the patches that let Playwright drive it (`playwright-firefox` shim, `status = "stable"`). Version `159.0` is the browser's own version; Playwright 1.65.1 pins it as revision `1572`.

- Upstream: https://github.com/microsoft/playwright (Apache-2.0); the browser is `MPL-2.0`
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Playwright publishes no Windows ARM64 build of any of these.

## Source

- Tier: the Playwright project's own build (Playwright's patched Firefox (`builds/firefox/<revision>`), not Mozilla's own release).
- GLOBAL: `https://cdn.playwright.dev/builds/...` (the host Playwright's registry downloads from).
- CN: `https://gitcode.com/xlings-res/playwright-firefox/releases/download/159.0/<file>`, the upstream bytes under the upstream file names, published with `gtc`, each file with a `.sha256` sidecar.
- Checksums: Playwright publishes none. Each was computed from a first download and equals a second download from `playwright.download.prss.microsoft.com`. The CN copy was downloaded back and compared with `cmp`.
- Auto-update: no. There is no release feed; versions move with Playwright's `browsers.json`. `ci.mirror` is not declared because the CN copy already exists.

## Linking

Dynamic glibc binaries on the host's loader and libraries; no `deps`, as `zed.lua` and `blender.lua`. Declaring `xim:glibc` would make elfpatch rewrite the loader and the browser would lose the host's `ld.so.cache`.
`firefox` resolves everything but glibc, libstdc++ and GTK from its own directory.

## What the hooks do

- install: `payload.unpack` moves the archive's one top-level directory into place, `chmod +x` on the executable, and an assertion that the platform's executable exists.
- config: registers one shim `playwright-firefox` (`xvm.add` with `alias`) for the platform's executable.
- uninstall: `xvm.remove("playwright-firefox")`.
- System impact: none outside the package's own directory. No `/etc`, shell profile, `PATH` or host package manager.
- `programs` is empty on purpose: `chrome.exe --version` prints nothing on Windows and a GUI browser would open a window under CI's probe.

## Using it with Playwright

These are the builds Playwright itself would download into `~/.cache/ms-playwright/`. Point Playwright at the shim's target with `executablePath`; matching the driver version (1.65.x) matters for Firefox and WebKit, whose patches speak Playwright's protocol. Not tested here.

## Verification

- Linux `x86_64`, isolated `XLINGS_HOME`: install, shim runs (`--version` prints `Mozilla Firefox 159.0`), remove leaves no shim.
- Not run: `linux` `aarch64`, `macosx`, `windows`. CI installs on all three platforms.

## Revision log

- 2026-11-26 — added at 159.0 (Playwright 1.65.1, revision 1572): initial `spec = "2"` recipe, CN published to GitCode with gtc.
