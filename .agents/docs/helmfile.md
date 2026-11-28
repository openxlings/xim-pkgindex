# helmfile

Declaratively deploy Kubernetes manifests, Kustomize configs, and Charts as Helm releases. Provides the `helmfile` CLI (`stable`).

- Upstream: https://github.com/helmfile/helmfile (`MIT`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`); upstream `386` builds are omitted because `archs` only covers 64-bit targets.

## Source

- Tier: upstream release
- GLOBAL: `https://github.com/helmfile/helmfile/releases/download/v${version}/helmfile_${version}_{linux,darwin,windows}_${arch_alias}.tar.gz` (all six platforms ship `.tar.gz` flat archives)
- CN: none yet (declares `ci = { mirror = true }` so post-merge CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: taken from upstream `helmfile_1.8.5_checksums.txt` and verified against locally downloaded bytes for all six targets (all agreed)
- Auto-update: yes (`extensions.autoupdate` with `${tag}` and `${version}`)

## Linking

Static Go binary with zero external shared-library dependencies:
- Linux `x86_64` and `aarch64` ELFs: `readelf -d` shows no dynamic section; `ldd` reports `not a dynamic executable`. No `xim:glibc` or `xim:gcc-runtime` dependency.
- Windows `x86_64` (`0x8664`) and `aarch64` (`0xaa64`) PE32+ executables: import table contains `kernel32.dll` only (no `VCRUNTIME140.dll` / `MSVCP140.dll`, no `xim:vcruntime` dependency).
- Note: subcommands that render or apply charts (`list`, `template`, `apply`, `sync`, `show-dag`) invoke an external `helm` binary (`xim:helm` or `--helm-binary`), while `version` and `create` run standalone.

## What the hooks do

- install: extracts the flat `.tar.gz` directly into `install_dir()` (`tar -xf` + `chmod +x` on POSIX; `%SystemRoot%\System32\tar.exe -xf` on Windows) so files never mix in the shared `runtimedir`, with a move fallback if pre-extracted; asserts `helmfile`/`helmfile.exe` and `LICENSE` via `payload.require`.
- config: registers `helmfile` via `xvm.add("helmfile", { bindir = pkginfo.install_dir() })`.
- uninstall: removes `helmfile` via `xvm.remove("helmfile")`.
- System impact: none.

## Verification

- Static & isolation pytest (`tests/h/test_helmfile.py -m "static or isolation"`), repo core static suite, lint scripts, and `tools/xpkg_ci.py inspect/materialize` run on `linux/x86_64`.
- Isolated `XLINGS_HOME` & `HOME` lifecycle (`xlings install local:helmfile -y`, `helmfile --version`, `helmfile create`, `pytest -m "index or lifecycle or verify"`, `xlings remove`) verified on `linux/x86_64`.
- `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) not executed locally; verified archive layout, checksums, and ELF/PE headers/imports, with Windows extraction hook covered by Lua unit tests and CI.

## Revision log

- 2026-11-26 — added at `1.8.5`: initial release across `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`), flat `.tar.gz` extraction on all platforms.
