---
name: llvm-subpackaging
description: LLVM 全平台分包（sub-packaging）规范 / 设计方案 / SOP。把上游单体 LLVM 工具链 carve 成两个自包含包——`llvm`（slim 自包含工具链 = 编译器 + lld + binutils + libc++ + compiler-rt）与 `llvm-tools`（clang-format/tidy/clangd）——并发布到 xlings-res 双镜像（GitHub gh + GitCode gtc）。用于新增/对齐某平台的 llvm 包、升级版本、保证 linux/macosx/windows 三平台一致。
---

# LLVM 分包规范 / SOP（2 包模型）

把上游 **1.4–2GB 单体** LLVM 整包 carve 成两个职责单一、**自包含**的包,让用户按需安装,
不必每次拖整包(还含 1.2GB 用不到的静态库 + lldb + 全部 extra 工具)。

> 详细清单与命令见:
> - `references/split-manifest.md` —— 两个包的二进制/库清单、平台矩阵、自包含事实
> - `references/publish-resources.md` —— gh / gtc 双镜像发布 SOP、资产命名、sha256 校验

## 0) 背景事实(决定整套设计)

1. **2 包,不是 3 包。** 历史上曾拆成 `llvm-core` + `llvm-libcxx` + `llvm-tools`(commit
   `9db2ba94`),但随后 `99b004dc` **主动把 libc++ 并回 `llvm`、删掉独立 `llvm-libcxx`**,
   让 `llvm` 成为一个自包含 toolchain。所以当前正确模型是:
   **`llvm`(core+libc++ 合并)** + **`llvm-tools`**。release 上残留的 `llvm-core-*`/
   `llvm-libcxx-*` 资产是被放弃的旧拆分,**不再使用、不要复活**。
2. **上游没有现成分包。** `github.com/llvm/llvm-project` 全是单体整包
   (mac `LLVM-<ver>-macOS-<arch>.tar.xz`≈1.45GB;win `clang+llvm-<ver>-x86_64-pc-windows-msvc.tar.xz`)。
   两个包都是 xlings-res 下游 carve 的。
3. **目标二进制静态自包含。** clang 驱动(`clang-<major>`)、`lld`、`clang-format`/`tidy`/
   `clangd` 都静态链接 LLVM,只依赖系统库;无共享 `libLLVM`。mac 的 `libclang-cpp.dylib`/
   `liblldb.dylib`、win 的 `libclang.dll`/`liblldb.dll` 只服务 extra/lldb 工具 → **全部丢弃**。
4. **不做 strip。** LLVM release 二进制无 DWARF `debug_info`,strip 只省 ~8–10%,不值得。

## 1) 包定义(三平台统一)

| 包 | 职责 | 关键内容 |
|----|------|---------|
| **`llvm`** | slim 自包含工具链(编译+链接+binutils+C++ 标准库) | `bin/`: clang-<major>(+clang/clang++/clang-cl/clang-cpp 软链)、lld(+ld.lld/ld64.lld/lld-link/wasm-ld)、llvm-ar/nm/ranlib/strip/objcopy/objdump/readobj/readelf/symbolizer/profdata/cov/link/as/dis/size/rc/config/lib/dlltool/addr2line/...(权威 33 项见 manifest);`lib/clang/<major>/include`(builtin 头)+`lib/clang/<major>/lib`(compiler-rt);**libc++**(linux/mac):`include/c++/v1`、`lib/` 的 libc++/libc++abi/libunwind、`share/libc++/v1/std.cppm`;**libatomic**(仅 linux,`lib/<triple>/libatomic.so*`+`.a`):libc++ 过度链接它(0 引用的幽灵 NEEDED)且 16 字节原子的 `__atomic_*` 退化调用需要它——漏带会让**每个**产物运行期挂 `libatomic.so.1: cannot open`、真用原子者无法链接,故必须随包(GCC 运行时库,上游 LLVM Linux release 已捆在 `lib/<triple>/`)。windows 无 libc++(用 MSVC STL),mac 无 libatomic(非 GNU 平台)。 |
| **`llvm-tools`** | 编辑器/开发工具 | `bin/`: clang-format、clang-tidy、clangd;`lib/clang/<major>/include`(clangd resource-dir 需要) |

> **被丢弃(不进任何包)**:全部 `.a` 静态库(mac≈1.24GB)、`libclang-cpp`/`liblldb*` + lldb 工具、
> clang extra 工具(clang-move/refactor/query/check/scan-deps/...)、MLIR、docs。

**一致性铁律**:三平台同名包职责一致,只允许平台差异化:
- 扩展名 `.so`(linux)/`.dylib`(mac)/`.dll|.exe`(win);库目录 linux/mac 用 `lib/<triple>/`(mac libc++ 直接在 `lib/`),win DLL 在 `bin/`
- 驱动名:win 多 `clang-cl`/`lld-link`/`llvm-lib`
- **libc++ 仅 linux/mac**;windows `llvm` 是 core-only

## 2) 自包含校验(carve 验收红线)

