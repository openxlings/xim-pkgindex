# redis

In-memory key-value data structure store, cache, and message broker (`redis-server`, `redis-cli`, `redis-benchmark`, `redis-check-aof`, `redis-check-rdb`, `redis-sentinel`), `status = "stable"`.

- Upstream: https://redis.io / https://github.com/redis/redis (RSALv2, SSPLv1, AGPLv3)
- Namespace: `xim`
- Platforms: `windows` (`x86_64`). `linux` and `macosx` are intentionally omitted because official `redis/redis` releases publish source tarballs only and install-time compilation is disallowed; POSIX support awaits prebuilt musl-static / static binaries published via `tools/res/build.sh` (#1295) to `xlings-res`.

## Source

- Tier: well-known third-party release (`redis-windows/redis-windows`, official Redis distributes no Windows builds)
- GLOBAL: `https://github.com/redis-windows/redis-windows/releases/download/${version}/Redis-${version}-Windows-x64-msys2.zip`
- CN: none yet (`ci = { mirror = true }` declared)
- Checksums: verified `af16df340525b431e9ec8dabfd625d5e7a233f82805b5418819904ea909c447f` against GitHub release asset digest for `redis-windows/redis-windows@8.10.3` and local `sha256sum` on the downloaded `Redis-8.10.3-Windows-x64-msys2.zip` archive.
- Auto-update: yes (`extensions.autoupdate` tracking `redis-windows/redis-windows/releases` with exact version tags `${version}`).

## Linking

- `windows/x86_64`: self-contained MSYS2 build with `BUILD_TLS=yes`. The archive bundles all 5 MSYS2/OpenSSL/C++ runtime DLLs alongside the 6 executables at the root (`msys-2.0.dll`, `msys-crypto-3.dll`, `msys-gcc_s-seh-1.dll`, `msys-ssl-3.dll`, `msys-stdc++-6.dll`), so it has no MSVC CRT dependency and declares no `xim:vcruntime` dependency.

## What the hooks do

- install: unpacks `Redis-<ver>-Windows-x64-msys2.zip` with `payload.unpack{ extracted = "Redis-" .. ver .. "-Windows-x64-msys2", strip = 1 }` into `pkginfo.install_dir()` and verifies all 6 `.exe` binaries plus `redis.conf` and `sentinel.conf` via `payload.require`.
- config: registers `redis-server` at `bindir = pkginfo.install_dir()` and the 5 sibling programs (`redis-cli`, `redis-benchmark`, `redis-check-aof`, `redis-check-rdb`, `redis-sentinel`) with `binding = "redis-server@" .. pkginfo.version()`.
- uninstall: removes all 6 registered xvm entries in reverse order.
- System impact: none (self-contained in `pkginfo.install_dir()` and xvm shims).

## Verification

- Verified locally on Linux (`x86_64`): archive download & `sha256sum`, zip layout inspection (17 entries under `Redis-8.10.3-Windows-x64-msys2/`), `pytest` static/isolation/index suites (with Lua sandbox mocks for `install()`, `installed()`, `config()`, and `uninstall()`), repo-wide static checks, `lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `python3 tools/xpkg_ci.py inspect --only redis`.
- Windows `x86_64` native install, binary execution, and uninstall were not run locally (Linux host) and are covered by Windows CI.

## Revision log

- 2026-11-26 — added at 8.10.3 for `windows` (`x86_64`) using self-contained `redis-windows` MSYS2 payload; dropped install-time POSIX source builds pending `xlings-res` factory artifacts.
