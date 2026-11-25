# dart-sdk

The Dart SDK (`dart` CLI, Dart VM, AOT runtime, analyzer, `pub`, and compilers). Status: `stable`.

- Upstream: https://dart.dev (BSD-3-Clause, https://github.com/dart-lang/sdk)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream official release archive (`storage.googleapis.com/dart-archive`)
- GLOBAL:
  - `linux`: `https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-linux-${arch_alias}-release.zip`
  - `macosx`: `https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-macos-${arch_alias}-release.zip`
  - `windows`: `https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-windows-${arch_alias}-release.zip`
- CN: none declared (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res`).
- Checksums: fetched from official `.sha256sum` sidecars at `channels/stable/release/3.14.1/sdk/*.zip.sha256sum`; `linux/x86_64`, `linux/aarch64`, and `windows/x86_64` archives were also downloaded and hashed locally with matching SHA256 digests.
- Auto-update: no. `dart-lang/sdk` on GitHub has no GitHub Releases and carries 89+ pages of tags (exceeding `xpkgindex-update`'s 50-request per-package budget), while `channels/stable/release/latest/VERSION` is JSON rather than a supported GitHub or Sparkle XML feed (same as `flutter.lua`).

## Linking

- Linux (`3.14.1`, `readelf -d`):
  - `x86_64`: `INTERP /lib64/ld-linux-x86-64.so.2`; `NEEDED`: `libdl.so.2`, `libpthread.so.0`, `libm.so.6`, `libc.so.6`, `ld-linux-x86-64.so.2` (plus `librt.so.1`, `libresolv.so.2` on sanitizer runtimes).
  - `aarch64`: `INTERP /lib/ld-linux-aarch64.so.1`; `NEEDED`: `libm.so.6`, `libc.so.6` (plus `libresolv.so.2` on sanitizer runtimes).
  - Declares `deps = { runtime = { "xim:glibc@>=2.39" } }`; no `libstdc++` or `libgcc_s` dependency.
- Windows (`3.14.1` `x86_64` PE import inspection):
  - `dart.exe`, `dartaotruntime.exe`, `dartvm.exe`, `utils/gen_snapshot.exe`, and `utils/wasm-opt.exe` statically link the MSVC CRT and import only Windows OS system DLLs (`KERNEL32`, `ntdll`, `ADVAPI32`, `WS2_32`, `ole32`, `OLEAUT32`, `SHELL32`, `SHLWAPI`, `IPHLPAPI`, `PSAPI`, `RPCRT4`, `bcrypt`, `CRYPT32`, `dbghelp`, `api-ms-win-core-path-l1-1-0`). No `xim:vcruntime` dependency needed.

## What the hooks do

- `install`: calls `payload.unpack{ extracted = "dart-sdk", strip = 1 }` to preserve the full `dart-sdk/` directory tree (needed for `bin/snapshots/`, `bin/utils/`, `lib/`), marks POSIX executables `+x`, and asserts required binaries/snapshots/version file via `payload.require`.
- `config`: registers `dart-sdk` (`type = "group"`) and `dart` (`bindir = pkginfo.install_dir() .. "/bin"`, `binding = "dart-sdk@" .. pkginfo.version()`).
- `uninstall`: removes `dart` and `dart-sdk` from xvm.
- System impact: none; no shell profile, `PATH`, or host package manager modifications.

## Verification

- `linux/x86_64`: verified locally in isolated `XLINGS_HOME` (`xlings config --add-xpkg`, `xlings install`, `dep-closure-check.sh`, `dart --version`, `dart run`, `dart analyze`, `dart compile exe`, `xlings remove`, `xlings config --remove-xpkg`) and `pytest tests/d/test_dart_sdk.py`.
- `linux/aarch64`, `macosx`, `windows`: not run locally (to be covered by CI).

## Revision log

- 2026-11-25 — added at `3.14.1` across `linux`, `macosx`, and `windows` (`x86_64`, `aarch64`).
