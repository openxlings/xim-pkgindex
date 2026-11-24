---
name: llvm-subpackaging
description: LLVM all-platform sub-packaging spec / design / SOP. Carves the upstream monolithic LLVM toolchain into two self-contained packages — `llvm` (slim self-contained toolchain = compiler + lld + binutils + libc++ + compiler-rt) and `llvm-tools` (clang-format/tidy/clangd) — and publishes them to the xlings-res dual mirrors (GitHub gh + GitCode gtc). Use it to add/align the llvm package for a platform, upgrade versions, and keep linux/macosx/windows consistent.
---

# LLVM Sub-packaging Spec / SOP (2-package model)

Carve the upstream **1.4–2GB monolithic** LLVM bundle into two single-purpose, **self-contained** packages, so users install only what they need
instead of pulling the whole bundle every time (which also carries 1.2GB of unused static libraries + lldb + all extra tools).

> Detailed manifests and commands:
> - `references/split-manifest.md` — binary/library manifests of the two packages, platform matrix, self-containment facts
> - `references/publish-resources.md` — gh / gtc dual-mirror publishing SOP, asset naming, sha256 verification

## 0) Background facts (these determine the whole design)

1. **2 packages, not 3.** It was once split into `llvm-core` + `llvm-libcxx` + `llvm-tools` (commit
   `9db2ba94`), but then `99b004dc` **deliberately merged libc++ back into `llvm` and deleted the standalone `llvm-libcxx`**,
   making `llvm` a self-contained toolchain. So the correct current model is:
   **`llvm` (core+libc++ merged)** + **`llvm-tools`**. The `llvm-core-*`/
   `llvm-libcxx-*` assets left over on the release are the abandoned old split; **do not use them, do not revive them**.
2. **Upstream has no ready-made sub-packages.** `github.com/llvm/llvm-project` ships only monolithic bundles
   (mac `LLVM-<ver>-macOS-<arch>.tar.xz` ≈1.45GB; win `clang+llvm-<ver>-x86_64-pc-windows-msvc.tar.xz`).
   Both packages are carved downstream by xlings-res.
3. **Target binaries are statically self-contained.** The clang driver (`clang-<major>`), `lld`, `clang-format`/`tidy`/
   `clangd` all statically link LLVM and depend only on system libraries; there is no shared `libLLVM`. mac's `libclang-cpp.dylib`/
   `liblldb.dylib` and win's `libclang.dll`/`liblldb.dll` serve only the extra/lldb tools → **all dropped**.
4. **No strip.** LLVM release binaries have no DWARF `debug_info`; strip saves only ~8–10%, not worth it.

## 1) Package definitions (uniform across the three platforms)

