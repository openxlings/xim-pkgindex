# LLVM 包清单 / 平台矩阵 / 自包含事实(2 包模型)

> 权威依据:现网 `llvm-20.1.7-linux-x86_64`(Unix 基准)与 `llvm-20.1.7-windows-x86_64`
> (Windows 基准)资产的实际 `bin/` 集;macOS 取自上游 `LLVM-<ver>-macOS-ARM64` 实测。
> carve 工具 `.agents/tools/build-llvm-subpkg.sh` 的 `CORE_BINS` 即按本清单硬编码。

## 1. `llvm` —— slim 自包含工具链(编译 + 链接 + binutils + C++ 标准库)

### bin/ —— Unix(linux + macosx),权威 34 项(linux `llvm` 资产)

```
clang clang++ clang-<major> clang-cl clang-cpp clang-scan-deps
ld64.lld ld.lld lld lld-link wasm-ld
llvm-addr2line llvm-ar llvm-as llvm-bitcode-strip llvm-config llvm-cov
llvm-dis llvm-dlltool llvm-lib llvm-link llvm-nm llvm-objcopy llvm-objdump
llvm-otool llvm-profdata llvm-ranlib llvm-rc llvm-readelf llvm-readobj
llvm-size llvm-strip llvm-symbolizer hwasan_symbolize
```
> `clang`/`clang++`/`clang-cl`/`clang-cpp` 是指向 `clang-<major>` 的软链;
> `hwasan_symbolize` 仅 linux(mac 缺,carve 自动跳过)。

### bin/ —— Windows,权威 27 exe + 2 DLL(windows `llvm` 资产)

```
clang.exe clang++.exe clang-cl.exe clang-scan-deps.exe lld-link.exe
llvm-addr2line llvm-ar llvm-config llvm-cov llvm-cvtres llvm-cxxfilt
llvm-dlltool llvm-lib llvm-mt llvm-nm llvm-objcopy llvm-objdump
llvm-profdata llvm-ranlib llvm-rc llvm-readelf llvm-readobj llvm-size
llvm-strings llvm-strip llvm-symbolizer llvm-windres        (.exe)
libiomp5md.dll libomp.dll                                   (openmp 运行时)
```
> Windows 无独立 `lld`/`wasm-ld`/`clang-cpp`/`llvm-as|dis|link|bitcode-strip|otool`;
> 多 `cvtres/mt/windres/cxxfilt/strings`(Windows 工具链)。核心 exe 静态链接,
> 不 import `LLVM-C.dll`/`libclang.dll`/`liblldb.dll`(实测),故那些 DLL 不打包。

### lib/ + include/ + share/(所有平台)

```
lib/clang/<major>/include/      # clang builtin 头(stddef.h…)
lib/clang/<major>/lib/...       # compiler-rt(各平台子目录)
# 以下仅 linux/macosx(windows 用 MSVC STL,无 libc++):
include/c++/v1/                 # libc++ 头
include/<triple>/c++/v1/        # 平台特化头(若上游提供)
lib/<triple>/ 或 lib/           # libc++ / libc++abi / libunwind (.so|.dylib + .a) + libc++.modules.json
share/libc++/v1/                # std.cppm / std.compat.cppm + std/*.inc(`import std;` 需要)
```

## 2. `llvm-tools` —— 编辑器/开发工具(三平台已发布)

```
bin/  clang-format  clang-tidy  clangd      (windows 带 .exe)
lib/clang/<major>/include/                  # clangd 推导 resource-dir 需要
```
mac/win 三个工具均静态自包含(self-containment 校验已证实)。

## 3. 平台矩阵

| 维度 | linux-x86_64 | macosx-arm64 | windows-x86_64 |
|------|-------------|--------------|----------------|
| `llvm` 来源 | xlings 自建 slim 构建（维护者管线） | 上游 `LLVM-<ver>-macOS-ARM64` carve | 上游 `clang+llvm-<ver>-x86_64-pc-windows-msvc` carve |
| libc++ | 有 | 有 | **无**（MSVC STL） |
| 共享库扩展名 | `.so` | `.dylib` | `.dll` |
| libc++ 库目录 | `lib/<triple>/` | `lib/`（直接） | — |
| 可执行后缀 | 无 | 无 | `.exe` |
| 资产扩展名 | `tar.gz`+`tar.xz` | `tar.xz` | `tar.xz`+`zip` |
| 自包含校验 | `ldd` | Mach-O LC_LOAD_DYLIB | `objdump -p` 导入表 |
| 本流程能否产出 | 否（维护者构建） | 是 | 是 |

## 4. 自包含事实（20.1.7/22.1.8 实测）

- macOS `lib/`：少量 dylib + 大量静态 `.a`（1.24GB），**无 `libLLVM.dylib`**；
  `libclang-cpp.dylib`(185M)/`liblldb.dylib`(166M) 只服务 extra/lldb 工具 → 丢弃。
- `clang-<major>`/`lld`/`clangd`/`clang-tidy`/`clang-format` 体积大正因**静态链接** LLVM，自包含。
- 全部二进制 `debug_info` 段数=0（无 DWARF）→ 不 strip。

## 5. 体积参考（压缩后）

| 资产 | 20.1.7 | 22.1.8 |
|------|--------|--------|
| 上游 mac 全量（carve 输入） | 1449M | 1480M |
| 上游 win 全量（carve 输入） | 939M | 862M |
| `llvm-<ver>-macosx-arm64.tar.xz`（产出） | ~97M | ~见产出 |
| `llvm-<ver>-windows-x86_64`（产出） | （现网既有） | ~见产出 |
| `llvm-tools-<ver>-macosx-arm64.tar.xz` | 49M | ~37M |

分包后用户装 `llvm`(~100M)或 `llvm-tools`(~40–70M),相对 1.4G 整包是数量级收益。
