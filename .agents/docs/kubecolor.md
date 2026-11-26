# kubecolor

Colorizes `kubectl` output (`kubecolor` CLI wrapper, `status = "stable"`).

- Upstream: https://github.com/kubecolor/kubecolor (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream `linux_386`, `linux_armv6`, and `windows_386` assets are not covered because `xim-pkgindex` targets `x86_64` and `aarch64`.

## Source

- Tier: upstream release (`kubecolor/kubecolor` GitHub Releases)
- GLOBAL: `https://github.com/kubecolor/kubecolor/releases/download/v${version}/kubecolor_${version}_<os>_${arch_alias}.<ext>` (`.tar.gz` for `linux`/`darwin`, `.zip` for `windows`)
- CN: none yet (`ci = { mirror = true }` declared; CI mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: all 6 SHA-256 digests matched upstream `checksums.txt` for `v0.9.0` and locally downloaded archive bytes
- Auto-update: yes (`extensions.autoupdate`, `GLOBAL`, `required = true`)

## Linking

- `linux/x86_64` & `linux/aarch64`: static Go ELF executables (`readelf -d` shows no `.dynamic` section); no `xim:glibc` needed.
- `windows/x86_64` & `windows/aarch64`: PE32+ console executables importing `kernel32.dll` only.
- `macosx/x86_64` & `macosx/aarch64`: Mach-O 64-bit executables.
- Runtime dependency: `xim:kubectl` (`kubecolor` invokes `kubectl` from `PATH` for all kubectl subcommands).

## What the hooks do

- install: extracts the flat archive directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` using `%SystemRoot%\System32\tar.exe` on Windows) and verifies `kubecolor` / `kubecolor.exe` via `payload.require`.
- config: registers `kubecolor` with `xvm.add("kubecolor", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `kubecolor` with `xvm.remove("kubecolor")`.
- System impact: none.

## Verification

- Verified `kubecolor@0.9.0` on `linux/x86_64` in isolated `XLINGS_HOME=/tmp/xlings-kubecolor`: `xlings config --add-xpkg`, `xlings search kubecolor`, `xlings install kubecolor@0.9.0 -y` (installed `kubecolor` + `xim:kubectl`), `kubecolor --kubecolor-version` (`0.9.0`), `kubecolor version --client`, `kubecolor /?` (non-blocking), `xlings remove kubecolor -y`, idempotency checks, and `pytest` (`static`, `isolation`, `index`, `lifecycle`, `verify`).
- Not run locally: `linux/aarch64`, `macosx/{x86_64,aarch64}`, and `windows/{x86_64,aarch64}` live installs (no local hosts for those targets; covered by CI after PR open).

## Revision log

- 2026-11-26 — added at `0.9.0`: initial spec-2 package with all 6 platform/arch assets, `xim:kubectl` runtime dep, and `extensions.autoupdate`.
