# minikube

minikube runs a local Kubernetes cluster inside a container or VM and provides the
`minikube` command for cluster lifecycle, dashboard and addon management. Status: stable.

- Upstream: https://github.com/kubernetes/minikube (Apache-2.0)
- Namespace: `xim`
- Platforms: linux x86_64/aarch64, macosx aarch64, windows x86_64. Windows ARM64 is
  omitted because upstream v1.39.0 publishes no matching CLI asset.

## Source

- Tier: upstream release
- GLOBAL: `https://github.com/kubernetes/minikube/releases/download/v${version}/minikube-linux-${arch_alias}`
  (linux/macOS raw binaries, `minikube-windows-${arch_alias}.exe` on Windows)
- CN: none yet
- Checksums: each sha256 was taken from the upstream release's `.sha256` sidecar and
  cross-checked against the GitHub release API digest of the same asset.
- Auto-update: yes (`extensions.autoupdate`, GLOBAL only; no CN leg).

## Linking

The linux x86_64 payload is dynamically linked against the host glibc (interpreter
`/lib64/ld-linux-x86-64.so.2`, `NEEDED` libc/libpthread/libresolv/libdl) and deliberately
declares no `xim:` dependency; the linux aarch64 payload is static. macOS and Windows
payloads use system libraries only. This host-interpreter linkage is intentional and
documented by the packager.

## What the hooks do

- install: place the single binary into the install directory and `chmod +x`; nothing is
  unpacked or relocated.
- config: `xvm.add("minikube")`.
- uninstall: `xvm.remove("minikube")`.
- System impact: none (no PATH, shell profile, or configuration changes).

## Verification

- CI green at review time: static-and-isolation, index-registration, install on
  linux/macosx/windows.
- The author ran `check-revision.sh` and `xpkgindex-update inspect`/`check` on the recipe.
- Not run: real cluster creation — the tests install and exercise the CLI, not a full
  cluster inside a VM/container driver.

## Revision log

- 2026-11-27 — added at 1.39.0: raw upstream CLI binaries; checksums double-verified
  (sidecar + API digest); Windows ARM64 skipped for lack of an upstream asset.
