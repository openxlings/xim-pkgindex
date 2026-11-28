# etcd

Distributed reliable key-value store (`etcd`, `etcdctl`, `etcdutl`), `status = "stable"`.

- Upstream: https://etcd.io / https://github.com/etcd-io/etcd (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows` `aarch64` is omitted because upstream v3.7.4 publishes no Windows ARM64 asset; `linux` `ppc64le`/`s390x` are omitted as xlings does not target them.

## Source

- Tier: upstream release (`https://github.com/etcd-io/etcd/releases`)
- GLOBAL: `etcd-v${version}-linux-{amd64,arm64}.tar.gz`, `etcd-v${version}-darwin-{amd64,arm64}.zip`, `etcd-v${version}-windows-amd64.zip`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: taken from upstream `SHA256SUMS` for `v3.7.4` and verified locally via `sha256sum -c SHA256SUMS` against all five downloaded archives.
- Auto-update: yes (`extensions.autoupdate` using `${tag}` and `${version}`).

## Linking

- Linux (`x86_64`, `aarch64`): all three binaries (`etcd`, `etcdctl`, `etcdutl`) are statically linked Go ELF executables with no `DYNAMIC` section (`readelf -d` reports `There is no dynamic section in this file.`, `ldd` reports not a dynamic executable). Zero `runtime` dependencies declared.
- Windows (`x86_64`): all three PE32+ executables (`etcd.exe`, `etcdctl.exe`, `etcdutl.exe`) import only `kernel32.dll` (no VCRUNTIME or MinGW DLL dependencies).

## What the hooks do

- install: unpacks `etcd-v<version>-<os>-<arch>/` into `pkginfo.install_dir()` via `payload.unpack` (handles both pre-extracted directory moves and Windows `.zip` extraction via `System32\tar.exe` fallback), and asserts all three binaries via `payload.require`.
- config: registers `etcd` as the root program (`xvm.add("etcd", { bindir = pkginfo.install_dir() })`) and `etcdctl` and `etcdutl` with `binding = "etcd@" .. pkginfo.version()`.
- uninstall: removes `etcdutl`, `etcdctl`, and `etcd` via `xvm.remove`.
- System impact: none outside `$XLINGS_HOME`.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search etcd`, `xlings install etcd@3.7.4 -y`, `etcd --version`, `etcdctl version`, `etcdutl version`, `xlings list etcd`, idempotent reinstall, `xlings remove etcd -y`, and `xlings config --remove-xpkg etcd`.
- Ran `pytest tests/e/test_etcd.py` across `static`, `isolation`, `index`, `lifecycle`, and `verify` (including a live local `etcd` + `etcdctl` put/get round-trip).
- Not run locally: `macosx` (`x86_64`, `aarch64`), `linux` (`aarch64`), and `windows` (`x86_64`) runtime installs (no native hosts locally; macOS `.zip` and Windows `.zip` hooks were exercised via Lua unit tests, and CI validates Linux `x86_64`/`aarch64`, macOS `aarch64`, and Windows `x86_64`).

## Revision log

- 2026-11-25 — added at 3.7.4: initial `spec = "2"` recipe covering Linux x86_64/aarch64, macOS x86_64/aarch64, and Windows x86_64 with `etcd`, `etcdctl`, and `etcdutl`.