放进包的每个二进制运行期只允许依赖①系统库②同包随附库。
- **macOS**:Mach-O `LC_LOAD_DYLIB` 读取器(纯 Python,见 `build-llvm-subpkg.sh`),非
  `/usr/lib`、`/System` 即不合格 → 中止。
- **Linux**:`ldd` 只能是系统库(不应出现 `libLLVM.so`)。
- **Windows**:核心 exe 静态链接;`objdump -p` 确认不 import `LLVM-C.dll`/`libclang.dll`/
  `liblldb.dll`(实测 clang.exe/lld.exe 都不 import)→ 不打包那些 DLL。

## 3) Carve 工具

`.agents/tools/build-llvm-subpkg.sh`(manifest 驱动,从 `build-llvm-tools.sh` 泛化):

```bash
# 合并 slim llvm(mac/win,从上游全量 carve)
build-llvm-subpkg.sh --in <full.tar.xz|解压dir> --pkg llvm   --version 22.1.8 --platform macosx  --arch arm64
build-llvm-subpkg.sh --in <dir>                  --pkg tools  --version 22.1.8 --platform windows --arch x86_64
```
- `--pkg llvm` = core + libcxx(libc++ 缺失时自动跳过,如 windows)+ share/libc++。
- 同源整包先解压一次成 dir,再对 dir 多次 carve(避免重复解压);见 stage 里的 `carve.sh`。
- macOS 自动跑自包含校验;**不 strip**;按平台默认格式打包(mac=tar.xz;win=tar.xz+zip)。

## 4) 发布到 xlings-res(双镜像,必须一致)

`GLOBAL=github.com/xlings-res/llvm`、`CN=gitcode.com/xlings-res/llvm`,tag=版本号。
- 命名:`<pkg>-<ver>-<platform>-<arch>.<ext>`(`pkg`∈{`llvm`,`llvm-tools`};平台 `linux-x86_64`/
  `macosx-arm64`/`windows-x86_64`;ext:mac=`tar.xz`、win=`tar.xz`+`zip`、linux=`tar.gz`+`tar.xz`)。
- **GLOBAL**:`gh release upload <tag> <file>... --clobber --repo xlings-res/llvm`(支持覆盖)。
- **CN**:GitCode 不能覆盖;**新资产名直接 `gtc release upload`**;若是替换旧同名资产,
  **由维护者手动在网页删旧资产**后我再上传(gtc 不能删)。
- 发布后从 GLOBAL、CN、carve 产物三方 sha256 比对一致;补旧版本时 `latest` 不倒退。
- 完整命令见 `references/publish-resources.md`。

## 5) 接线包索引(.lua 配方)

- `pkgs/l/llvm.lua`:三平台 `xpm`。linux/win 用 `"XLINGS_RES"`(资源已就绪);mac 用显式
  `url={GLOBAL=...,CN=...}`(沿用 `llvm-tools.lua` 的 macosx 写法)。**不 pin sha256**。
  `install()` 把解压目录 `os.mv` 到 `install_dir()`,并按平台生成 `clang.cfg`/`clang++.cfg`
  (sysroot 注入 + 指向**本包内**的 libc++ 头/库 —— libc++ 与 clang 同包,故路径自洽,
  这正是 `99b004dc` 合并的理由)。windows 无 libc++ 不生成 libc++ cfg。
- `pkgs/l/llvm-tools.lua`:三平台,自包含,`config()` 注册 clang-format/tidy/clangd。
- 版本骨架:`["latest"]={ref=...}` + 每版本一条;某平台缺该版本资源(如 linux 22.1.8 待
  自建)就**不要给该平台加该版本条目 / 不要把 latest 指过去**,否则 CI install 测试必挂。
- 隔离合规(`xpkg-creater`):禁 `os.exec("xvm ...")`、禁改 PATH/profile;import 仅 `xim.libxpkg.*`。

## 6) 平台落地能力(谁能产哪个)

**三平台都从上游全量 release carve,本机即可产出**(同一 `build-llvm-subpkg.sh` 流程):
- macosx-arm64 ← `LLVM-<ver>-macOS-ARM64.tar.xz`
- windows-x86_64 ← `clang+llvm-<ver>-x86_64-pc-windows-msvc.tar.xz`
- linux-x86_64 ← `LLVM-<ver>-Linux-X64.tar.xz`(含 libc++ / share/libc++ / compiler-rt,与 mac 同构;
  clang 二进制运行期只依赖系统库,编译期目标由 `llvm.lua` 的 sysroot 注入 cfg 决定)

> 上游 Linux 全量约 1.9GB(carve 后 `llvm`≈150M xz)。早期误以为 linux 需"自建构建",
> 实测可直接 carve 上游,与 mac/win 完全一致。

## 7) 验收清单

- [ ] 模型为 2 包(`llvm` + `llvm-tools`),未复活 core/libcxx。
- [ ] 每个二进制过自包含校验;未 strip。
- [ ] 资产 GLOBAL+CN 齐全、命名合规、sha256 三方一致。
- [ ] 配方三平台结构对齐、不 pin sha256、隔离合规;无资源的平台/版本不接线。
- [ ] 新增/改包带 tests、走 `pr-workflow` 过全部 CI(含 macos-install-test)。
