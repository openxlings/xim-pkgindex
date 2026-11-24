# LLVM Package Manifest / Platform Matrix / Self-containment Facts (2-package model)

> Authoritative basis: the actual `bin/` sets of the live `llvm-20.1.7-linux-x86_64` (Unix baseline) and `llvm-20.1.7-windows-x86_64`
> (Windows baseline) assets; macOS is taken from measurements of upstream `LLVM-<ver>-macOS-ARM64`.
> `CORE_BINS` in the carve tool `.agents/tools/build-llvm-subpkg.sh` is hard-coded from this manifest.

## 1. `llvm` — slim self-contained toolchain (compile + link + binutils + C++ standard library)

### bin/ — Unix (linux + macosx), authoritative 34 items (linux `llvm` asset)

```
clang clang++ clang-<major> clang-cl clang-cpp clang-scan-deps
ld64.lld ld.lld lld lld-link wasm-ld
llvm-addr2line llvm-ar llvm-as llvm-bitcode-strip llvm-config llvm-cov
llvm-dis llvm-dlltool llvm-lib llvm-link llvm-nm llvm-objcopy llvm-objdump
llvm-otool llvm-profdata llvm-ranlib llvm-rc llvm-readelf llvm-readobj
llvm-size llvm-strip llvm-symbolizer hwasan_symbolize
```
> `clang`/`clang++`/`clang-cl`/`clang-cpp` are symlinks to `clang-<major>`;
> `hwasan_symbolize` is linux only (missing on mac, carve skips it automatically).

### bin/ — Windows, authoritative 27 exe + 2 DLL (windows `llvm` asset)

```
clang.exe clang++.exe clang-cl.exe clang-scan-deps.exe lld-link.exe
llvm-addr2line llvm-ar llvm-config llvm-cov llvm-cvtres llvm-cxxfilt
llvm-dlltool llvm-lib llvm-mt llvm-nm llvm-objcopy llvm-objdump
llvm-profdata llvm-ranlib llvm-rc llvm-readelf llvm-readobj llvm-size
llvm-strings llvm-strip llvm-symbolizer llvm-windres        (.exe)
libiomp5md.dll libomp.dll                                   (openmp runtime)
```
> Windows has no standalone `lld`/`wasm-ld`/`clang-cpp`/`llvm-as|dis|link|bitcode-strip|otool`;
> it additionally has `cvtres/mt/windres/cxxfilt/strings` (Windows toolchain). Core exes are statically linked and
> do not import `LLVM-C.dll`/`libclang.dll`/`liblldb.dll` (measured), so those DLLs are not packaged.

### lib/ + include/ + share/ (all platforms)

```
lib/clang/<major>/include/      # clang builtin headers (stddef.h…)
lib/clang/<major>/lib/...       # compiler-rt (per-platform subdirectories)
# the following are linux/macosx only (windows uses MSVC STL, no libc++):
include/c++/v1/                 # libc++ headers
include/<triple>/c++/v1/        # platform-specific headers (if upstream provides them)
lib/<triple>/ or lib/           # libc++ / libc++abi / libunwind (.so|.dylib + .a) + libc++.modules.json
lib/<triple>/libatomic.so*+.a   # linux only: GCC runtime library, needed for libc++'s ghost dependency + the 16-byte atomic __atomic_* fallback calls; if missing, every artifact hangs at runtime on libatomic.so.1.
                                # ⚠ Not from upstream (LLVM does not build libatomic, the upstream Linux package does not ship it) — carve takes it from the build machine's GCC (gcc -print-file-name=libatomic.so.1)
share/libc++/v1/                # std.cppm / std.compat.cppm + std/*.inc (needed by `import std;`)
```

## 2. `llvm-tools` — editor/development tools (published for all three platforms)

```
bin/  clang-format  clang-tidy  clangd      (windows ships .exe)
lib/clang/<major>/include/                  # needed for clangd to derive resource-dir
```
The three tools on mac/win are all statically self-contained (confirmed by the self-containment verification).

## 3. Platform matrix

| Dimension | linux-x86_64 | macosx-arm64 | windows-x86_64 |
|------|-------------|--------------|----------------|
| `llvm` source | upstream `LLVM-<ver>-Linux-X64` carve | upstream `LLVM-<ver>-macOS-ARM64` carve | upstream `clang+llvm-<ver>-x86_64-pc-windows-msvc` carve |
| libc++ | yes | yes | **none** (MSVC STL) |
| Shared library extension | `.so` | `.dylib` | `.dll` |
| libc++ library directory | `lib/<triple>/` | `lib/` (directly) | — |
| Executable suffix | none | none | `.exe` |
| Asset extension | `tar.gz`+`tar.xz` | `tar.xz` | `tar.xz`+`zip` |
| Self-containment check | `ldd` | Mach-O LC_LOAD_DYLIB | `objdump -p` import table |
| Producible by this flow | yes (upstream carve) | yes | yes |

## 4. Self-containment facts (measured on 20.1.7/22.1.8)

- macOS `lib/`: a few dylibs + lots of static `.a` (1.24GB), **no `libLLVM.dylib`**;
  `libclang-cpp.dylib` (185M)/`liblldb.dylib` (166M) serve only the extra/lldb tools → dropped.
- `clang-<major>`/`lld`/`clangd`/`clang-tidy`/`clang-format` are large precisely because they **statically link** LLVM, and so are self-contained.
- All binaries have 0 `debug_info` sections (no DWARF) → no strip.

## 5. Size reference (compressed)

| Asset | 20.1.7 | 22.1.8 |
|------|--------|--------|
| Upstream mac full (carve input) | 1449M | 1480M |
| Upstream win full (carve input) | 939M | 862M |
| `llvm-<ver>-macosx-arm64.tar.xz` (output) | ~97M | ~see output |
| `llvm-<ver>-windows-x86_64` (output) | (already live) | ~see output |
| `llvm-tools-<ver>-macosx-arm64.tar.xz` | 49M | ~37M |

After sub-packaging, users install `llvm` (~100M) or `llvm-tools` (~40–70M); relative to the 1.4G bundle this is an order-of-magnitude gain.
