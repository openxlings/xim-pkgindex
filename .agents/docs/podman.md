# podman

Daemonless OCI container and pod engine (`podman`), status `stable`.

- Upstream: https://podman.io / https://github.com/podman-container-tools/podman (`Apache-2.0`)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`aarch64`), `windows` (`x86_64`, `aarch64`). `macosx/x86_64` is omitted because upstream Podman 6.x no longer publishes Intel macOS archives.

## Source

- Tier: mixed by platform (explicitly documented):
  - `macosx` (`aarch64`) and `windows` (`x86_64`, `aarch64`): Tier 1 — official upstream release (`podman-container-tools/podman` GitHub Releases, `v6.2.1`).
  - `linux` (`x86_64`, `aarch64`): Tier 2 — well-known third-party static build (`mgoltzsche/podman-static`, Apache-2.0, GPG-signed, tracks exact upstream tags). Official `podman-container-tools/podman` releases publish only the client-only `podman-remote-static` binary on Linux and no standalone local container engine tarball.
- GLOBAL:
  - `linux`: `https://github.com/mgoltzsche/podman-static/releases/download/v${version}/podman-linux-${arch_alias}.tar.gz`
  - `macosx`: `https://github.com/podman-container-tools/podman/releases/download/v${version}/podman-remote-release-darwin_${arch_alias}.zip`
  - `windows`: `https://github.com/podman-container-tools/podman/releases/download/v${version}/podman-remote-release-windows_${arch_alias}.zip`
- CN: none yet (`ci = { mirror = true }` declared for `xlings-res` mirroring)
- Checksums: all 5 archive SHA-256 digests verified against upstream `shasums` / GitHub Release asset digests for `v6.2.1` and local `sha256sum` of downloaded archives.
- Auto-update: yes (`extensions.autoupdate` tracking `podman-container-tools/podman/releases` with `GLOBAL.required = true` across all 5 URLs so updates advance only after both upstream and `mgoltzsche/podman-static` publish matching `${tag}` assets).

## Linking

- `linux/x86_64` and `linux/aarch64`: every binary in the bundle (`podman`, `crun`, `runc`, `conmon`, `netavark`, `aardvark-dns`, `passt`/`pasta`, `catatonit`, `fuse-overlayfs`, `fusermount3`, `rootlessport`, `quadlet`) is statically linked (`static` or `static-pie`, zero `DT_NEEDED`). Declares no `xim:glibc` dependency.
- `macosx/aarch64`: Mach-O 64-bit `arm64` executables (`podman`, `podman-mac-helper`).
- `windows/x86_64` and `windows/aarch64`: PE32+ executables (`podman.exe`, `gvproxy.exe`, `win-sshproxy.exe`) importing only `kernel32.dll` (no `VCRUNTIME140.dll`). Declares no `xim:vcruntime` dependency.

## What the hooks do

- install: unpacks `podman-linux-{amd64,arm64}` (Linux) or `podman-<version>` (macOS/Windows) into `pkginfo.install_dir()` via `payload.unpack`. On Linux, writes a relocatable `etc/containers/xlings-containers.conf` pointing `seccomp_profile`, `init_path`, `helper_binaries_dir`, `conmon_path`, and `crun`/`runc` runtime paths inside `pkginfo.install_dir()`. On macOS, runs `chmod +x` on `usr/bin/podman` and `usr/bin/podman-mac-helper`. Verifies the complete per-platform file set with `payload.require`.
- config: registers `podman` via `xvm.add`. On Linux, points `bindir` at `usr/local/bin` and attaches `CONTAINERS_CONF`, `CONTAINERS_POLICY_JSON`, and `CONTAINERS_REGISTRIES_CONF` pointing into `pkginfo.install_dir()/etc/containers/` so local rootless containers work without modifying `/etc/containers` or `/usr/local`. Bundled `pasta`/`passt` stay private inside the payload (not registered in xvm) to avoid colliding with `xim:passt`. On macOS/Windows, points `bindir` at `usr/bin` (keeping helper binaries `podman-mac-helper` / `gvproxy.exe` / `win-sshproxy.exe` beside `podman`).
- uninstall: removes `podman` via `xvm.remove`.
- System impact: none (self-contained in `pkginfo.install_dir()` and xvm shims; running rootless containers on Linux uses host kernel user namespaces and `/etc/subuid`, `/etc/subgid`, `newuidmap`/`newgidmap` when present).

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search podman`, `xlings install local:podman@6.2.1 -y`, `which podman`, `podman --version`, `podman --help`, `podman completion bash`, `podman info`, offline `podman import` + `podman run --rm` rootless container execution, idempotent reinstall, `xlings remove`, plus `pytest tests/p/test_podman.py`, repository-wide static/isolation tests, `.github/scripts/check-*.sh`, `tools/lint_exec_quoting.sh`, `tools/xpkg_ci.py inspect/materialize`, and `xpkgindex-update` audit/check.
- Not run locally: `linux/aarch64`, `macosx/aarch64`, `windows/x86_64`, and `windows/aarch64` runtime installs (covered by archive digest/layout/binary inspection, Lua sandbox hook tests, and GitHub Actions CI).

## Revision log

- 2026-11-26 — added at `6.2.1`: full static Linux stack (`mgoltzsche/podman-static`, `x86_64` and `aarch64`) with relocatable `xlings-containers.conf`, plus official `podman-container-tools/podman` standalone archives for `macosx` (`aarch64`) and `windows` (`x86_64`, `aarch64`).
