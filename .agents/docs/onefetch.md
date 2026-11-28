# onefetch

Onefetch reports Git repository language statistics and history. The 3.3.0 package is stable and provides the `onefetch` command.

- Upstream: https://github.com/o2sh/onefetch (MIT)
- Namespace: `xim`
- Platforms: Linux x86_64, macOS arm64/aarch64, and Windows x86_64. Other CPU/platform combinations have no matching 3.3.0 upstream asset.

## Source

- Tier: upstream GitHub release 3.3.0
- GLOBAL: `https://github.com/o2sh/onefetch/releases/download/${tag}/onefetch-{linux,mac,win}.tar.gz` (platform-specific templates are in the recipe)
- CN: none yet (no verified mirror)
- Checksums: downloaded release archives agreed with the SHA256 `digest` values in the official GitHub release metadata: Linux `664ca61395157d722cd70eb20549d250b36cfcf4a71aae5229bd928b8afd2301`, macOS `ce507fcd2ca993c73acc247a0acc831924b55cd8d9e20efca0e2ba7fad962620`, Windows `3b900747d75195fbfdc04cdd6c8f858d72918c67cba178526f26d68ab69f9653`.
- Auto-update: yes (`extensions.autoupdate`), GLOBAL only.

## Linking

Linux is a dynamic x86_64 ELF using `libgcc_s.so.1`, `libm.so.6`, and `libc.so.6`; it declares `xim:glibc@>=2.39` and `xim:gcc-runtime@15.1.0`. macOS uses system libraries. Windows imports `VCRUNTIME140.dll` and declares `xim:vcruntime`; the recipe copies the dependency provider's complete `bin` file set beside the executable rather than naming or bundling a compiler runtime in the release archive.

## What the hooks do

- install: extract the flat archive into the package directory, write the upstream MIT notice as `LICENSE.md`, make POSIX payloads executable, and require every installed file.
- config: register `onefetch` with xvm.
- uninstall: remove the xvm registration; xlings removes the managed payload.
- System impact: none outside the package directory and xlings metadata.

## Verification

Focused `pytest -q tests/o/test_onefetch.py` passed 9 tests on Linux x86_64 after the final test-driver/runtime repair. The compiler-runtime policy test passed 2 tests. A fresh isolated Linux home, with both `XLINGS_SUBOS_LIB` and `XLINGS_SUBOS_LIBS` set to the temporary SubOS library directory, initialized the copied xlings client, installed the local recipe, ran the generated `onefetch` shim (`onefetch 3.3.0`), and removed it; the payload and shim were absent afterward. Native macOS arm64 and Windows x86_64 execution remains CI coverage.

## Revision log

- 2026-11-27 — added at 3.3.0: upstream portable archives, explicit platform matrix, Linux runtime closure, and dependency-managed Windows CRT deployment.
