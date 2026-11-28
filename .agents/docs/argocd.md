# argocd

Declarative Continuous Deployment for Kubernetes (`argoproj/argo-cd`); provides the `argocd` CLI (status: `stable`).

- Upstream: https://github.com/argoproj/argo-cd (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream `v3.6.3` publishes no `windows-arm64` binary (upstream `linux-ppc64le` and `linux-s390x` binaries are also outside `package.archs`).

## Source

- Tier: upstream official repository release (`https://github.com/argoproj/argo-cd/releases`)
- GLOBAL:
  - `linux`: `https://github.com/argoproj/argo-cd/releases/download/v${version}/argocd-linux-${arch_alias}` (`amd64`, `arm64`)
  - `macosx`: `https://github.com/argoproj/argo-cd/releases/download/v${version}/argocd-darwin-${arch_alias}` (`amd64`, `arm64`)
  - `windows`: `https://github.com/argoproj/argo-cd/releases/download/v${version}/argocd-windows-${arch_alias}.exe` (`amd64`)
- CN: none yet (`ci = { mirror = true }`; CI will mirror to `xlings-res` after merge; every asset has a distinct filename with zero `materialize` basename collision)
- Checksums: taken from upstream `cli_checksums.txt` for `v3.6.3` and verified locally via `sha256sum` and GitHub release digests on all 5 downloaded binaries
- Auto-update: yes (`extensions.autoupdate` with `${tag}` pointing to `https://github.com/argoproj/argo-cd/releases`)

## Linking

- `linux/x86_64` and `linux/aarch64`: static Go ELF64 executables. Verified with `readelf -d` (no dynamic section), `readelf -l` (no `PT_INTERP`), and `ldd` ("not a dynamic executable"). Declares no `xim:glibc` or runtime library dependencies.
- `macosx/x86_64` and `macosx/aarch64`: Mach-O 64-bit executables (`x86_64` and `arm64`).
- `windows/x86_64`: PE32+ console executable (`x86-64`). PE import inspection shows only `kernel32.dll`, with no `VCRUNTIME140.dll` or `MSVCP140.dll`, so no `xim:vcruntime` dependency is required.

## What the hooks do

- `install`: checks that `pkginfo.install_file()` exists, clears and creates `pkginfo.install_dir()`, moves the downloaded raw binary to `argocd` (or `argocd.exe` when the payload ends in `.exe`), runs `chmod +x` on Unix, and verifies the target file exists.
- `config`: registers `argocd` with `xvm.add("argocd", { bindir = pkginfo.install_dir() })`.
- `uninstall`: calls `xvm.remove("argocd")`.
- System impact: none (no shell profile, `PATH`, or system configuration edits).

## Verification

- Verified on `linux/x86_64`:
  - `pytest tests/a/test_argocd.py -m "static or isolation"`
  - `tools/xpkg_ci.py inspect --only argocd`
  - Repo-wide static/isolation checks, `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`
  - Isolated `XLINGS_HOME` & `HOME`: `xlings config --add-xpkg pkgs/a/argocd.lua`, `xlings search argocd`, `xlings install local:argocd -y`, `argocd version --client`, `argocd --help`, `argocd completion bash`, `argocd /?`, `pytest tests/a/test_argocd.py -m "index or lifecycle or verify"`, and `xlings remove local:argocd -y`.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows/x86_64` runtime installs (not on host; covered by CI runners plus SHA-256, ELF/PE header, and `xpkg_ci.py inspect` verification for all 5 assets).

## Revision log

- 2026-11-26 — added at 3.6.3: initial spec-2 recipe using upstream single-file binaries for linux (x86_64, aarch64), macosx (x86_64, aarch64), and windows (x86_64).
