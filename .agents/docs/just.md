# just

Command runner (`just`) for saving and running project-specific recipes (`justfile`), status `stable`.

- Upstream: https://github.com/casey/just (`CC0-1.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). All official prebuilt release platforms/architectures covered by desktop/server targets (`arm`, `armv7`, `loongarch64`, `riscv64gc` Linux targets are omitted as outside `package.archs`).

## Source

- Tier: upstream release (`casey/just` GitHub Releases)
- GLOBAL: `https://github.com/casey/just/releases/download/${tag}/just-${version}-<target>.{tar.gz,zip}`
- CN: none yet (`ci = { mirror = true }` declared for `xlings-res` mirroring)
- Checksums: `SHA256SUMS` published in `casey/just` release `1.59.0`; all 6 downloaded archive hashes verified to match `SHA256SUMS`
- Auto-update: yes (`extensions.autoupdate` using `${tag}` / `${version}`)

## Linking

- Linux `x86_64`: `static-pie linked` musl ELF with zero `DT_NEEDED` entries (`ldd`: `statically linked`). Declares no `deps`.
- Linux `aarch64`: `statically linked` musl ELF with no `.dynamic` section. Declares no `deps`.
- Windows `x86_64` and `aarch64`: PE32+ binaries linked with static CRT, importing only Windows OS DLLs (`bcryptprimitives.dll`, `kernel32.dll`, `api-ms-win-core-synch-l1-2-0.dll`, `userenv.dll`, `shell32.dll`, `combase.dll`, `ntdll.dll`); no `VCRUNTIME140.dll` import or delay-load import. Declares no `xim:vcruntime`.

## What the hooks do

- install: upstream archives are flat at root (`just`/`just.exe`, `just.1`, `LICENSE`, `README.md`, `GRAMMAR.md`, `Cargo.toml`, `Cargo.lock`, `completions/`). On POSIX, unpacks the `.tar.gz` directly into `pkginfo.install_dir()` via `tar -xzf` and runs `chmod +x`; on Windows, unpacks the `.zip` into `pkginfo.install_dir()` via `payload.unpack{}` (`System32\tar.exe`). Asserts `just` / `just.exe` via `payload.require`.
- config: registers `just` via `xvm.add("just", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `just` via `xvm.remove("just")`.
- System impact: none.

## Verification

- Verified locally on Linux `x86_64`: `pytest tests/j/test_just.py -m "static or isolation" -v`, `pytest tests/j/test_just.py -m index -v`, `XLINGS_TEST_SUBOS=default pytest tests/j/test_just.py -m verify -v`, repo-wide static checks, and `xlings install`/`just --version`/recipe execution/`xlings remove` lifecycle.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime installs (covered by binary inspection + Lua sandbox hook tests + GitHub Actions CI for `linux`, `macosx/aarch64`, `windows/x86_64`).

## Revision log

- 2026-11-25 — added at `1.59.0`: static musl binaries on Linux (`x86_64`/`aarch64`), static-CRT PE binaries on Windows (`x86_64`/`aarch64`), flat archive extraction directly into `install_dir`.
