# buf

`buf` is the CLI for working with Protocol Buffers (linting, breaking change detection, formatting, code generation, and BSR management). Status: `stable`.

- Upstream: https://github.com/bufbuild/buf (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`)

## Source

- Tier: upstream release (`bufbuild/buf`)
- GLOBAL: `https://github.com/bufbuild/buf/releases/download/v${version}/buf-<OS>-<ARCH>.{tar.gz,zip}`
- CN: none yet (`ci = { mirror = true }`)
- Checksums: verified against upstream `sha256.txt` and downloaded archives for `v1.75.0`
- Auto-update: yes (`extensions.autoupdate` using `${tag}`)

## Linking

- Linux (`x86_64`, `aarch64`): all three binaries (`buf`, `protoc-gen-buf-lint`, `protoc-gen-buf-breaking`) are statically linked Go executables (`readelf -d` shows no dynamic section; `ldd` reports not a dynamic executable). No runtime dependencies declared.
- Windows (`x86_64`, `arm64`): PE32+ executables (`0x8664`, `0xaa64`) import only `kernel32.dll`. No `xim:vcruntime` dependency needed.

## What the hooks do

- `install`: unpacks the `buf/` directory via `payload.unpack{ extracted = "buf", strip = 1 }` and verifies `bin/buf[.exe]`, `bin/protoc-gen-buf-lint[.exe]`, `bin/protoc-gen-buf-breaking[.exe]`, and `LICENSE`.
- `config`: registers `buf`, `protoc-gen-buf-lint` (`binding = "buf@<version>"`), and `protoc-gen-buf-breaking` (`binding = "buf@<version>"`) via `xvm.add` from `<install_dir>/bin`.
- `uninstall`: removes `protoc-gen-buf-breaking`, `protoc-gen-buf-lint`, and `buf` via `xvm.remove`.
- System impact: none; isolated to `<install_dir>` and subos xvm shims.

## Verification

- `linux` `x86_64`: installed `local:buf@1.75.0`, verified `buf --version` (`1.75.0`), verified `buf lint` on a valid `buf.yaml` + `hello/v1/hello.proto`, verified `protoc-gen-buf-lint` and `protoc-gen-buf-breaking` shims execute, removed cleanly with zero leftover shims.
- `pytest tests/b/test_buf.py -m "static or isolation" -v`: 14 passed.
- `XLINGS_TEST_SUBOS=default pytest tests/b/test_buf.py -m verify -v`: 3 passed.
- `pytest tests/b/test_buf.py -m index -v`: 1 passed.
- Not run locally: `linux/aarch64`, `macosx`, and `windows` runtime installs (covered by CI; ELF/PE inspection and archive SHA256 checks ran locally for all 6 targets).

## Revision log

- 2026-11-25 — added at `1.75.0`: initial spec-2 recipe covering all 6 upstream archive targets (`Linux`, `Darwin`, `Windows` x `x86_64`/`aarch64`).