| Package | Role | Key contents |
|----|------|---------|
| **`llvm`** | slim self-contained toolchain (compile + link + binutils + C++ standard library) | `bin/`: clang-<major> (+ clang/clang++/clang-cl/clang-cpp symlinks), lld (+ ld.lld/ld64.lld/lld-link/wasm-ld), llvm-ar/nm/ranlib/strip/objcopy/objdump/readobj/readelf/symbolizer/profdata/cov/link/as/dis/size/rc/config/lib/dlltool/addr2line/... (authoritative 33 items in the manifest); `lib/clang/<major>/include` (builtin headers) + `lib/clang/<major>/lib` (compiler-rt); **libc++** (linux/mac): `include/c++/v1`, libc++/libc++abi/libunwind in `lib/`, `share/libc++/v1/std.cppm`; **libatomic** (linux only, `lib/<triple>/libatomic.so*`+`.a`): libc++ over-links it (a ghost NEEDED with 0 references) and the `__atomic_*` fallback calls for 16-byte atomics need it — if it is missing, **every** artifact hangs at runtime with `libatomic.so.1: cannot open`, and anything that really uses atomics cannot link, so it must ship with the package. **Key point: it is a GCC runtime library; LLVM does not build it (`Release.cmake` DEFAULT_RUNTIMES has no libatomic) and the upstream LLVM Linux release does not ship it either** (measured: 0 files) — at carve time `build-llvm-subpkg.sh` **takes it from the build machine's GCC** (`gcc -print-file-name=libatomic.so.1`) and puts it into `lib/<triple>/`. windows has no libc++ (uses MSVC STL), mac has no libatomic (not a GNU platform). |
| **`llvm-tools`** | editor/development tools | `bin/`: clang-format, clang-tidy, clangd; `lib/clang/<major>/include` (needed by clangd's resource-dir) |

> **Dropped (goes into no package)**: all `.a` static libraries (mac ≈1.24GB), `libclang-cpp`/`liblldb*` + lldb tools,
> clang extra tools (clang-move/refactor/query/check/scan-deps/...), MLIR, docs.

**Consistency rule**: same-named packages have the same role on all three platforms; only platform-specific differences are allowed:
- Extension `.so` (linux)/`.dylib` (mac)/`.dll|.exe` (win); library directory is `lib/<triple>/` on linux/mac (mac libc++ is directly in `lib/`), win DLLs are in `bin/`
- Driver names: win additionally has `clang-cl`/`lld-link`/`llvm-lib`
- **libc++ is linux/mac only**; windows `llvm` is core-only

## 2) Self-containment verification (carve acceptance red line)

Every binary put into a package may depend at runtime only on (1) system libraries and (2) libraries shipped in the same package.
- **macOS**: Mach-O `LC_LOAD_DYLIB` reader (pure Python, see `build-llvm-subpkg.sh`); anything not under
  `/usr/lib` or `/System` is non-compliant → abort.
- **Linux**: `ldd` may show only system libraries (`libLLVM.so` must not appear).
- **Windows**: core exes are statically linked; `objdump -p` confirms they do not import `LLVM-C.dll`/`libclang.dll`/
  `liblldb.dll` (measured: neither clang.exe nor lld.exe imports them) → those DLLs are not packaged.

## 3) Carve tool

`.agents/tools/build-llvm-subpkg.sh` (manifest-driven, generalized from `build-llvm-tools.sh`):

```bash
# merged slim llvm (mac/win, carved from the full upstream bundle)
build-llvm-subpkg.sh --in <full.tar.xz|extracted dir> --pkg llvm   --version 22.1.8 --platform macosx  --arch arm64
build-llvm-subpkg.sh --in <dir>                  --pkg tools  --version 22.1.8 --platform windows --arch x86_64
```
- `--pkg llvm` = core + libcxx (automatically skipped when libc++ is absent, e.g. windows) + share/libc++.
- Extract the same-source full bundle once into a dir, then carve from that dir multiple times (avoids repeated extraction); see `carve.sh` in the stage.
- macOS runs the self-containment verification automatically; **no strip**; packaged in the platform's default format (mac=tar.xz; win=tar.xz+zip).

## 4) Publish to xlings-res (dual mirrors, must be consistent)

`GLOBAL=github.com/xlings-res/llvm`, `CN=gitcode.com/xlings-res/llvm`, tag=version number.
- Naming: `<pkg>-<ver>-<platform>-<arch>.<ext>` (`pkg`∈{`llvm`,`llvm-tools`}; platform `linux-x86_64`/
  `macosx-arm64`/`windows-x86_64`; ext: mac=`tar.xz`, win=`tar.xz`+`zip`, linux=`tar.gz`+`tar.xz`).
- **GLOBAL**: `gh release upload <tag> <file>... --clobber --repo xlings-res/llvm` (overwrite supported).
- **CN**: GitCode cannot overwrite; **for a new asset name just run `gtc release upload`**; if replacing an old asset with the same name,
  **the maintainer manually deletes the old asset on the web page** and I then upload (gtc cannot delete).
- After publishing, compare sha256 across GLOBAL, CN and the carve output (all three must match); when backfilling an old version, `latest` must not go backwards.
- Full commands: `references/publish-resources.md`.

## 5) Wire into the package index (.lua recipes)

- `pkgs/l/llvm.lua`: `xpm` for all three platforms. linux/win use `"XLINGS_RES"` (resources are ready); mac uses an explicit
  `url={GLOBAL=...,CN=...}` (following the macosx style in `llvm-tools.lua`). **Do not pin sha256**.
  `install()` `os.mv`s the extracted directory to `install_dir()` and generates `clang.cfg`/`clang++.cfg` per platform
  (sysroot injection + pointing at the libc++ headers/libs **inside this package** — libc++ is in the same package as clang, so the paths are self-consistent,
  which is exactly the reason for the `99b004dc` merge). windows has no libc++, so no libc++ cfg is generated.
- `pkgs/l/llvm-tools.lua`: all three platforms, self-contained, `config()` registers clang-format/tidy/clangd.
- Version skeleton: `["latest"]={ref=...}` + one entry per version; if a platform lacks resources for a version (e.g. linux 22.1.8 awaiting
  self-build), **do not add that version entry for that platform / do not point latest there**, otherwise the CI install test is bound to fail.
- Isolation compliance (`xpkg-creater`): no `os.exec("xvm ...")`, no modifying PATH/profile; import only `xim.libxpkg.*`.

## 6) Platform capability (who can produce which)

**All three platforms are carved from the full upstream release and can be produced on this machine** (same `build-llvm-subpkg.sh` flow):
- macosx-arm64 ← `LLVM-<ver>-macOS-ARM64.tar.xz`
- windows-x86_64 ← `clang+llvm-<ver>-x86_64-pc-windows-msvc.tar.xz`
- linux-x86_64 ← `LLVM-<ver>-Linux-X64.tar.xz` (includes libc++ / share/libc++ / compiler-rt, isomorphic with mac;
  the clang binaries depend at runtime only on system libraries, and the compile-time target is determined by the sysroot-injection cfg from `llvm.lua`)

> Upstream Linux full bundle is about 1.9GB (after carve, `llvm` ≈150M xz). It was wrongly assumed early on that linux needed a "self-build",
> but measurement shows upstream can be carved directly, fully identical to mac/win.

## 7) Acceptance checklist

- [ ] Model is 2 packages (`llvm` + `llvm-tools`); core/libcxx not revived.
- [ ] Every binary passes the self-containment verification; not stripped.
- [ ] Assets complete on GLOBAL+CN, naming compliant, sha256 consistent across all three.
- [ ] Recipes structurally aligned across the three platforms, no sha256 pin, isolation compliant; platforms/versions without resources are not wired.
- [ ] New/changed packages come with tests and go through `pr-workflow` with all CI passing (including macos-install-test).
