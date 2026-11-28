# protoc

Protocol Buffers compiler (`protoc`) with the bundled well-known `.proto` definitions (`include/google/protobuf/*.proto`). Status: `stable`.

- Upstream: https://github.com/protocolbuffers/protobuf (BSD-3-Clause, https://protobuf.dev)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). `windows/aarch64` is omitted because upstream publishes no Windows ARM64 release asset.

## Source

- Tier: upstream release (`protocolbuffers/protobuf` GitHub Releases)
- GLOBAL: `protoc-${version}-{linux-x86_64,linux-aarch_64,osx-x86_64,osx-aarch_64,win64}.zip`
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL assets to `xlings-res` after merge)
- Checksums: matched GitHub release asset digests and locally computed SHA-256 hashes on all five v36.2 archives
- Auto-update: yes (`extensions.autoupdate` with `${tag}` and `${version}`)

## Linking

- `linux` `x86_64` & `aarch64` (`bin/protoc`): statically linked ELF executables (`readelf -d`: no dynamic section, no `PT_INTERP`, zero `DT_NEEDED` entries). No `xim:glibc` or `xim:gcc-runtime` runtime dependency is needed.
- `windows` `x86_64` (`bin/protoc.exe`): PE32+ executable importing only Windows OS system DLLs (`ADVAPI32.dll`, `dbghelp.dll`, `KERNEL32.dll`, `msvcrt.dll`). No `xim:vcruntime` dependency is needed.
- `macosx` `x86_64` & `aarch64`: Mach-O 64-bit executables.

## What the hooks do

- install: extracts the flat `.zip` archive directly from `pkginfo.install_file()` into `pkginfo.install_dir()` (`System32\tar.exe` on Windows, `unzip -q -o` on POSIX) so `bin/` and `include/` stay isolated from `runtimedir`, runs `chmod +x` on POSIX, and checks `bin/protoc[.exe]` plus `include/google/protobuf/timestamp.proto`.
- config: registers `protoc` via `xvm.add("protoc", { bindir = pkginfo.install_dir() .. "/bin" })` so `protoc` finds `../include` relative to its executable.
- uninstall: `xvm.remove("protoc")`.
- System impact: none (self-contained under `pkginfo.install_dir()` and xvm shim).

## Verification

- Verified `xlings config --add-xpkg pkgs/p/protoc.lua`, `xlings search protoc`, `xlings install protoc@36.2 -y`, `protoc --version`, compiling a `.proto` importing `google/protobuf/timestamp.proto`, `dep-closure-check.sh`, idempotent reinstall, `xlings remove protoc -y`, and `pytest` suites on Linux `x86_64` in an isolated `XLINGS_HOME`.
- macOS (`x86_64`/`aarch64`), Linux `aarch64`, and Windows `x86_64` installs were not run locally (will run in GitHub Actions CI, except macOS `x86_64` which is resource-only).

## Revision log

- 2026-11-25 — added at `36.2` (upstream `v36.2`).
