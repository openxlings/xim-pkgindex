# llama.cpp

LLM inference in C/C++ (`llama-cli`, `llama-server`), packaged at `b12720` (`stable`) from upstream CPU builds.

- Upstream: https://github.com/ggml-org/llama.cpp (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`). Windows `aarch64` is omitted until `xim:vcruntime` adds ARM64 CRT DLLs.

## Source

- Tier: official repository release (`ggml-org/llama.cpp`)
- GLOBAL: `https://github.com/ggml-org/llama.cpp/releases/download/${version}/llama-${version}-bin-...`
- CN: none yet (`ci = { mirror = true }` — CI mirrors GLOBAL assets to `xlings-res`)
- Checksums: computed locally from downloaded release archives and verified a second time via `tools/xpkg_ci.py materialize` + `verify` (upstream does not publish a checksum file).
- Auto-update: `extensions.autoupdate` declared (`${tag}` / `${version}` with `b12720`, validated by `autoupdate-ci.py audit`). Note: upstream marks `bXXXX` builds as GitHub prereleases across >10,000 releases.

## Linking

- Linux (`ubuntu-x64` / `ubuntu-arm64`): dynamic glibc ELFs (`RUNPATH=$ORIGIN` as shipped), linking `libc.so.6`, `libm.so.6`, `ld-linux-*.so.*` (`xim:glibc@>=2.39`), `libstdc++.so.6`, `libgcc_s.so.1`, `libgomp.so.1` (`xim:gcc-runtime`), and `libssl.so.3`, `libcrypto.so.3` (`xim:openssl@3.1.5`). `xim:patchelf@0.18.0` (`build` dep) restores `$ORIGIN` first alongside xlings' post-install closure RPATH in `config()` so bundled `libllama*.so*`, `libggml*.so*` (including `dlopen`'d CPU backends), and `libmtmd.so*` resolve without host fallback.
- macOS (`macos-x64` / `macos-arm64`): `@rpath` bundled `.dylib` files beside binaries + Apple system frameworks/libraries only.
- Windows (`win-cpu-x64`): bundles `libomp.dll` and `llama*.dll`/`ggml*.dll`; imports `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`, `MSVCP140.dll`, satisfied by copying `xim:vcruntime` DLLs app-local beside the `.exe`s.

## What the hooks do

- `install`: unpacks `llama-<version>/` on POSIX (flat `.zip` directly into `install_dir` on Windows, plus `xim:vcruntime` DLL copy), preserving all bundled `.so`/`.dylib`/`.dll` files beside `llama-cli` and `llama-server`.
- `config`: on Linux, prepends `$ORIGIN` (`--force-rpath`) onto ELFs in `install_dir`; registers `llama-cli`, `llama-server`, and `llama.cpp` (`type = "group"`) with `xvm`.
- `uninstall`: removes `llama-cli`, `llama-server`, and `llama.cpp` from `xvm`.
- System impact: none (self-contained in `$XLINGS_HOME`).

## Verification

- Linux `x86_64` (isolated `$XLINGS_HOME`): `xlings install`, `dep-closure-check.sh` (50 ELFs, 8 external sonames, exit 0), `ldd` (zero host libs / zero `not found`), `llama-cli --version` / `--help`, `llama-server --version` / `--help`, idempotent reinstall, `pytest tests/l/test_llamacpp.py`, and `xlings remove` all passed.
- Linux `aarch64`, macOS `x86_64`/`aarch64`, and Windows `x86_64`: not run locally (Linux `x86_64` host only); ELF/Mach-O/PE imports and archive hashes verified locally, native install deferred to CI runners.

## Revision log

- 2026-11-25 — added at `b12720`: initial CPU package for Linux, macOS, and Windows `x86_64`.
