# kustomize

Kubernetes YAML configuration customization CLI (`kustomize`), `status = "stable"`.

- Upstream: https://github.com/kubernetes-sigs/kustomize (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `linux_ppc64le` and `linux_s390x`, omitted because `archs` only covers `x86_64` and `aarch64`.

## Source

- Tier: official repository release (`kubernetes-sigs/kustomize`, monorepo tag `kustomize/v<version>`)
- GLOBAL: `https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${version}/kustomize_v${version}_<os>_<arch_alias>.<ext>` (`linux`/`darwin` `.tar.gz`, `windows` `.zip`)
- CN: none yet (`ci = { mirror = true }`, maintainer CI will mirror to `xlings-res`)
- Checksums: taken from upstream `checksums.txt` on `kustomize/v5.8.3` and verified against downloaded bytes for all 6 archives
- Auto-update: yes (`extensions.autoupdate` with `tag = "kustomize/v${version}"`, ignoring sibling monorepo tags like `kyaml/v*`, `api/v*`, `cmd/config/v*`)

## Linking

- `linux/x86_64` and `linux/aarch64`: statically linked Go ELFs (`no .dynamic section`, no `INTERP`); no `xim:glibc` or `xim:gcc-runtime` dependency.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables.
- `windows/x86_64` and `windows/aarch64`: PE32+ console executables importing `kernel32.dll` only; no `xim:vcruntime` dependency.

## What the hooks do

- `install`: extracts the flat upstream archive directly into `pkginfo.install_dir()` (`tar -xzf` + `chmod +x` on POSIX; `libs/payload.lua` `payload.unpack{}` -> `%SystemRoot%\System32\tar.exe` on Windows) so shared download directories cannot leak files from other flat archives, then asserts the executable with `payload.require`.
- `config`: registers `kustomize` with `xvm.add("kustomize", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("kustomize")`.
- System impact: none; only writes inside `pkginfo.install_dir()` and registers the `xvm` shim.

## Verification

- Verified `kustomize/v5.8.3` download URLs, SHA256s, archive layouts, ELF headers (`readelf -d`, `readelf -l`, `ldd`), and PE imports.
- Ran static, isolation, index, lifecycle, and verify pytest suites, repository checks, `tools/xpkg_ci.py inspect/materialize`, `autoupdate-ci.py audit`, and isolated `XLINGS_HOME` install/version/build/remove on `linux/x86_64`.
- Not run locally: `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`), and `linux/aarch64` native execution (no local hosts for those targets; covered by CI runners for `linux/aarch64`, `macosx/aarch64`, and `windows/x86_64`).

## Revision log

- 2026-11-26 — added at `5.8.3`: monorepo release tags `kustomize/v5.8.3` with flat single-binary archives and static Linux/Windows payloads.
